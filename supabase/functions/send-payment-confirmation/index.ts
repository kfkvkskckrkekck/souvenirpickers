import { createClient } from 'npm:@supabase/supabase-js@2';
import { createTransport } from 'npm:nodemailer@6.9.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface PaymentConfirmationData {
  orderNumber: string;
  amount: string;
  currency: string;
  customerEmail: string;
  customerName: string;
  paymentDate: string;
  paymentMethod: string;
  itemsDescription: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { orderId, paymentIntentId } = await req.json();

    if (!orderId && !paymentIntentId) {
      throw new Error('Order ID or Payment Intent ID is required');
    }

    let order;

    if (orderId) {
      const { data, error } = await supabase
        .from('orders')
        .select('*, client:client_id(email, full_name), listing:listing_id(title)')
        .eq('id', orderId)
        .single();

      if (error || !data) {
        throw new Error('Order not found');
      }
      order = data;
    } else if (paymentIntentId) {
      const { data: paymentIntent } = await supabase
        .from('payment_intents')
        .select('order_id, amount, currency')
        .eq('stripe_payment_intent_id', paymentIntentId)
        .maybeSingle();

      if (paymentIntent) {
        const { data, error } = await supabase
          .from('orders')
          .select('*, client:client_id(email, full_name), listing:listing_id(title)')
          .eq('id', paymentIntent.order_id)
          .single();

        if (error || !data) {
          throw new Error('Order not found');
        }
        order = data;
      }
    }

    if (!order) {
      throw new Error('Order not found');
    }

    const confirmationData: PaymentConfirmationData = {
      orderNumber: order.id.substring(0, 8).toUpperCase(),
      amount: order.total_price,
      currency: 'EUR',
      customerEmail: order.client?.email || 'customer@email.com',
      customerName: order.client?.full_name || 'Valued Customer',
      paymentDate: new Date().toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      }),
      paymentMethod: 'Credit Card',
      itemsDescription: order.listing?.title || 'Custom Order',
    };

    const htmlContent = generatePaymentConfirmationHTML(confirmationData);

    const smtpHost = Deno.env.get('SMTP_HOST') || 'mail.souvenirpickers.com';
    const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '587');
    const smtpUser = Deno.env.get('SMTP_USER') || 'support@souvenirpickers.com';
    const smtpPass = Deno.env.get('SMTP_PASS');
    const smtpFrom = Deno.env.get('SMTP_FROM') || 'support@souvenirpickers.com';

    if (!smtpPass) {
      throw new Error('SMTP password is not configured');
    }

    const transporter = createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      requireTLS: smtpPort === 587,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
      tls: {
        rejectUnauthorized: false
      },
    });

    await transporter.sendMail({
      from: `"SouvenirPickers Orders" <${smtpFrom}>`,
      to: confirmationData.customerEmail,
      subject: `Payment Confirmation - Order #${confirmationData.orderNumber}`,
      html: htmlContent,
    });

    console.log(`Payment confirmation email sent successfully to ${confirmationData.customerEmail}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Payment confirmation email sent successfully',
        orderNumber: confirmationData.orderNumber,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error sending payment confirmation:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
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

function generatePaymentConfirmationHTML(data: PaymentConfirmationData): string {
  const currencySymbol = data.currency === 'EUR' ? '€' : data.currency === 'USD' ? '$' : data.currency;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payment Confirmation</title>
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
    .success-icon {
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
    .payment-details {
      background: #f8fafc;
      border-radius: 8px;
      padding: 24px;
      margin-bottom: 30px;
    }
    .detail-row {
      display: flex;
      justify-content: space-between;
      padding: 12px 0;
      border-bottom: 1px solid #e2e8f0;
      font-size: 15px;
    }
    .detail-row:last-child {
      border-bottom: none;
    }
    .detail-label {
      color: #64748b;
      font-weight: 500;
    }
    .detail-value {
      color: #1e293b;
      font-weight: 600;
    }
    .amount-highlight {
      background: #dbeafe;
      border-radius: 8px;
      padding: 20px;
      text-align: center;
      margin-bottom: 30px;
    }
    .amount-label {
      font-size: 14px;
      color: #64748b;
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .amount-value {
      font-size: 36px;
      font-weight: 700;
      color: #2563eb;
    }
    .next-steps {
      background: #f0fdf4;
      border: 2px solid #86efac;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 30px;
    }
    .next-steps h3 {
      font-size: 16px;
      color: #166534;
      margin-bottom: 12px;
      font-weight: 600;
    }
    .next-steps ul {
      list-style: none;
      padding: 0;
    }
    .next-steps li {
      padding: 8px 0;
      color: #15803d;
      font-size: 14px;
      display: flex;
      align-items: start;
    }
    .next-steps li:before {
      content: '✓';
      color: #22c55e;
      font-weight: bold;
      margin-right: 10px;
      font-size: 16px;
    }
    .cta-button {
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
    .support-section {
      background: #fef3c7;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 30px;
      text-align: center;
    }
    .support-section p {
      font-size: 14px;
      color: #92400e;
      margin-bottom: 8px;
    }
    .support-email {
      color: #b45309;
      font-weight: 600;
      text-decoration: none;
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
    .social-links {
      margin: 20px 0;
    }
    .social-links a {
      display: inline-block;
      margin: 0 8px;
      color: #64748b;
      text-decoration: none;
      font-size: 13px;
    }
  </style>
</head>
<body>
  <div class="email-container">
    <div class="header">
      <div class="success-icon">✓</div>
      <h1>Payment Successful!</h1>
      <p>Your order has been confirmed</p>
    </div>

    <div class="content">
      <div class="greeting">
        Dear ${data.customerName},
      </div>

      <div class="message">
        Thank you for your order! We're pleased to confirm that your payment has been successfully processed. Your SouvenirPickers picker will begin working on your order right away.
      </div>

      <div class="amount-highlight">
        <div class="amount-label">Amount Paid</div>
        <div class="amount-value">${currencySymbol}${parseFloat(data.amount).toFixed(2)}</div>
      </div>

      <div class="payment-details">
        <div class="detail-row">
          <span class="detail-label">Order Number</span>
          <span class="detail-value">#${data.orderNumber}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Payment Date</span>
          <span class="detail-value">${data.paymentDate}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Payment Method</span>
          <span class="detail-value">${data.paymentMethod}</span>
        </div>
        <div class="detail-row">
          <span class="detail-label">Item</span>
          <span class="detail-value">${data.itemsDescription}</span>
        </div>
      </div>

      <div class="next-steps">
        <h3>What Happens Next?</h3>
        <ul>
          <li>Your picker has been notified and will start preparing your items</li>
          <li>You'll receive updates as your order progresses</li>
          <li>Track your order status in your SouvenirPickers dashboard</li>
          <li>Once shipped, you'll receive tracking information</li>
        </ul>
      </div>

      <div style="text-align: center;">
        <a href="https://souvenirpickers.com/orders" class="cta-button">View Order Status</a>
      </div>

      <div class="support-section">
        <p><strong>Need Help?</strong></p>
        <p>Our support team is here for you. Contact us at:</p>
        <a href="mailto:support@souvenirpickers.com" class="support-email">support@souvenirpickers.com</a>
      </div>
    </div>

    <div class="footer">
      <p><strong>SouvenirPickers</strong></p>
      <p>Connecting Collectors with Local Pickers Worldwide</p>
      <div class="social-links">
        <a href="https://souvenirpickers.com">Website</a> •
        <a href="https://souvenirpickers.com/help">Help Center</a> •
        <a href="https://souvenirpickers.com/contact">Contact Us</a>
      </div>
      <p style="margin-top: 20px; font-size: 12px;">
        This is an automated confirmation email. Please do not reply to this message.
      </p>
    </div>
  </div>
</body>
</html>
  `.trim();
}
