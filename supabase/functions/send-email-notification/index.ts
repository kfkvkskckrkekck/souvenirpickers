import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createTransport } from 'npm:nodemailer@6.9.7';

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

interface EmailRequest {
  to: string;
  subject: string;
  type: 'order_confirmation' | 'order_shipped' | 'order_status_update' | 'message_received' | 'wishlist_price_drop' | 'new_listing_match' | 'custom_order_response' | 'new_order_picker' | 'payment_confirmation' | 'support_message_received' | 'support_ticket' | 'email_confirmation' | 'welcome_email' | 'dispute_notification';
  data: any;
}

function escapeHtml(text: string): string {
  const map: { [key: string]: string } = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;'
  };
  return text.replace(/[&<>"']/g, (m) => map[m]);
}

function generateEmailHTML(type: string, data: any): string {
  const baseStyle = `
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #2563eb 0%, #f97316 100%); color: white; padding: 30px; text-align: center; }
    .content { padding: 30px; background: #f9fafb; }
    .button { display: inline-block; background: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; margin: 20px 0; }
    .footer { padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
  `;

  switch (type) {
    case 'order_confirmation':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Order Confirmed!</h1>
          </div>
          <div class="content">
            <h2>Thank you for your order</h2>
            <p>Hi ${escapeHtml(data.customer_name || 'Customer')},</p>
            <p>Your order #${escapeHtml(data.order_id || '')} has been confirmed.</p>
            <p><strong>Item:</strong> ${escapeHtml(data.item_title || '')}</p>
            <p><strong>Total:</strong> $${escapeHtml(String(data.total_amount || '0'))}</p>
            <p>Your picker will begin working on your order soon. You'll receive updates as your item is prepared and shipped.</p>
            <a href="https://souvenirpickers.com/orders" class="button">View Order Status</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'order_shipped':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Your Order Has Shipped!</h1>
          </div>
          <div class="content">
            <h2>On its way to you</h2>
            <p>Hi ${escapeHtml(data.customer_name || 'Customer')},</p>
            <p>Great news! Your order #${escapeHtml(data.order_id || '')} has been shipped.</p>
            <p><strong>Tracking Number:</strong> ${escapeHtml(data.tracking_number || '')}</p>
            <p><strong>Estimated Delivery:</strong> ${escapeHtml(data.estimated_delivery || '')}</p>
            <a href="https://souvenirpickers.com/orders/${escapeHtml(data.order_id || '')}" class="button">Track Your Order</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'message_received':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>New Message</h1>
          </div>
          <div class="content">
            <h2>You have a new message</h2>
            <p>Hi ${escapeHtml(data.recipient_name || 'there')},</p>
            <p><strong>${escapeHtml(data.sender_name || 'A user')}</strong> sent you a message:</p>
            <blockquote style="background: white; padding: 15px; border-left: 4px solid #2563eb; margin: 20px 0;">
              ${escapeHtml(data.message_preview || '')}
            </blockquote>
            <a href="https://souvenirpickers.com/messages" class="button">View Message</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'wishlist_price_drop':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Price Drop Alert!</h1>
          </div>
          <div class="content">
            <h2>Great news!</h2>
            <p>Hi ${escapeHtml(data.user_name || 'there')},</p>
            <p>An item in your wishlist has dropped in price:</p>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h3>${escapeHtml(data.item_title || '')}</h3>
              <p style="color: #dc2626; font-size: 20px;"><strong>Was: $${escapeHtml(String(data.old_price || '0'))}</strong></p>
              <p style="color: #16a34a; font-size: 24px; font-weight: bold;">Now: $${escapeHtml(String(data.new_price || '0'))}</p>
              <p style="color: #16a34a;">Save $${escapeHtml(((data.old_price || 0) - (data.new_price || 0)).toFixed(2))}!</p>
            </div>
            <a href="https://souvenirpickers.com/listing/${escapeHtml(data.listing_id || '')}" class="button">View Item</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'new_listing_match':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>New Souvenir Match!</h1>
          </div>
          <div class="content">
            <h2>We found something you might like</h2>
            <p>Hi ${escapeHtml(data.user_name || 'there')},</p>
            <p>Based on your interests, we think you'll love this new listing:</p>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <h3>${escapeHtml(data.item_title || '')}</h3>
              <p>${escapeHtml(data.item_description || '')}</p>
              <p><strong>Location:</strong> ${escapeHtml(data.location || '')}</p>
              <p><strong>Price:</strong> $${escapeHtml(String(data.price || '0'))}</p>
            </div>
            <a href="https://souvenirpickers.com/listing/${escapeHtml(data.listing_id || '')}" class="button">View Listing</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'custom_order_response':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Custom Order Response</h1>
          </div>
          <div class="content">
            <h2>A picker responded to your request</h2>
            <p>Hi ${escapeHtml(data.customer_name || 'Customer')},</p>
            <p><strong>${escapeHtml(data.picker_name || 'A picker')}</strong> has responded to your custom order request:</p>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p><strong>Request:</strong> ${escapeHtml(data.request_title || '')}</p>
              <p><strong>Offered Price:</strong> $${escapeHtml(String(data.offered_price || '0'))}</p>
              <p>${escapeHtml(data.message || '')}</p>
            </div>
            <a href="https://souvenirpickers.com/custom-orders" class="button">View Response</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'new_order_picker':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>New Order Received!</h1>
          </div>
          <div class="content">
            <h2>You have a new order</h2>
            <p>Hi ${escapeHtml(data.picker_name || 'Picker')},</p>
            <p>Great news! You received a new order from <strong>${escapeHtml(data.customer_name || 'a customer')}</strong>.</p>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0;">
              <p><strong>Order #:</strong> ${escapeHtml(data.order_id || '')}</p>
              <p><strong>Item:</strong> ${escapeHtml(data.item_title || '')}</p>
              <p><strong>Quantity:</strong> ${escapeHtml(String(data.quantity || '1'))}</p>
              <p><strong>Amount:</strong> $${escapeHtml(String(data.total_amount || '0'))}</p>
            </div>
            <p>Please log in to accept and process this order.</p>
            <a href="https://souvenirpickers.com/orders/${escapeHtml(data.order_id || '')}" class="button">View Order Details</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'order_status_update':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Order Status Update</h1>
          </div>
          <div class="content">
            <h2>Your order has been updated</h2>
            <p>Hi ${escapeHtml(data.customer_name || 'Customer')},</p>
            <p>Your order #${escapeHtml(data.order_id || '')} status has changed to: <strong>${escapeHtml(data.new_status || '')}</strong></p>
            ${data.notes ? `<p>${escapeHtml(data.notes)}</p>` : ''}
            <a href="https://souvenirpickers.com/orders/${escapeHtml(data.order_id || '')}" class="button">View Order</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'payment_confirmation':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Payment Confirmed</h1>
          </div>
          <div class="content">
            <h2>Payment received successfully</h2>
            <p>Hi ${escapeHtml(data.customer_name || 'Customer')},</p>
            <p>We've received your payment of <strong>$${escapeHtml(String(data.amount || '0'))}</strong> for order #${escapeHtml(data.order_id || '')}.</p>
            <p>Your order is now being processed by your picker.</p>
            <a href="https://souvenirpickers.com/orders/${escapeHtml(data.order_id || '')}" class="button">View Order</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;

    case 'support_message_received':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>New Support Message</h1>
          </div>
          <div class="content">
            <h2>Support Request from ${escapeHtml(data.user_name || 'User')}</h2>
            <p><strong>From:</strong> ${escapeHtml(data.user_name || 'User')} (${escapeHtml(data.user_email || '')})</p>
            <p><strong>Time:</strong> ${new Date(data.sent_at || Date.now()).toLocaleString()}</p>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2563eb;">
              <p><strong>Message:</strong></p>
              <p style="white-space: pre-wrap;">${escapeHtml(data.message || '')}</p>
            </div>
            <p><strong>Conversation ID:</strong> ${escapeHtml(data.conversation_id || '')}</p>
            <p>Please log in to the admin panel to respond to this support request.</p>
            <a href="https://souvenirpickers.com/support" class="button">View in Admin Panel</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers Support System</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 10px;">
              Reply to this email will go to support@souvenirpickers.com
            </p>
          </div>
        </body>
        </html>
      `;

    case 'support_ticket':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>New Support Ticket</h1>
          </div>
          <div class="content">
            <h2>Support Ticket from ${escapeHtml(data.user_name || 'User')}</h2>
            <div style="background: #f3f4f6; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p><strong>Ticket ID:</strong> ${escapeHtml(data.ticket_id || '')}</p>
              <p><strong>From:</strong> ${escapeHtml(data.user_name || 'User')} (${escapeHtml(data.user_email || '')})</p>
              <p><strong>Category:</strong> ${escapeHtml(data.category || 'other')}</p>
              <p><strong>Priority:</strong> ${escapeHtml(data.priority || 'medium')}</p>
              <p><strong>Time:</strong> ${new Date(data.created_at || Date.now()).toLocaleString()}</p>
            </div>
            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2563eb;">
              <p><strong>Subject:</strong></p>
              <p style="font-size: 16px; font-weight: 600; margin-bottom: 15px;">${escapeHtml(data.subject || '')}</p>
              <p><strong>Message:</strong></p>
              <p style="white-space: pre-wrap;">${escapeHtml(data.message || '')}</p>
            </div>
            <p>Please log in to the admin panel to respond to this support ticket.</p>
            <a href="https://souvenirpickers.com/support" class="button">View Ticket in Admin Panel</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers Support System</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 10px;">
              Reply to this email will go to support@souvenirpickers.com
            </p>
          </div>
        </body>
        </html>
      `;

    case 'email_confirmation':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Welcome to SouvenirPickers!</h1>
          </div>
          <div class="content">
            <h2>Confirm Your Email Address</h2>
            <p>Hi ${escapeHtml(data.user_name || 'there')},</p>
            <p>Thank you for signing up! We're excited to have you join our community of souvenir collectors and pickers.</p>
            <p>To complete your registration and start exploring authentic souvenirs from around the world, please confirm your email address by clicking the button below:</p>
            <a href="${escapeHtml(data.confirmation_url || '')}" class="button">Confirm Email Address</a>
            <p style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb; font-size: 14px; color: #6b7280;">
              If the button doesn't work, copy and paste this link into your browser:<br>
              <span style="word-break: break-all; color: #2563eb;">${escapeHtml(data.confirmation_url || '')}</span>
            </p>
            <p style="font-size: 14px; color: #6b7280; margin-top: 20px;">
              This link will expire in 24 hours. If you didn't create an account with SouvenirPickers, you can safely ignore this email.
            </p>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 10px;">
              Need help? Contact us at support@souvenirpickers.com
            </p>
          </div>
        </body>
        </html>
      `;

    case 'welcome_email':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Welcome to SouvenirPickers!</h1>
          </div>
          <div class="content">
            <h2>Your Account is Ready</h2>
            <p>Hi ${escapeHtml(data.user_name || 'there')},</p>
            <p>Welcome to SouvenirPickers! Your account has been successfully created.</p>
            <p>We're excited to have you join our community of souvenir collectors and pickers from around the world.</p>
            <p>You can now start exploring authentic souvenirs, connect with local pickers, and discover unique items from every corner of the globe.</p>
            <a href="${escapeHtml(data.login_url || 'https://souvenirpickers.com')}" class="button">Start Exploring</a>
            <p style="margin-top: 30px;">
              <strong>What's next?</strong><br>
              - Browse listings from pickers worldwide<br>
              - Create your wishlist of desired items<br>
              - Connect with local pickers<br>
              - Start your souvenir collection
            </p>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 10px;">
              Need help? Contact us at support@souvenirpickers.com
            </p>
          </div>
        </body>
        </html>
      `;

    case 'dispute_notification':
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header" style="background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%);">
            <h1>URGENT: New Dispute Filed</h1>
          </div>
          <div class="content">
            <h2 style="color: #dc2626;">Dispute Requires Immediate Attention</h2>
            <p>A dispute has been filed on the platform and requires immediate review.</p>

            <div style="background: #fee2e2; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #dc2626;">
              <h3 style="margin-top: 0; color: #991b1b;">Dispute Details</h3>
              <p><strong>Dispute ID:</strong> ${escapeHtml(data.dispute_id || '')}</p>
              <p><strong>Order ID:</strong> ${escapeHtml(data.order_id || '')}</p>
              <p><strong>Order:</strong> ${escapeHtml(data.order_title || 'Unknown')}</p>
              <p><strong>Type:</strong> ${escapeHtml(data.dispute_type || '')}</p>
              <p><strong>Status:</strong> ${escapeHtml(data.status || 'open')}</p>
              <p><strong>Filed:</strong> ${new Date(data.created_at || Date.now()).toLocaleString()}</p>
            </div>

            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #e5e7eb;">
              <h3 style="margin-top: 0;">Parties Involved</h3>
              <p><strong>Filed By:</strong> ${escapeHtml(data.filed_by_name || 'Unknown')}<br>
              <span style="color: #6b7280; font-size: 14px;">${escapeHtml(data.filed_by_email || '')}</span></p>
              <p><strong>Against:</strong> ${escapeHtml(data.against_user_name || 'Unknown')}<br>
              <span style="color: #6b7280; font-size: 14px;">${escapeHtml(data.against_user_email || '')}</span></p>
            </div>

            <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #2563eb;">
              <p><strong>Description:</strong></p>
              <p style="white-space: pre-wrap;">${escapeHtml(data.description || 'No description provided')}</p>
            </div>

            <p style="color: #dc2626; font-weight: 600;">Please log in to the admin panel immediately to review this dispute and take appropriate action.</p>
            <a href="https://souvenirpickers.com/disputes" class="button" style="background: #dc2626;">Review Dispute Now</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers Support System</p>
            <p style="font-size: 12px; color: #9ca3af; margin-top: 10px;">
              This is an automated notification from the dispute management system
            </p>
          </div>
        </body>
        </html>
      `;

    default:
      return `
        <!DOCTYPE html>
        <html>
        <head><style>${baseStyle}</style></head>
        <body>
          <div class="header">
            <h1>Notification from SouvenirPickers</h1>
          </div>
          <div class="content">
            <p>You have a new notification from SouvenirPickers.</p>
            <a href="https://souvenirpickers.com" class="button">Visit SouvenirPickers</a>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const requestBody = await req.json();

    // Support both old format (EmailRequest) and new format (direct params)
    let to: string;
    let subject: string;
    let emailHTML: string;
    let emailType: string;

    if (requestBody.to_user_id) {
      // New format from database trigger
      // Get user email from database
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

      const userResponse = await fetch(`${supabaseUrl}/auth/v1/admin/users/${requestBody.to_user_id}`, {
        headers: {
          'Authorization': `Bearer ${supabaseServiceKey}`,
          'apikey': supabaseServiceKey
        }
      });

      if (!userResponse.ok) {
        throw new Error('Failed to fetch user email');
      }

      const userData = await userResponse.json();
      to = userData.email;
      subject = requestBody.subject;
      emailHTML = `
        <!DOCTYPE html>
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; }
            .header { background: linear-gradient(135deg, #2563eb 0%, #f97316 100%); color: white; padding: 30px; text-align: center; }
            .content { padding: 30px; background: #f9fafb; }
            .button { display: inline-block; background: #2563eb; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; margin: 20px 0; }
            .footer { padding: 20px; text-align: center; color: #6b7280; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>SouvenirPickers Notification</h1>
          </div>
          <div class="content">
            <pre style="white-space: pre-wrap; font-family: Arial, sans-serif;">${requestBody.body || ''}</pre>
          </div>
          <div class="footer">
            <p>SouvenirPickers - Connecting you with authentic souvenirs worldwide</p>
          </div>
        </body>
        </html>
      `;
      emailType = 'custom';
    } else {
      // Old format
      const emailRequest: EmailRequest = requestBody;
      to = emailRequest.to;
      subject = emailRequest.subject;
      emailHTML = generateEmailHTML(emailRequest.type, emailRequest.data);
      emailType = emailRequest.type;
    }

    console.log('Processing email notification:', {
      to,
      type: emailType,
      subject
    });

    const smtpHost = Deno.env.get('SMTP_HOST') || 'smtp.titan.email';
    const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '587');
    const smtpUser = Deno.env.get('SMTP_USER') || 'support@souvenirpickers.com';
    const smtpPass = Deno.env.get('SMTP_PASS');
    const smtpFrom = Deno.env.get('SMTP_FROM') || 'support@souvenirpickers.com';

    if (!smtpPass) {
      console.error('SMTP_PASS is not configured');
      throw new Error('SMTP password is not configured. Please set it in Supabase Edge Function settings.');
    }

    console.log('Sending email via BlueHost SMTP:', {
      host: smtpHost,
      port: smtpPort,
      user: smtpUser,
      to: to
    });

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
      from: `"SouvenirPickers" <${smtpFrom}>`,
      to: to,
      subject: subject,
      html: emailHTML,
    });

    console.log('Email sent successfully via BlueHost SMTP to:', to);

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Email notification sent successfully',
        to: to,
        subject: subject,
        type: emailType
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error processing email notification:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
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