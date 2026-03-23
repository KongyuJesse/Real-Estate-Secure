const crypto = require('crypto');
const express = require('express');

const { query, withTransaction } = require('../db');
const { asyncHandler } = require('../lib/async-handler');
const { success } = require('../lib/http');
const { badRequest } = require('../lib/errors');
const { getPagination } = require('../lib/pagination');
const { requireAuth } = require('../middleware/auth');
const { decryptValueSafely, encryptValue } = require('../services/field-crypto');
const {
  createSubscriptionCheckout,
  extractNotchPayWebhookEventType,
  extractNotchPayWebhookReference,
  getPaymentGatewaySummary,
  retrievePaymentByReference,
  verifyNotchPayWebhookSignature,
} = require('../services/payment-gateway-service');

function escapeHtml(value) {
  return String(value || '').replace(
    /[&<>"']/g,
    (char) =>
      ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
      })[char] || char,
  );
}

function maskValue(value) {
  const raw = String(value || '').trim();
  if (!raw) {
    return '';
  }
  const visible = raw.slice(-4);
  return `${'*'.repeat(Math.max(raw.length - 4, 0))}${visible}`;
}

function sanitizeBillingCycle(value) {
  const billingCycle = String(value || 'monthly').toLowerCase();
  if (!['monthly', 'yearly'].includes(billingCycle)) {
    throw badRequest('billing_cycle must be monthly or yearly.');
  }
  return billingCycle;
}

function isPaidPlan(plan) {
  return (
    Number(plan?.price_monthly ?? 0) > 0 ||
    Number(plan?.price_yearly ?? 0) > 0
  );
}

function buildSubscriptionCheckoutReference(userId, planCode, billingCycle) {
  const suffix = crypto.randomBytes(4).toString('hex');
  return `sub_${userId}_${planCode}_${billingCycle}_${Date.now()}_${suffix}`.slice(
    0,
    120,
  );
}

function parseSqlDate(value) {
  return new Date(`${String(value).slice(0, 10)}T00:00:00.000Z`);
}

function toSqlDate(value) {
  return new Date(value).toISOString().split('T')[0];
}

function addBillingCycle(startDate, billingCycle) {
  const next = new Date(startDate);
  if (billingCycle === 'yearly') {
    next.setUTCFullYear(next.getUTCFullYear() + 1);
  } else {
    next.setUTCMonth(next.getUTCMonth() + 1);
  }
  return next;
}

function normalizeCheckoutSessionStatus(providerStatus) {
  switch (String(providerStatus || '').toLowerCase()) {
    case 'complete':
      return 'paid';
    case 'failed':
    case 'canceled':
    case 'cancelled':
    case 'expired':
      return 'failed';
    case 'processing':
      return 'processing';
    default:
      return 'pending';
  }
}

function buildSubscriptionInvoiceNumber(reference, sessionId) {
  const compactReference = String(reference || '')
    .replace(/[^a-z0-9]/gi, '')
    .toUpperCase()
    .slice(-10);
  return `SUB-${sessionId}-${compactReference}`.slice(0, 50);
}

