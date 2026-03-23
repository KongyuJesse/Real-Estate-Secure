const crypto = require('crypto');

const { config } = require('../config');
const { badRequest } = require('../lib/errors');

function resolvePlanAmount(plan, billingCycle) {
  const yearlyAmount = Number(plan.price_yearly);
  const monthlyAmount = Number(plan.price_monthly);
  const rawAmount =
    billingCycle === 'yearly' && Number.isFinite(yearlyAmount) && yearlyAmount > 0
      ? yearlyAmount
      : monthlyAmount;
  return Number.isFinite(rawAmount) ? Math.round(rawAmount) : 0;
}

function isSandboxSubscriptionCheckoutEnabled() {
  return (
    !config.isProduction &&
    config.paymentGatewayProvider === 'notchpay' &&
    !config.notchPayPublicKey
  );
}

function buildSandboxCheckoutUrl(appBaseUrl, reference, redirectUrl) {
  const baseUrl = String(appBaseUrl || config.appBaseUrl || '').trim();
  if (!baseUrl) {
    throw badRequest('The platform base URL is not configured for sandbox checkout.');
  }

  const url = new URL('/payments/sandbox/subscriptions/checkout', baseUrl);
  url.searchParams.set('reference', reference);
  if (String(redirectUrl || '').trim().length > 0) {
    url.searchParams.set('redirect_url', String(redirectUrl).trim());
  }
  return url.toString();
}

function getPaymentGatewaySummary() {
  if (isSandboxSubscriptionCheckoutEnabled()) {
    return {
      provider: 'sandbox',
      configured: true,
      currency: 'XAF',
      collection_rails: ['mobile_money', 'card', 'bank_transfer'],
      payout_rails: [],
      recurring_support: false,
      checkout_mode: 'platform_sandbox',
      selection_ui_owner: 'platform',
      checkout_ui_owner: 'platform',
      reconciliation_owner: 'platform',
      webhook_reconciliation: false,
      recommended_for:
        'Local subscription checkout for development while live gateway credentials are being configured.',
    };
  }

  const provider = config.paymentGatewayProvider;
  if (provider === 'notchpay') {
    return {
      provider,
      configured: Boolean(config.notchPayPublicKey),
      currency: 'XAF',
      collection_rails: ['mobile_money', 'bank_transfer', 'card'],
      payout_rails: ['mobile_money', 'bank_account'],
      recurring_support: false,
      checkout_mode: 'provider_hosted',
      selection_ui_owner: 'platform',
      checkout_ui_owner: 'provider',
      reconciliation_owner: 'platform',
      webhook_reconciliation: true,
      recommended_for:
        'Cameroon-first hosted checkout for subscription purchases, buyer collections, and future payout expansion.',
    };
  }

  return {
    provider,
    configured: false,
    currency: 'XAF',
    collection_rails: [],
    payout_rails: [],
    recurring_support: false,
    checkout_mode: 'provider_hosted',
    selection_ui_owner: 'platform',
    checkout_ui_owner: 'provider',
    reconciliation_owner: 'platform',
    webhook_reconciliation: false,
    recommended_for: 'Not configured',
  };
}

function extractPayloadData(payload) {
  if (payload && typeof payload === 'object' && payload.data && typeof payload.data === 'object') {
    return payload.data;
  }
  return payload && typeof payload === 'object' ? payload : {};
}

function extractNotchPayPaymentObject(payload) {
  const data = extractPayloadData(payload);
  if (data.payment && typeof data.payment === 'object') {
    return data.payment;
  }
  if (data.transaction && typeof data.transaction === 'object') {
    return data.transaction;
  }
  return data;
}

function extractNotchPayCheckoutUrl(payload) {
  const data = extractPayloadData(payload);
  return String(
    data.authorization_url ||
      data.checkout_url ||
      data.payment_url ||
      data.link ||
      '',
  ).trim();
}

function extractNotchPayPaymentId(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  return String(payment.id || '').trim();
}

function extractNotchPayReference(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  return String(payment.reference || '').trim();
}

function extractNotchPayStatus(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  return String(payment.status || '').trim().toLowerCase();
}

function extractNotchPayAmount(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  const value = Number(payment.amount);
  return Number.isFinite(value) ? value : 0;
}

function extractNotchPayCurrency(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  return String(payment.currency || 'XAF').trim().toUpperCase();
}

function extractNotchPayCompletedAt(payload) {
  const payment = extractNotchPayPaymentObject(payload);
  return payment.completed_at || payment.completedAt || null;
}

function normalizeNotchPayPayment(payload) {
  return {
    provider: 'notchpay',
    paymentId: extractNotchPayPaymentId(payload),
    reference: extractNotchPayReference(payload),
    status: extractNotchPayStatus(payload),
    amount: extractNotchPayAmount(payload),
    currency: extractNotchPayCurrency(payload),
    completedAt: extractNotchPayCompletedAt(payload),
    raw: payload,
  };
}

