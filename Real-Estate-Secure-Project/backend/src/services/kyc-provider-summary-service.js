function normalizeKycRole(role) {
  const normalized = String(role || '').trim().toLowerCase();
  switch (normalized) {
    case 'seller':
    case 'lawyer':
    case 'notary':
      return normalized;
    default:
      return 'buyer';
  }
}

function roleLabel(role) {
  switch (normalizeKycRole(role)) {
    case 'seller':
      return 'Seller';
    case 'lawyer':
      return 'Lawyer';
    case 'notary':
      return 'Notary';
    default:
      return 'Buyer';
  }
}

function roleHeadline(role) {
  switch (normalizeKycRole(role)) {
    case 'seller':
      return 'Verify the person behind each listing before land files and property packages go live.';
    case 'lawyer':
      return 'Confirm legal identity before client files and advisory work move forward in the app.';
    case 'notary':
      return 'Confirm notarial identity before signings, closing steps, and file handoffs continue.';
    default:
      return 'Confirm buyer identity before trusted enquiries, offers, and closing steps.';
  }
}

function getKycProviderSummary({ role } = {}) {
  const normalizedRole = normalizeKycRole(role);
  return {
    provider: 'sumsub',
    display_name: 'Secure identity check',
    role: normalizedRole,
    role_label: roleLabel(normalizedRole),
    integration_mode: 'hybrid_sdk',
    app_shell_owner: 'platform',
    capture_ui_owner: 'provider',
    decision_owner: 'platform',
    capture_fallback_policy: 'no_fallback',
    capabilities: [
      'native_sdk',
      'themeable_sdk',
      'access_token_refresh',
      'applicant_actions',
      'email_verification',
      'phone_verification',
    ],
    recommendation: roleHeadline(normalizedRole),
    stages: [
      {
        code: 'entry',
        label: 'Entry',
        title: 'In-app status',
        description:
          'Keep the experience in the app so people always know what is ready, what is pending, and what to do next.',
      },
      {
        code: 'capture',
        label: 'Capture',
        title: 'Guided identity check',
        description:
          'Document, selfie, liveness, email, and phone checks should feel guided and lightweight on mobile.',
      },
      {
        code: 'result',
        label: 'Result',
        title: 'Clear status in the app',
        description:
          'Bring the final result back into the app with a simple status people can trust at a glance.',
      },
    ],
  };
}

module.exports = {
  getKycProviderSummary,
};