function buildPaymentStatusPage({
  providerLabel,
  sessionStatus,
  reference,
  message,
}) {
  const tint =
    sessionStatus === 'paid'
      ? '#166534'
      : sessionStatus === 'failed'
      ? '#9f1239'
      : '#1d4ed8';
  const badge =
    sessionStatus === 'paid'
      ? '#dcfce7'
      : sessionStatus === 'failed'
      ? '#ffe4e6'
      : '#dbeafe';
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Payment status</title>
    <style>
      body {
        margin: 0;
        font-family: Inter, Arial, sans-serif;
        background: #f4f4ef;
        color: #14181b;
      }
      main {
        max-width: 560px;
        margin: 0 auto;
        padding: 48px 24px;
      }
      .card {
        background: #ffffff;
        border-radius: 28px;
        padding: 30px;
        box-shadow: 0 20px 52px rgba(20, 24, 27, 0.08);
      }
      .eyebrow {
        display: inline-block;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: ${tint};
        background: ${badge};
        border-radius: 999px;
        padding: 8px 12px;
      }
      h1 {
        margin: 18px 0 12px;
        font-size: 28px;
        line-height: 1.2;
      }
      p {
        line-height: 1.6;
        margin: 0 0 12px;
      }
      code {
        background: #f1f5f9;
        border-radius: 8px;
        padding: 2px 8px;
      }
    </style>
  </head>
  <body>
    <main>
      <section class="card">
        <span class="eyebrow">${escapeHtml(providerLabel)} return</span>
        <h1>Payment flow received</h1>
        <p>Status: <strong>${escapeHtml(sessionStatus)}</strong></p>
        ${reference ? `<p>Reference: <code>${escapeHtml(reference)}</code></p>` : ''}
        <p>${escapeHtml(message)}</p>
        <p>Return to the Real Estate Secure mobile app. The Plans & Billing page can resume or confirm this checkout when you come back.</p>
      </section>
    </main>
  </body>
</html>`;
}

function buildSandboxCheckoutPage({
  reference,
  planName,
  amount,
  currency,
  billingCycle,
}) {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Subscription checkout</title>
    <style>
      body {
        margin: 0;
        font-family: Inter, Arial, sans-serif;
        background: linear-gradient(180deg, #f7f4ed 0%, #f4f4ef 100%);
        color: #14181b;
      }
      main {
        max-width: 620px;
        margin: 0 auto;
        padding: 40px 20px 56px;
      }
      .card {
        background: rgba(255, 255, 255, 0.96);
        border: 1px solid rgba(216, 208, 190, 0.72);
        border-radius: 32px;
        padding: 28px;
        box-shadow: 0 24px 60px rgba(20, 24, 27, 0.08);
      }
      .eyebrow {
        display: inline-flex;
        align-items: center;
        gap: 8px;
        font-size: 12px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #7c5c11;
        background: #f6edcf;
        border-radius: 999px;
        padding: 8px 12px;
      }
      h1 {
        margin: 18px 0 10px;
        font-size: 30px;
        line-height: 1.15;
      }
      p {
        margin: 0;
        line-height: 1.6;
        color: #4f5b67;
      }
      .summary {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
        margin: 24px 0;
      }
      .metric {
        border-radius: 22px;
        background: #f7f7f4;
        border: 1px solid #ebe7dc;
        padding: 16px;
      }
      .metric-label {
        font-size: 12px;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: #7b8794;
        margin-bottom: 8px;
      }
      .metric-value {
        font-size: 18px;
        font-weight: 700;
        color: #14181b;
      }
      .actions {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 12px;
        margin-top: 24px;
      }
      button {
        appearance: none;
        border: 0;
        border-radius: 999px;
        padding: 16px 18px;
        font-size: 15px;
        font-weight: 700;
        cursor: pointer;
      }
      .primary {
        background: #171717;
        color: #ffffff;
      }
      .secondary {
        background: #eceae2;
        color: #14181b;
      }
      code {
        background: #f1f5f9;
        border-radius: 8px;
        padding: 2px 8px;
      }
      @media (max-width: 640px) {
        .summary,
        .actions {
          grid-template-columns: 1fr;
        }
      }
    </style>
  </head>
  <body>
    <main>
      <section class="card">
        <span class="eyebrow">Checkout preview</span>
        <h1>Confirm this subscription</h1>
        <p>Use this hosted test checkout to complete the plan change from the Real Estate Secure mobile app.</p>
        <div class="summary">
          <div class="metric">
            <div class="metric-label">Plan</div>
            <div class="metric-value">${escapeHtml(planName)}</div>
          </div>
          <div class="metric">
            <div class="metric-label">Billing</div>
            <div class="metric-value">${escapeHtml(billingCycle)}</div>
          </div>
          <div class="metric">
            <div class="metric-label">Amount</div>
            <div class="metric-value">${escapeHtml(currency)} ${escapeHtml(amount)}</div>
          </div>
          <div class="metric">
            <div class="metric-label">Reference</div>
            <div class="metric-value"><code>${escapeHtml(reference)}</code></div>
          </div>
        </div>
        <p>Approve to simulate a completed payment, or cancel to return a failed result to the mobile billing screen.</p>
        <div class="actions">
          <form method="get" action="/payments/sandbox/subscriptions/complete">
            <input type="hidden" name="reference" value="${escapeHtml(reference)}" />
            <input type="hidden" name="outcome" value="paid" />
            <button class="primary" type="submit">Confirm payment</button>
          </form>
          <form method="get" action="/payments/sandbox/subscriptions/complete">
            <input type="hidden" name="reference" value="${escapeHtml(reference)}" />
            <input type="hidden" name="outcome" value="failed" />
            <button class="secondary" type="submit">Cancel checkout</button>
          </form>
        </div>
      </section>
    </main>
  </body>
</html>`;
}