function buildNotchPayCallbackUrl(redirectUrl, reference) {
  const baseUrl = String(redirectUrl || config.notchPayCallbackUrl || '').trim();
  if (!baseUrl) {
    return '';
  }
  try {
    const url = new URL(baseUrl);
    url.searchParams.set('reference', reference);
    return url.toString();
  } catch (_) {
    return baseUrl;
  }
}

async function createSubscriptionCheckout({
  sessionReference,
  plan,
  billingCycle,
  customer,
  redirectUrl,
  appBaseUrl,
}) {
  if (isSandboxSubscriptionCheckoutEnabled()) {
    const amount = resolvePlanAmount(plan, billingCycle);
    const checkoutUrl = buildSandboxCheckoutUrl(
      appBaseUrl,
      sessionReference,
      redirectUrl,
    );
    return {
      provider: 'sandbox',
      tx_ref: sessionReference,
      checkout_url: checkoutUrl,
      amount,
      currency: plan.currency || 'XAF',
      provider_payment_id: sessionReference,
      callback_url: String(redirectUrl || '').trim(),
      provider_payload: {
        mode: 'sandbox',
        amount,
        currency: plan.currency || 'XAF',
      },
    };
  }

  if (config.paymentGatewayProvider !== 'notchpay') {
    throw badRequest('The configured payment gateway provider is not supported.');
  }
  if (!config.notchPayPublicKey) {
    throw badRequest('Notch Pay credentials are not configured.');
  }

  const amount = resolvePlanAmount(plan, billingCycle);
  const callbackUrl = buildNotchPayCallbackUrl(redirectUrl, sessionReference);
  const response = await fetch(`${config.notchPayBaseUrl}/payments`, {
    method: 'POST',
    headers: {
      Authorization: config.notchPayPublicKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      amount,
      currency: plan.currency || 'XAF',
      reference: sessionReference,
      callback: callbackUrl || undefined,
      customer: {
        email: customer.email,
        name: customer.name,
      },
      description: `${plan.plan_name} subscription (${billingCycle})`,
      metadata: {
        type: 'subscription',
        plan_id: plan.id,
        plan_code: plan.plan_code,
        billing_cycle: billingCycle,
        user_id: customer.userId,
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw badRequest(
      payload?.message?.toString() || 'Notch Pay checkout initialization failed.',
    );
  }

  const checkoutUrl = extractNotchPayCheckoutUrl(payload);
  if (!checkoutUrl) {
    throw badRequest('Notch Pay did not return a usable checkout link.');
  }

  return {
    provider: 'notchpay',
    tx_ref: sessionReference,
    checkout_url: checkoutUrl,
    amount,
    currency: plan.currency || 'XAF',
    provider_payment_id: extractNotchPayPaymentId(payload),
    callback_url: callbackUrl,
    provider_payload: payload,
  };
}

async function retrievePaymentByReference(reference) {
  if (!config.notchPayPublicKey) {
    throw badRequest('Notch Pay credentials are not configured.');
  }

  const response = await fetch(
    `${config.notchPayBaseUrl}/payments/${encodeURIComponent(reference)}`,
    {
      method: 'GET',
      headers: {
        Authorization: config.notchPayPublicKey,
        'Content-Type': 'application/json',
      },
    },
  );

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw badRequest(
      payload?.message?.toString() || 'Notch Pay payment verification failed.',
    );
  }

  return normalizeNotchPayPayment(payload);
}

function timingSafeEqualHex(left, right) {
  if (!left || !right) {
    return false;
  }
  const leftBuffer = Buffer.from(String(left).trim(), 'utf8');
  const rightBuffer = Buffer.from(String(right).trim(), 'utf8');
  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }
  return crypto.timingSafeEqual(leftBuffer, rightBuffer);
}

function verifyNotchPayWebhookSignature(payload, signature) {
  if (!config.notchPayWebhookSecret || !payload || !signature) {
    return false;
  }
  const digest = crypto
    .createHmac('sha256', config.notchPayWebhookSecret)
    .update(payload)
    .digest('hex');
  return timingSafeEqualHex(digest, signature);
}

function extractNotchPayWebhookReference(payload) {
  return String(
    payload?.data?.reference ||
      payload?.reference ||
      payload?.data?.payment?.reference ||
      payload?.payment?.reference ||
      payload?.data?.transaction?.reference ||
      payload?.transaction?.reference ||
      '',
  ).trim();
}

function extractNotchPayWebhookEventType(payload) {
  return String(payload?.event || payload?.type || '').trim().toLowerCase();
}

module.exports = {
  createSubscriptionCheckout,
  extractNotchPayWebhookEventType,
  extractNotchPayWebhookReference,
  getPaymentGatewaySummary,
  retrievePaymentByReference,
  verifyNotchPayWebhookSignature,
};
