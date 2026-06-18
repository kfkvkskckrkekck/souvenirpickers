import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { createTransport } from 'npm:nodemailer@6.9.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const { email } = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: 'Email is required' }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log('Generating magic link for:', email);

    const { data, error } = await supabase.auth.admin.generateLink({
      type: 'magiclink',
      email: email,
      options: {
        redirectTo: 'https://souvenirpickers.com',
      },
    });

    if (error || !data) {
      console.error('Error generating magic link:', error);
      return new Response(
        JSON.stringify({ error: error?.message || 'Failed to generate magic link' }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    const magicLink = data.properties?.action_link;
    
    if (!magicLink) {
      throw new Error('Failed to generate magic link');
    }

    const smtpHost = Deno.env.get('SMTP_HOST');
    const smtpPort = Deno.env.get('SMTP_PORT');
    const smtpUser = Deno.env.get('SMTP_USER');
    const smtpPass = Deno.env.get('SMTP_PASS');
    const smtpFrom = Deno.env.get('SMTP_FROM');

    if (!smtpHost || !smtpPort || !smtpUser || !smtpPass || !smtpFrom) {
      console.error('SMTP Configuration check:', {
        hasHost: !!smtpHost,
        hasPort: !!smtpPort,
        hasUser: !!smtpUser,
        hasPass: !!smtpPass,
        hasFrom: !!smtpFrom
      });
      throw new Error('Missing required SMTP configuration. Please set all SMTP secrets in Supabase Edge Functions settings.');
    }

    console.log('SMTP Configuration loaded:', {
      host: smtpHost,
      port: smtpPort,
      user: smtpUser,
      from: smtpFrom,
      hasPassword: !!smtpPass
    });

    const transporter = createTransport({
      host: smtpHost,
      port: parseInt(smtpPort),
      secure: parseInt(smtpPort) === 465,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
      tls: {
        rejectUnauthorized: false
      },
      connectionTimeout: 45000,
      greetingTimeout: 30000,
      socketTimeout: 45000,
    });

    const htmlContent = generateMagicLinkHTML(magicLink);

    await transporter.sendMail({
      from: `\"SouvenirPickers Support\" <${smtpFrom}>`,
      to: email,
      subject: 'Your Magic Link - SouvenirPickers',
      html: htmlContent,
    });

    console.log('Magic link email sent successfully to:', email);

    return new Response(
      JSON.stringify({ 
        message: 'Magic link sent successfully! Check your email.',
        email: email 
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (err: any) {
    console.error('Error:', err);
    return new Response(
      JSON.stringify({ error: err.message || 'Internal server error' }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

function generateMagicLinkHTML(magicLink: string): string {
  return `
<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"UTF-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
  <title>Magic Link Login</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      background-color: #f5f5f5;
      padding: 20px;
    }
    .email-container {
      max-width: 600px;
      margin: 0 auto;
      background: white;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #2563eb 0%, #1d4ed8 100%);
      padding: 40px 30px;
      text-align: center;
      color: white;
    }
    .magic-icon {
      width: 80px;
      height: 80px;
      background: rgba(255,255,255,0.2);
      border-radius: 50%;
      margin: 0 auto 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 40px;
    }
    .header h1 {
      font-size: 28px;
      margin-bottom: 8px;
      font-weight: 700;
    }
    .header p {
      font-size: 16px;
      opacity: 0.9;
    }
    .content {
      padding: 40px 30px;
    }
    .greeting {
      font-size: 18px;
      margin-bottom: 20px;
      color: #333;
    }
    .message {
      font-size: 15px;
      line-height: 1.8;
      color: #555;
      margin-bottom: 30px;
    }
    .login-button {
      display: inline-block;
      background: #2563eb;
      color: white;
      padding: 14px 32px;
      border-radius: 8px;
      text-decoration: none;
      font-weight: 600;
      font-size: 15px;
      margin: 20px 0;
      text-align: center;
    }
    .button-container {
      text-align: center;
      margin: 30px 0;
    }
    .security-notice {
      background: #fef3c7;
      border-left: 4px solid #f59e0b;
      border-radius: 8px;
      padding: 20px;
      margin: 30px 0;
    }
    .security-notice p {
      font-size: 14px;
      color: #92400e;
      margin-bottom: 8px;
    }
    .expiry-notice {
      background: #f0f9ff;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #0c4a6e;
      text-align: center;
    }
    .footer {
      background: #f8fafc;
      padding: 30px;
      text-align: center;
      border-top: 1px solid #e2e8f0;
    }
    .footer p {
      font-size: 13px;
      color: #64748b;
      margin-bottom: 8px;
    }
    .footer a {
      color: #2563eb;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class=\"email-container\">
    <div class=\"header\">
      <div class=\"magic-icon\">✨</div>
      <h1>Your Magic Link</h1>
      <p>Sign in to your account</p>
    </div>

    <div class=\"content\">
      <div class=\"greeting\">
        Hello,
      </div>

      <div class=\"message\">
        You requested a magic link to sign in to your SouvenirPickers account. Click the button below to access your account securely.
      </div>

      <div class=\"button-container\">
        <a href=\"${magicLink}\" class=\"login-button\">Sign In to SouvenirPickers</a>
      </div>

      <div class=\"expiry-notice\">
        This link will expire in 1 hour for security reasons.
      </div>

      <div class=\"security-notice\">
        <p>⚠️ <strong>Security Notice:</strong></p>
        <p>If you didn't request this magic link, please ignore this email. Your account remains secure.</p>
      </div>

      <div class=\"message\" style=\"margin-top: 30px;\">
        If the button doesn't work, copy and paste this link into your browser:
        <br><br>
        <span style=\"font-size: 12px; color: #64748b; word-break: break-all;\">${magicLink}</span>
      </div>
    </div>

    <div class=\"footer\">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <p style=\"margin-top: 20px;\">Need help? Contact us at <a href=\"mailto:support@souvenirpickers.com\">support@souvenirpickers.com</a></p>
      <p style=\"margin-top: 20px; font-size: 12px;\">
        This is an automated email. Please do not reply to this message.
      </p>
    </div>
  </div>
</body>
</html>
  `.trim();
}
