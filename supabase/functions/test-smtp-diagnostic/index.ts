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
      throw new Error('Email is required');
    }

    const smtpHost = Deno.env.get('SMTP_HOST');
    const smtpUser = Deno.env.get('SMTP_USER');
    const smtpPass = Deno.env.get('SMTP_PASS');
    const smtpFrom = Deno.env.get('SMTP_FROM');

    console.log('Testing SMTP Configuration:', {
      host: smtpHost,
      user: smtpUser,
      from: smtpFrom,
      hasPassword: !!smtpPass
    });

    const results: any = {
      port587: { tested: false, success: false, error: null, details: null },
      port465: { tested: false, success: false, error: null, details: null },
    };

    // Test Port 587 (STARTTLS)
    console.log('\n=== Testing Port 587 (STARTTLS) ===');
    try {
      const transporter587 = createTransport({
        host: smtpHost,
        port: 587,
        secure: false,
        requireTLS: true,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
        tls: {
          rejectUnauthorized: false,
        },
        connectionTimeout: 30000,
      });

      await transporter587.verify();
      console.log('✅ Port 587 connection verified');

      const info = await transporter587.sendMail({
        from: `"SouvenirPickers Support" <${smtpFrom}>`,
        to: email,
        replyTo: smtpFrom,
        subject: 'SMTP Test - Port 587 - SouvenirPickers',
        text: `This is a test email sent via Port 587 (STARTTLS).\n\nIf you received this, Port 587 is working correctly!`,
        html: `<div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px;">
          <h2 style="color: #f97316;">SMTP Test Successful!</h2>
          <p>This is a test email sent via <strong>Port 587 (STARTTLS)</strong>.</p>
          <p>If you received this, your SMTP configuration is working correctly on this port!</p>
          <hr style="margin: 20px 0; border: none; border-top: 1px solid #ddd;">
          <p style="color: #666; font-size: 12px;">SouvenirPickers - SMTP Diagnostic Test</p>
        </div>`,
      });

      results.port587 = {
        tested: true,
        success: true,
        error: null,
        details: {
          messageId: info.messageId,
          response: info.response,
          accepted: info.accepted,
          rejected: info.rejected,
        }
      };
      console.log('✅ Port 587 email sent:', info.messageId);
    } catch (error: any) {
      results.port587 = {
        tested: true,
        success: false,
        error: error.message,
        details: null
      };
      console.error('❌ Port 587 failed:', error.message);
    }

    // Test Port 465 (SSL)
    console.log('\n=== Testing Port 465 (SSL) ===');
    try {
      const transporter465 = createTransport({
        host: smtpHost,
        port: 465,
        secure: true,
        auth: {
          user: smtpUser,
          pass: smtpPass,
        },
        tls: {
          rejectUnauthorized: false,
        },
        connectionTimeout: 30000,
      });

      await transporter465.verify();
      console.log('✅ Port 465 connection verified');

      const info = await transporter465.sendMail({
        from: `"SouvenirPickers Support" <${smtpFrom}>`,
        to: email,
        replyTo: smtpFrom,
        subject: 'SMTP Test - Port 465 - SouvenirPickers',
        text: `This is a test email sent via Port 465 (SSL).\n\nIf you received this, Port 465 is working correctly!`,
        html: `<div style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px;">
          <h2 style="color: #f97316;">SMTP Test Successful!</h2>
          <p>This is a test email sent via <strong>Port 465 (SSL)</strong>.</p>
          <p>If you received this, your SMTP configuration is working correctly on this port!</p>
          <hr style="margin: 20px 0; border: none; border-top: 1px solid #ddd;">
          <p style="color: #666; font-size: 12px;">SouvenirPickers - SMTP Diagnostic Test</p>
        </div>`,
      });

      results.port465 = {
        tested: true,
        success: true,
        error: null,
        details: {
          messageId: info.messageId,
          response: info.response,
          accepted: info.accepted,
          rejected: info.rejected,
        }
      };
      console.log('✅ Port 465 email sent:', info.messageId);
    } catch (error: any) {
      results.port465 = {
        tested: true,
        success: false,
        error: error.message,
        details: null
      };
      console.error('❌ Port 465 failed:', error.message);
    }

    // Determine recommendation
    const recommendation = results.port587.success
      ? 'Use Port 587 (STARTTLS) - Most reliable for Bluehost'
      : results.port465.success
        ? 'Use Port 465 (SSL) - Working but less common'
        : 'Both ports failed - Check SMTP credentials or contact Bluehost support';

    console.log('\n=== RECOMMENDATION ===');
    console.log(recommendation);

    return new Response(
      JSON.stringify({
        success: results.port587.success || results.port465.success,
        recommendation,
        results,
        testEmail: email,
        timestamp: new Date().toISOString(),
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
    console.error('Error in SMTP diagnostic:', err);
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
