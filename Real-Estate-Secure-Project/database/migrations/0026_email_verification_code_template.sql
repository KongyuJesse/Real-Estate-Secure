UPDATE email_templates
SET
  subject_en = 'Your Real Estate Secure verification code',
  subject_fr = 'Votre code de verification Real Estate Secure',
  body_en = $$<!DOCTYPE html>
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
                  Hello {{first_name}}, enter the verification code below in the Real Estate Secure app to confirm {{email_address}}.
                </p>
                <div style="padding:18px 20px;border-radius:18px;background:#f8f4eb;border:1px solid #eadfcf;font-size:28px;letter-spacing:8px;line-height:1.4;color:#163328;font-weight:700;text-align:center;">
                  {{verification_code}}
                </div>
                <p style="margin:16px 0 0;font-size:14px;line-height:1.7;color:#6a6f67;">
                  This 6-digit code expires at {{expires_at}}. If you did not request it, you can safely ignore this message.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>$$,
  body_fr = $$<!DOCTYPE html>
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
                  Bonjour {{first_name}}, saisissez le code ci-dessous dans l'application Real Estate Secure pour confirmer {{email_address}}.
                </p>
                <div style="padding:18px 20px;border-radius:18px;background:#f8f4eb;border:1px solid #eadfcf;font-size:28px;letter-spacing:8px;line-height:1.4;color:#163328;font-weight:700;text-align:center;">
                  {{verification_code}}
                </div>
                <p style="margin:16px 0 0;font-size:14px;line-height:1.7;color:#6a6f67;">
                  Ce code a 6 chiffres expire a {{expires_at}}. Si vous n'etes pas a l'origine de cette demande, ignorez simplement ce message.
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>$$,
  variables = '["first_name","email_address","verification_code","expires_at"]'::jsonb,
  updated_at = now()
WHERE template_name = 'email_verification';