function buildSubscriptionCheckoutState(session) {
  if (!session) {
    return null;
  }

  const sessionStatus = String(session.session_status || 'pending')
    .trim()
    .toLowerCase();
  const providerStatus = String(session.provider_status || '')
    .trim()
    .toLowerCase();
  const checkoutUrl = String(session.checkout_url || '').trim();
  const canResumeCheckout =
    checkoutUrl.length > 0 && !['paid', 'failed'].includes(sessionStatus);
  const needsAttention = ['pending', 'processing', 'failed'].includes(
    sessionStatus,
  );

  let returnHint =
    'The last checkout state is available for review inside the mobile app.';
  if (sessionStatus === 'paid') {
    returnHint =
      'Payment confirmed. Refreshing your plan state should now show the active subscription.';
  } else if (sessionStatus === 'processing') {
    returnHint =
      'The gateway is still processing this payment. Use confirm status after returning from checkout.';
  } else if (sessionStatus === 'pending') {
    returnHint =
      'Complete the hosted checkout, then return here to resume or confirm the payment result.';
  } else if (sessionStatus === 'failed') {
    returnHint =
      'This checkout did not complete successfully. You can review the error and start a fresh payment attempt.';
  }

  return {
    id: session.id,
    reference: session.reference,
    provider: session.provider,
    plan_id: session.plan_id,
    plan_name: session.plan_name,
    plan_code: session.plan_code,
    billing_cycle: session.billing_cycle,
    session_status: sessionStatus,
    provider_status: providerStatus,
    checkout_url: checkoutUrl,
    callback_url: String(session.callback_url || '').trim(),
    amount: Number(session.amount || 0),
    currency: String(session.currency || 'XAF').trim().toUpperCase(),
    error_message: String(session.error_message || '').trim(),
    can_resume_checkout: canResumeCheckout,
    needs_attention: needsAttention,
    return_hint: returnHint,
    created_at: session.created_at,
    updated_at: session.updated_at,
    paid_at: session.paid_at,
  };
}

async function findLatestSubscriptionCheckoutSession({ userId, reference }) {
  const filters = ['scs.user_id = $1'];
  const params = [userId];

  if (String(reference || '').trim().length > 0) {
    params.push(String(reference).trim());
    filters.push(`scs.reference = $${params.length}`);
  }

  const result = await query(
    `SELECT
        scs.id,
        scs.user_id,
        scs.plan_id,
        scs.reference,
        scs.provider,
        scs.billing_cycle,
        scs.amount,
        scs.currency,
        scs.checkout_url,
        scs.callback_url,
        scs.provider_status,
        scs.session_status,
        scs.error_message,
        scs.created_at,
        scs.updated_at,
        scs.paid_at,
        sp.plan_name,
        sp.plan_code
     FROM subscription_checkout_sessions scs
     JOIN subscription_plans sp ON sp.id = scs.plan_id
     WHERE ${filters.join(' AND ')}
     ORDER BY scs.created_at DESC
     LIMIT 1`,
    params,
  );
  return result.rows[0] ?? null;
}

async function findSubscriptionCheckoutSessionByReference(reference) {
  const result = await query(
    `SELECT
        scs.*,
        sp.plan_name,
        sp.plan_code
     FROM subscription_checkout_sessions scs
     JOIN subscription_plans sp ON sp.id = scs.plan_id
     WHERE scs.reference = $1
     LIMIT 1`,
    [reference],
  );
  return result.rows[0] ?? null;
}

async function refreshSubscriptionCheckoutIfNeeded(session) {
  if (!session) {
    return null;
  }

  if (String(session.provider || '').trim().toLowerCase() === 'sandbox') {
    return session;
  }

  if (!['pending', 'processing'].includes(String(session.session_status))) {
    return session;
  }

  const reference = String(session.reference || '').trim();
  if (!reference) {
    return session;
  }

  try {
    const payment = await retrievePaymentByReference(reference);
    await reconcileSubscriptionCheckout({
      reference,
      payment,
    });
  } catch (error) {
    await query(
      `UPDATE subscription_checkout_sessions
       SET error_message = COALESCE($2, error_message),
           updated_at = now()
       WHERE id = $1`,
      [
        session.id,
        error?.message?.toString() ||
          'We could not refresh the payment result from the gateway yet.',
      ],
    );
  }

  return findLatestSubscriptionCheckoutSession({
    userId: session.user_id,
    reference,
  });
}

