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
    const { email, redirectTo } = await req.json();

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

    console.log('🔄 Password reset request received for:', email);

    // Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error('❌ Missing Supabase credentials');
      throw new Error('Server configuration error');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log('✓ Supabase client initialized');

    // Generate recovery link
    console.log('🔑 Generating password reset link...');
    const { data, error } = await supabase.auth.admin.generateLink({
      type: 'recovery',
      email: email,
      options: {
        redirectTo: redirectTo || 'https://souvenirpickers.com/reset-password',
      },
    });

    if (error || !data) {
      console.error('❌ Error generating recovery link:', error);
      // For security: Always return success even if user doesn't exist
      // This prevents user enumeration attacks
      return new Response(
        JSON.stringify({
          success: true,
          message: 'If an account exists for this email, you will receive a password reset link shortly.',
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
    }

    const resetLink = data.properties?.action_link;

    if (!resetLink) {
      console.error('❌ No reset link generated');
      // For security: Always return success
      return new Response(
        JSON.stringify({
          success: true,
          message: 'If an account exists for this email, you will receive a password reset link shortly.',
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
    }

    console.log('✓ Password reset link generated successfully');

    // Get SMTP configuration
    const smtpHost = Deno.env.get('SMTP_HOST');
    const smtpPort = Deno.env.get('SMTP_PORT');
    const smtpUser = Deno.env.get('SMTP_USER');
    const smtpPass = Deno.env.get('SMTP_PASS');
    const smtpFrom = Deno.env.get('SMTP_FROM');

    console.log('📧 Checking SMTP configuration...');
    const smtpConfig = {
      hasHost: !!smtpHost,
      hasPort: !!smtpPort,
      hasUser: !!smtpUser,
      hasPass: !!smtpPass,
      hasFrom: !!smtpFrom
    };
    console.log('SMTP Config status:', smtpConfig);

    if (!smtpHost || !smtpPort || !smtpUser || !smtpPass || !smtpFrom) {
      const missingFields = [];
      if (!smtpHost) missingFields.push('SMTP_HOST');
      if (!smtpPort) missingFields.push('SMTP_PORT');
      if (!smtpUser) missingFields.push('SMTP_USER');
      if (!smtpPass) missingFields.push('SMTP_PASS');
      if (!smtpFrom) missingFields.push('SMTP_FROM');

      console.error('❌ Missing SMTP configuration:', missingFields.join(', '));
      throw new Error(`SMTP configuration incomplete. Missing: ${missingFields.join(', ')}. Please configure these secrets in Supabase Dashboard > Edge Functions > send-password-reset-email > Secrets.`);
    }

    console.log('✓ SMTP configuration validated');
    console.log('📤 Sending email via SMTP...');
    console.log('SMTP Details:', {
      host: smtpHost,
      port: smtpPort,
      user: smtpUser,
      from: smtpFrom
    });

    // Create nodemailer transporter with better Bluehost compatibility
    const transporter = createTransport({
      host: smtpHost,
      port: parseInt(smtpPort),
      secure: smtpPort === '465', // Use SSL for port 465
      requireTLS: smtpPort === '587', // Use STARTTLS for port 587
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
      tls: {
        rejectUnauthorized: false,
        ciphers: 'SSLv3'
      },
      connectionTimeout: 60000,
      greetingTimeout: 30000,
      socketTimeout: 60000,
      debug: true,
      logger: true,
    });

    const htmlContent = generatePasswordResetHTML(resetLink);
    const textContent = generatePasswordResetText(resetLink);

    // Send email with improved headers for better deliverability
    const info = await transporter.sendMail({
      from: `"SouvenirPickers Support" <${smtpFrom}>`,
      to: email,
      replyTo: smtpFrom,
      subject: 'Reset Your Password - SouvenirPickers',
      text: textContent,
      html: htmlContent,
      headers: {
        'X-Priority': '1',
        'X-MSMail-Priority': 'High',
        'Importance': 'high',
        'X-Mailer': 'SouvenirPickers',
        'List-Unsubscribe': `<mailto:${smtpFrom}?subject=unsubscribe>`,
      },
    });

    console.log('✅ Password reset email sent successfully!');
    console.log('Email details:', {
      to: email,
      messageId: info.messageId,
      response: info.response,
      accepted: info.accepted,
      rejected: info.rejected
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Password reset email sent successfully! Check your email.',
        email: email,
        messageId: info.messageId
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
    console.error('❌ Error in send-password-reset-email:', err);
    console.error('Error stack:', err.stack);

    // Check if it's an SMTP configuration error
    const isSMTPError = err.message?.includes('SMTP') || err.message?.includes('Missing:');

    return new Response(
      JSON.stringify({
        error: err.message || 'Internal server error',
        details: isSMTPError ? 'SMTP configuration is missing or incomplete. Please contact support.' : 'An error occurred while processing your request.'
      }),
      {
        status: isSMTPError ? 503 : 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});

function generatePasswordResetText(resetLink: string): string {
  return `
Reset Your Password - SouvenirPickers

Hello,

We received a request to reset your password for your SouvenirPickers account.

Click the link below to create a new password:
${resetLink}

This link will expire in 1 hour for security reasons.

SECURITY NOTICE:
If you didn't request a password reset, please ignore this email. Your account remains secure and no changes have been made.

---
SouvenirPickers
Connecting Collectors with Local Pickers Worldwide

Need help? Contact us at support@souvenirpickers.com

This is an automated email. Please do not reply to this message.
  `.trim();
}

function generatePasswordResetHTML(resetLink: string): string {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Reset Your Password</title>
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
      background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
      padding: 40px 30px;
      text-align: center;
      color: white;
    }
    .lock-icon {
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
    .reset-button {
      display: inline-block;
      background: #f97316;
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
      background: #fef2f2;
      border-radius: 8px;
      padding: 15px;
      margin: 20px 0;
      font-size: 14px;
      color: #991b1b;
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
      color: #f97316;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div class="email-container">
    <div class="header">
      <div class="lock-icon">🔐</div>
      <h1>Reset Your Password</h1>
      <p>Secure your account</p>
    </div>

    <div class="content">
      <div class="greeting">
        Hello,
      </div>

      <div class="message">
        We received a request to reset your password for your SouvenirPickers account. Click the button below to create a new password.
      </div>

      <div class="button-container">
        <a href="${resetLink}" class="reset-button">Reset My Password</a>
      </div>

      <div class="expiry-notice">
        ⏰ This link will expire in 1 hour for security reasons.
      </div>

      <div class="security-notice">
        <p>⚠️ <strong>Security Notice:</strong></p>
        <p>If you didn't request a password reset, please ignore this email. Your account remains secure and no changes have been made.</p>
      </div>

      <div class="message" style="margin-top: 30px;">
        If the button doesn't work, copy and paste this link into your browser:
        <br><br>
        <span style="font-size: 12px; color: #64748b; word-break: break-all;">${resetLink}</span>
      </div>
    </div>

    <div class="footer">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <p style="margin-top: 20px;">Need help? Contact us at <a href="mailto:support@souvenirpickers.com">support@souvenirpickers.com</a></p>
      <p style="margin-top: 20px; font-size: 12px;">
        This is an automated email. Please do not reply to this message.
      </p>
    </div>
  </div>
</body>
</html>
  `.trim();
}
