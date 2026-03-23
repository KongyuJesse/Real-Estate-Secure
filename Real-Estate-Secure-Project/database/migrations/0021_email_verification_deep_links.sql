INSERT INTO email_templates (
  template_name,
  subject_en,
  subject_fr,
  body_en,
  body_fr,
  variables,
  attachments,
  is_active
)
VALUES
  (
    'email_verification',
    'Verify your Real Estate Secure email',
    'Verifiez votre adresse email Real Estate Secure',
    $$<!DOCTYPE html>
<html lang="en">
  <body style="margin:0;background:#f5efe4;font-family:Segoe UI,Arial,sans-serif;color:#163328;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:24px;overflow:hidden;border:1px solid #e4d9c5;">
            <tr>
              <td style="padding:32px 36px;border-bottom:1px solid #efe5d5;">
                <div style="font-size:13px;letter-spacing:1.2px;text-transform:uppercase;color:#1e5a43;">Account Verification</div>
                <h1 style="margin:10px 0 0;font-size:26px;">Confirm your email address</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 36px;">
                <p style="margin:0 0 16px;font-size:15px;line-height:1.7;">
                  Hello {{first_name}}, tap the secure button below to open Real Estate Secure and finish confirming {{email_address}}.
                </p>
                <p style="margin:0 0 18px;">
                  <a href="{{verification_url}}" style="display:inline-block;padding:14px 22px;border-radius:999px;background:#1a237e;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;">
                    Open the app and verify
                  </a>
                </p>
                <p style="margin:0 0 12px;font-size:14px;line-height:1.7;color:#6a6f67;">
                  If the button does not open the app, you can still paste this verification token inside the mobile verification screen:
                </p>
                <div style="padding:18px 20px;border-radius:18px;background:#f8f4eb;border:1px solid #eadfcf;font-size:16px;line-height:1.7;color:#163328;font-weight:700;">
                  {{verification_token}}
                </div>
                <p style="margin:16px 0 0;font-size:14px;line-height:1.7;color:#6a6f67;">
                  This verification link and token expire at {{expires_at}}.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>$$,
    $$<!DOCTYPE html>
<html lang="fr">
  <body style="margin:0;background:#f5efe4;font-family:Segoe UI,Arial,sans-serif;color:#163328;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:640px;background:#ffffff;border-radius:24px;overflow:hidden;border:1px solid #e4d9c5;">
            <tr>
              <td style="padding:32px 36px;border-bottom:1px solid #efe5d5;">
                <div style="font-size:13px;letter-spacing:1.2px;text-transform:uppercase;color:#1e5a43;">Verification du compte</div>
                <h1 style="margin:10px 0 0;font-size:26px;">Confirmez votre adresse email</h1>
              </td>
            </tr>
            <tr>
              <td style="padding:28px 36px;">
                <p style="margin:0 0 16px;font-size:15px;line-height:1.7;">
                  Bonjour {{first_name}}, utilisez le bouton securise ci-dessous pour ouvrir Real Estate Secure et confirmer {{email_address}}.
                </p>
                <p style="margin:0 0 18px;">
                  <a href="{{verification_url}}" style="display:inline-block;padding:14px 22px;border-radius:999px;background:#1a237e;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;">
                    Ouvrir l'application et verifier
                  </a>
                </p>
                <p style="margin:0 0 12px;font-size:14px;line-height:1.7;color:#6a6f67;">
                  Si le bouton n'ouvre pas l'application, vous pouvez toujours coller ce jeton de verification dans l'ecran mobile de verification:
                </p>
                <div style="padding:18px 20px;border-radius:18px;background:#f8f4eb;border:1px solid #eadfcf;font-size:16px;line-height:1.7;color:#163328;font-weight:700;">
                  {{verification_token}}
                </div>
                <p style="margin:16px 0 0;font-size:14px;line-height:1.7;color:#6a6f67;">
                  Ce lien et ce jeton expirent a {{expires_at}}.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>$$,
    '["first_name","email_address","verification_token","verification_url","expires_at"]'::jsonb,
    '[]'::jsonb,
    true
  )
ON CONFLICT (template_name) DO UPDATE
SET subject_en = EXCLUDED.subject_en,
    subject_fr = EXCLUDED.subject_fr,
    body_en = EXCLUDED.body_en,
    body_fr = EXCLUDED.body_fr,
    variables = EXCLUDED.variables,
    attachments = EXCLUDED.attachments,
    is_active = EXCLUDED.is_active,
    updated_at = now();