async function reconcileSubscriptionCheckout({ reference, payment }) {
  return withTransaction(async (client) => {
    const sessionResult = await client.query(
      `SELECT scs.*, sp.plan_name, sp.plan_code, sp.max_listings, sp.featured_listings_included
       FROM subscription_checkout_sessions scs
       JOIN subscription_plans sp ON sp.id = scs.plan_id
       WHERE scs.reference = $1
       LIMIT 1
       FOR UPDATE`,
      [reference],
    );
    const session = sessionResult.rows[0];
    if (!session) {
      throw badRequest('Subscription checkout session was not found.');
    }

    const providerStatus = String(payment?.status || 'pending').toLowerCase();
    const sessionStatus = normalizeCheckoutSessionStatus(providerStatus);
    const paidAt = payment?.completedAt || null;

    await client.query(
      `UPDATE subscription_checkout_sessions
       SET provider_status = $2,
           session_status = $3,
           provider_payload = $4,
           paid_at = COALESCE($5::timestamptz, paid_at),
           verified_at = now(),
           error_message = CASE
             WHEN $3 = 'failed' THEN COALESCE(error_message, 'The checkout did not complete successfully.')
             ELSE NULL
           END,
           updated_at = now()
       WHERE id = $1`,
      [session.id, providerStatus, sessionStatus, payment?.raw ?? {}, paidAt],
    );

    if (sessionStatus !== 'paid') {
      return {
        reference: session.reference,
        sessionStatus,
        providerStatus,
        subscriptionId: session.subscription_id,
      };
    }

    if (session.subscription_id) {
      return {
        reference: session.reference,
        sessionStatus,
        providerStatus,
        subscriptionId: session.subscription_id,
      };
    }

    const existingSubscriptionResult = await client.query(
      `SELECT id, plan_id, end_date
       FROM user_subscriptions
       WHERE user_id = $1 AND subscription_status IN ('active', 'pending')
       ORDER BY created_at DESC
       LIMIT 1
       FOR UPDATE`,
      [session.user_id],
    );
    const existingSubscription = existingSubscriptionResult.rows[0] ?? null;

    const amountPaid =
      Number(payment?.amount) > 0 ? Number(payment.amount) : Number(session.amount);
    const currency = String(payment?.currency || session.currency || 'XAF').toUpperCase();
    let subscriptionId;
    let periodStart;
    let periodEnd;

    if (existingSubscription && Number(existingSubscription.plan_id) === Number(session.plan_id)) {
      const renewalAnchor = parseSqlDate(existingSubscription.end_date);
      const currentDate = new Date();
      periodStart = renewalAnchor > currentDate ? renewalAnchor : currentDate;
      periodEnd = addBillingCycle(periodStart, session.billing_cycle);

      const updatedSubscription = await client.query(
        `UPDATE user_subscriptions
         SET subscription_status = 'active',
             billing_cycle = $2,
             end_date = $3,
             next_billing_date = $3,
             price_paid = $4,
             currency = $5,
             listing_count_limit = $6,
             featured_count_limit = $7,
             cancellation_reason = NULL,
             cancelled_at = NULL,
             updated_at = now()
         WHERE id = $1
         RETURNING id`,
        [
          existingSubscription.id,
          session.billing_cycle,
          toSqlDate(periodEnd),
          amountPaid,
          currency,
          session.max_listings,
          session.featured_listings_included,
        ],
      );
      subscriptionId = updatedSubscription.rows[0].id;
    } else {
      if (existingSubscription) {
        await client.query(
          `UPDATE user_subscriptions
           SET subscription_status = 'cancelled',
               cancelled_at = now(),
               cancellation_reason = $2,
               updated_at = now()
           WHERE user_id = $1 AND subscription_status IN ('active', 'pending')`,
          [session.user_id, `Superseded by hosted checkout ${session.reference}.`],
        );
      }

      periodStart = new Date();
      periodEnd = addBillingCycle(periodStart, session.billing_cycle);
      const insertedSubscription = await client.query(
        `INSERT INTO user_subscriptions (
            user_id, plan_id, subscription_status, billing_cycle, start_date, end_date,
            next_billing_date, price_paid, currency, listing_count_limit, featured_count_limit
         )
         VALUES ($1,$2,'active',$3,$4,$5,$6,$7,$8,$9,$10)
         RETURNING id`,
        [
          session.user_id,
          session.plan_id,
          session.billing_cycle,
          toSqlDate(periodStart),
          toSqlDate(periodEnd),
          toSqlDate(periodEnd),
          amountPaid,
          currency,
          session.max_listings,
          session.featured_listings_included,
        ],
      );
      subscriptionId = insertedSubscription.rows[0].id;
    }

    await client.query(
      `INSERT INTO subscription_invoices (
          subscription_id, invoice_number, period_start, period_end, amount,
          total_amount, status, paid_at, payment_reference
       )
       VALUES ($1,$2,$3,$4,$5,$5,'paid',COALESCE($6::timestamptz, now()),$7)`,
      [
        subscriptionId,
        buildSubscriptionInvoiceNumber(session.reference, session.id),
        toSqlDate(periodStart),
        toSqlDate(periodEnd),
        amountPaid,
        paidAt,
        session.reference,
      ],
    );

    await client.query(
      `UPDATE subscription_checkout_sessions
       SET subscription_id = $2,
           session_status = 'paid',
           paid_at = COALESCE($3::timestamptz, paid_at, now()),
           updated_at = now()
       WHERE id = $1`,
      [session.id, subscriptionId, paidAt],
    );

    return {
      reference: session.reference,
      sessionStatus: 'paid',
      providerStatus,
      subscriptionId,
    };
  });
}

function buildCommerceRouter() {
  const router = express.Router();

  router.get('/payments/methods', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, method_type, provider, account_name, phone_number, bank_name, is_default, is_verified, is_active
       FROM payment_methods
       WHERE user_id = $1
       ORDER BY is_default DESC, created_at DESC`,
      [req.auth.uid],
    );
    return success(
      res,
      result.rows.map((row) => ({
        ...row,
        phone_number: maskValue(decryptValueSafely(row.phone_number)),
      })),
    );
  }));

  router.post('/payments/methods', requireAuth, asyncHandler(async (req, res) => {
    const { method_type, provider, account_name, account_number, phone_number, bank_name, bank_code } = req.body ?? {};
    if (!method_type || !provider) {
      throw badRequest('method_type and provider are required.');
    }
    const result = await query(
      `INSERT INTO payment_methods (
          user_id, method_type, provider, account_name, account_number,
          phone_number, bank_name, bank_code, is_active
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true)
       RETURNING id, method_type, provider, account_name, phone_number, bank_name`,
      [
        req.auth.uid,
        method_type,
        provider,
        account_name ?? null,
        encryptValue(account_number ?? null),
        encryptValue(phone_number ?? null),
        bank_name ?? null,
        bank_code ?? null,
      ],
    );
    return success(
      res,
      {
        ...result.rows[0],
        phone_number: maskValue(decryptValueSafely(result.rows[0].phone_number)),
      },
      undefined,
      201,
    );
  }));

  router.delete('/payments/methods/:id', requireAuth, asyncHandler(async (req, res) => {
    await query('DELETE FROM payment_methods WHERE id = $1 AND user_id = $2', [req.params.id, req.auth.uid]);
    return success(res, { deleted: true });
  }));

  router.get('/payments/history', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT et.transaction_reference, et.transaction_type, et.amount, et.status, et.created_at
       FROM escrow_transactions et
       LEFT JOIN payment_methods pm ON pm.id = et.payment_method_id
       WHERE et.initiated_by_id = $1 OR pm.user_id = $1
       ORDER BY et.created_at DESC`,
      [req.auth.uid],
    );
    return success(res, result.rows);
  }));

  router.get('/payments/gateway/summary', asyncHandler(async (req, res) => {
    return success(res, getPaymentGatewaySummary());
  }));

  router.post('/payments/gateway/subscriptions/checkout', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.plan_id) {
      throw badRequest('plan_id is required.');
    }

    const billingCycle = sanitizeBillingCycle(req.body?.billing_cycle);

    const [planResult, userResult] = await Promise.all([
      query(
        `SELECT id, plan_name, plan_code, price_monthly, price_yearly, currency
         FROM subscription_plans
         WHERE id = $1
         LIMIT 1`,
        [req.body.plan_id],
      ),
      query(
        `SELECT id, email, CONCAT(first_name, ' ', last_name) AS full_name
         FROM users
         WHERE id = $1
         LIMIT 1`,
        [req.auth.uid],
      ),
    ]);

    const plan = planResult.rows[0];
    const user = userResult.rows[0];
    if (!plan) {
      throw badRequest('Selected plan was not found.');
    }
    if (!user) {
      throw badRequest('Authenticated user was not found.');
    }

    const amount =
      billingCycle === 'yearly' && Number(plan.price_yearly) > 0
        ? Number(plan.price_yearly)
        : Number(plan.price_monthly);
    const reference = buildSubscriptionCheckoutReference(
      user.id,
      plan.plan_code,
      billingCycle,
    );

    const sessionResult = await query(
      `INSERT INTO subscription_checkout_sessions (
          reference, provider, user_id, plan_id, billing_cycle, amount, currency,
          redirect_url, customer_email, customer_name
       )
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING id`,
      [
        reference,
        getPaymentGatewaySummary().provider,
        user.id,
        plan.id,
        billingCycle,
        amount,
        plan.currency || 'XAF',
        req.body?.redirect_url ?? null,
        user.email,
        user.full_name || user.email,
      ],
    );

    let checkout;
    try {
      checkout = await createSubscriptionCheckout({
        sessionReference: reference,
        plan,
        billingCycle,
        customer: {
          userId: user.id,
          email: user.email,
          name: user.full_name || user.email,
        },
        redirectUrl: req.body?.redirect_url ?? null,
        appBaseUrl: `${req.protocol}://${req.get('host')}`,
      });
    } catch (error) {
      await query(
        `UPDATE subscription_checkout_sessions
         SET session_status = 'failed', error_message = $2, updated_at = now()
         WHERE id = $1`,
        [sessionResult.rows[0].id, error?.message || 'Checkout initialization failed.'],
      );
      throw error;
    }

    await query(
      `UPDATE subscription_checkout_sessions
       SET checkout_url = $2,
           provider_checkout_id = $3,
           callback_url = $4,
           provider_payload = $5,
           updated_at = now()
       WHERE id = $1`,
      [
        sessionResult.rows[0].id,
        checkout.checkout_url,
        checkout.provider_payment_id || null,
        checkout.callback_url || null,
        checkout.provider_payload || {},
      ],
    );

    return success(res, {
      ...checkout,
      plan_id: plan.id,
      plan_code: plan.plan_code,
      billing_cycle: billingCycle,
    });
  }));

  router.get('/payments/gateway/subscriptions/latest', requireAuth, asyncHandler(async (req, res) => {
    const reference = String(req.query?.reference || '').trim();
    let session = await findLatestSubscriptionCheckoutSession({
      userId: req.auth.uid,
      reference,
    });

    if (!session) {
      return success(res, null);
    }

    session = await refreshSubscriptionCheckoutIfNeeded(session);
    return success(res, buildSubscriptionCheckoutState(session));
  }));

  router.get('/payments/sandbox/subscriptions/checkout', asyncHandler(async (req, res) => {
    const reference = String(req.query?.reference || '').trim();
    if (!reference) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Subscription checkout',
            sessionStatus: 'failed',
            reference: '',
            message: 'The checkout reference is missing.',
          }),
        );
    }

    const session = await findSubscriptionCheckoutSessionByReference(reference);
    if (!session) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Subscription checkout',
            sessionStatus: 'failed',
            reference,
            message: 'The checkout session could not be found.',
          }),
        );
    }

    if (String(session.provider || '').trim().toLowerCase() !== 'sandbox') {
      return res.redirect(String(session.checkout_url || '').trim() || '/');
    }

    return res
      .status(200)
      .type('html')
      .send(
        buildSandboxCheckoutPage({
          reference: session.reference,
          planName: session.plan_name || 'Subscription plan',
          amount: Number(session.amount || 0).toFixed(0),
          currency: String(session.currency || 'XAF').trim().toUpperCase(),
          billingCycle: String(session.billing_cycle || 'monthly').trim(),
        }),
      );
  }));

  router.get('/payments/sandbox/subscriptions/complete', asyncHandler(async (req, res) => {
    const reference = String(req.query?.reference || '').trim();
    const outcome = String(req.query?.outcome || 'failed').trim().toLowerCase();
    if (!reference) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Subscription checkout',
            sessionStatus: 'failed',
            reference: '',
            message: 'The checkout reference is missing.',
          }),
        );
    }

    const session = await findSubscriptionCheckoutSessionByReference(reference);
    if (!session) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Subscription checkout',
            sessionStatus: 'failed',
            reference,
            message: 'The checkout session could not be found.',
          }),
        );
    }

    if (outcome === 'paid') {
      await reconcileSubscriptionCheckout({
        reference,
        payment: {
          status: 'complete',
          amount: Number(session.amount || 0),
          currency: String(session.currency || 'XAF').trim().toUpperCase(),
          completedAt: new Date().toISOString(),
          raw: {
            provider: 'sandbox',
            reference,
            outcome: 'paid',
          },
        },
      });

      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Subscription checkout',
            sessionStatus: 'paid',
            reference,
            message:
              'Payment confirmed. Return to the app and the active plan will refresh automatically.',
          }),
        );
    }

    await query(
      `UPDATE subscription_checkout_sessions
       SET provider_status = 'failed',
           session_status = 'failed',
           error_message = 'The checkout was cancelled before completion.',
           verified_at = now(),
           updated_at = now()
       WHERE reference = $1`,
      [reference],
    );

    return res
      .status(200)
      .type('html')
      .send(
        buildPaymentStatusPage({
          providerLabel: 'Subscription checkout',
          sessionStatus: 'failed',
          reference,
          message:
            'The checkout was cancelled. You can return to the app and choose another plan when you are ready.',
        }),
      );
  }));

  router.get('/payments/notchpay/return', asyncHandler(async (req, res) => {
    const reference = String(req.query?.reference || '').trim();
    if (!reference) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Notch Pay',
            sessionStatus: 'pending',
            reference: '',
            message:
              'We received the browser return but no subscription reference was attached.',
          }),
        );
    }

    try {
      const payment = await retrievePaymentByReference(reference);
      const reconciliation = await reconcileSubscriptionCheckout({
        reference,
        payment,
      });
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Notch Pay',
            sessionStatus: reconciliation.sessionStatus,
            reference,
            message:
              reconciliation.sessionStatus === 'paid'
                ? 'Your payment was confirmed and the subscription is now active.'
                : 'Your payment is still pending review with the gateway. Refresh the subscription page in the app shortly.',
          }),
        );
    } catch (error) {
      return res
        .status(200)
        .type('html')
        .send(
          buildPaymentStatusPage({
            providerLabel: 'Notch Pay',
            sessionStatus: 'failed',
            reference,
            message:
              error?.message ||
              'We could not confirm this payment yet. Refresh the app or contact support if the charge succeeded.',
          }),
        );
    }
  }));

  router.post('/webhooks/notchpay', asyncHandler(async (req, res) => {
    const signature = String(req.get('notchpay-signature') || '').trim();
    const rawPayload = req.rawBody || JSON.stringify(req.body || {});
    if (!verifyNotchPayWebhookSignature(rawPayload, signature)) {
      throw badRequest('Invalid Notch Pay webhook signature.');
    }

    const eventType = extractNotchPayWebhookEventType(req.body);
    const reference = extractNotchPayWebhookReference(req.body);

    if (!eventType.startsWith('payment.') || !reference) {
      return success(res, {
        received: true,
        ignored: true,
      });
    }

    const payment = await retrievePaymentByReference(reference);
    const reconciliation = await reconcileSubscriptionCheckout({
      reference,
      payment,
    });

    return success(res, {
      received: true,
      event: eventType,
      reference,
      session_status: reconciliation.sessionStatus,
    });
  }));

  router.post('/payments/withdraw', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.amount) {
      throw badRequest('amount is required.');
    }
    const result = await query(
      `INSERT INTO payout_requests (user_id, payment_method_id, amount, currency, reason)
       VALUES ($1,$2,$3,COALESCE($4,'XAF'),$5)
       RETURNING uuid, status, amount, currency, requested_at`,
      [req.auth.uid, req.body?.payment_method_id ?? null, req.body.amount, req.body?.currency ?? null, req.body?.reason ?? null],
    );
    return success(res, result.rows[0], undefined, 201);
  }));

  router.get('/subscriptions/plans', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, plan_name, plan_code, price_monthly, price_yearly, currency,
              max_listings, max_photos_per_listing, max_videos_per_listing,
              featured_listings_included, priority_support, analytics_access,
              api_access, bulk_listing_tools, company_profile, badge_display,
              transaction_fee_percentage, description, features
       FROM subscription_plans
       WHERE is_active = true
       ORDER BY sort_order ASC`,
    );
    return success(res, result.rows);
  }));

  router.post('/subscriptions', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.plan_id || !req.body?.billing_cycle || !req.body?.start_date || !req.body?.end_date) {
      throw badRequest('plan_id, billing_cycle, start_date, and end_date are required.');
    }
    const billingCycle = sanitizeBillingCycle(req.body?.billing_cycle);
    const plan = await query('SELECT * FROM subscription_plans WHERE id = $1 LIMIT 1', [req.body.plan_id]);
    const row = plan.rows[0];
    if (!row) {
      throw badRequest('Selected plan was not found.');
    }
    if (isPaidPlan(row)) {
      throw badRequest('Paid subscriptions must be activated through secure checkout.');
    }
    const result = await query(
      `INSERT INTO user_subscriptions (
          user_id, plan_id, subscription_status, billing_cycle, start_date, end_date,
          next_billing_date, price_paid, currency, listing_count_limit, featured_count_limit
       )
       VALUES ($1,$2,'active',$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING id, subscription_status, start_date, end_date`,
      [
        req.auth.uid,
        row.id,
        billingCycle,
        req.body.start_date,
        req.body.end_date,
        req.body.next_billing_date ?? req.body.end_date,
        req.body.price_paid ?? row.price_monthly,
        row.currency,
        row.max_listings,
        row.featured_listings_included,
      ],
    );
    return success(res, result.rows[0], undefined, 201);
  }));

  router.get('/subscriptions/current', requireAuth, asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT us.*, sp.plan_name, sp.plan_code, sp.description, sp.badge_display,
              sp.max_listings, sp.max_photos_per_listing, sp.max_videos_per_listing,
              sp.featured_listings_included, sp.priority_support, sp.analytics_access,
              sp.api_access, sp.bulk_listing_tools, sp.company_profile
       FROM user_subscriptions us
       JOIN subscription_plans sp ON sp.id = us.plan_id
       WHERE us.user_id = $1
         AND us.subscription_status IN ('active', 'pending')
       ORDER BY us.created_at DESC
       LIMIT 1`,
      [req.auth.uid],
    );
    return success(res, result.rows[0] ?? null);
  }));

  router.put('/subscriptions/cancel', requireAuth, asyncHandler(async (req, res) => {
    await query(
      `UPDATE user_subscriptions
       SET subscription_status = 'cancelled', cancelled_at = now(), cancellation_reason = $2, updated_at = now()
       WHERE user_id = $1 AND subscription_status = 'active'`,
      [req.auth.uid, req.body?.cancellation_reason ?? null],
    );
    return success(res, { cancelled: true });
  }));

  router.put('/subscriptions/upgrade', requireAuth, asyncHandler(async (req, res) => {
    if (!req.body?.plan_id) {
      throw badRequest('plan_id is required.');
    }
    const planResult = await query(
      'SELECT id, price_monthly, price_yearly FROM subscription_plans WHERE id = $1 LIMIT 1',
      [req.body.plan_id],
    );
    const plan = planResult.rows[0];
    if (!plan) {
      throw badRequest('Selected plan was not found.');
    }
    if (isPaidPlan(plan)) {
      throw badRequest('Paid subscriptions must be activated through secure checkout.');
    }
    await query(
      `UPDATE user_subscriptions
       SET plan_id = $2, updated_at = now()
       WHERE user_id = $1 AND subscription_status = 'active'`,
      [req.auth.uid, plan.id],
    );
    return success(res, { upgraded: true, plan_id: plan.id });
  }));

  router.get('/currencies', asyncHandler(async (req, res) => {
    const result = await query(
      'SELECT code, name, symbol, is_active FROM currencies WHERE is_active = true ORDER BY code ASC',
    );
    return success(res, result.rows);
  }));

  router.get('/currencies/rates', asyncHandler(async (req, res) => {
    const base = String(req.query.base ?? 'XAF');
    const result = await query(
      `SELECT base_currency, quote_currency, rate, effective_at
       FROM exchange_rates er
       WHERE er.base_currency = $1
         AND er.effective_at = (
           SELECT MAX(effective_at) FROM exchange_rates latest
           WHERE latest.base_currency = er.base_currency
             AND latest.quote_currency = er.quote_currency
         )
       ORDER BY quote_currency ASC`,
      [base],
    );
    return success(res, result.rows);
  }));

  router.get('/currencies/convert', asyncHandler(async (req, res) => {
    const amount = Number(req.query.amount ?? 0);
    const from = String(req.query.from ?? 'XAF');
    const to = String(req.query.to ?? 'XAF');
    if (!Number.isFinite(amount) || amount <= 0) {
      throw badRequest('amount must be a positive number.');
    }
    if (from === to) {
      return success(res, { amount, from, to, rate: 1, converted_amount: amount });
    }
    const direct = await query(
      `SELECT rate
       FROM exchange_rates
       WHERE base_currency = $1 AND quote_currency = $2
       ORDER BY effective_at DESC
       LIMIT 1`,
      [from, to],
    );
    let rate = Number(direct.rows[0]?.rate ?? 0);
    if (!rate) {
      const inverse = await query(
        `SELECT rate
         FROM exchange_rates
         WHERE base_currency = $1 AND quote_currency = $2
         ORDER BY effective_at DESC
         LIMIT 1`,
        [to, from],
      );
      const inverseRate = Number(inverse.rows[0]?.rate ?? 0);
      rate = inverseRate ? 1 / inverseRate : 0;
    }
    if (!rate) {
      throw badRequest(`No exchange rate available for ${from}/${to}.`);
    }
    return success(res, {
      amount,
      from,
      to,
      rate,
      converted_amount: Number((amount * rate).toFixed(2)),
    });
  }));

  router.get('/services/catalog', asyncHandler(async (req, res) => {
    const result = await query(
      `SELECT id, service_code, service_name, service_type, billing_model, price_xaf, target_roles, description, metadata
       FROM platform_service_catalog
       WHERE is_active = true
       ORDER BY service_name ASC`,
    );
    return success(res, result.rows);
  }));

  router.get('/services/orders', requireAuth, asyncHandler(async (req, res) => {
    const { limit, offset, page } = getPagination(req.query);
    const result = await query(
      `SELECT so.uuid, so.status, so.amount_xaf, so.currency, so.created_at, psc.service_name, psc.service_code
       FROM service_orders so
       JOIN platform_service_catalog psc ON psc.id = so.service_id
       WHERE so.user_id = $1
       ORDER BY so.created_at DESC
       LIMIT $2 OFFSET $3`,
      [req.auth.uid, limit, offset],
    );
    return success(res, result.rows, { page, limit, count: result.rows.length });
  }));

  router.post('/services/orders', requireAuth, asyncHandler(async (req, res) => {
    const service = await query(
      'SELECT * FROM platform_service_catalog WHERE id = $1 LIMIT 1',
      [req.body?.service_id],
    );
    const row = service.rows[0];
    if (!row) {
      throw badRequest('service_id is invalid.');
    }
    const result = await query(
      `INSERT INTO service_orders (
          user_id, service_id, property_id, transaction_id, status, amount_xaf, currency, requested_metadata
       )
       VALUES (
         $1, $2,
         (SELECT id FROM properties WHERE uuid = $3),
         (SELECT id FROM transactions WHERE uuid = $4),
         'pending_payment',
         $5,
         'XAF',
         COALESCE($6,'{}'::jsonb)
       )
       RETURNING uuid, status, amount_xaf, created_at`,
      [
        req.auth.uid,
        row.id,
        req.body?.property_id ?? null,
        req.body?.transaction_id ?? null,
        row.price_xaf,
        JSON.stringify(req.body?.requested_metadata ?? {}),
      ],
    );
    return success(res, result.rows[0], undefined, 201);
  }));

  return router;
}

module.exports = { buildCommerceRouter };
