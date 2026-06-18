import { createClient } from 'npm:@supabase/supabase-js@2';
import { createTransport } from 'npm:nodemailer@6.9.7';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

interface InvoiceData {
  invoiceNumber: string;
  issueDate: string;
  dueDate: string;
  billingPeriodStart: string;
  billingPeriodEnd: string;
  billingName: string;
  billingEmail: string;
  billingAddress?: string;
  billingCity?: string;
  billingPostalCode?: string;
  billingCountry?: string;
  taxId?: string;
  subtotal: number;
  taxRate: number;
  taxAmount: number;
  totalAmount: number;
  currency: string;
  paymentMethod?: string;
  paidAt?: string;
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

    const { invoiceId } = await req.json();

    if (!invoiceId) {
      throw new Error('Invoice ID is required');
    }

    const { data: invoice, error: invoiceError } = await supabase
      .from('invoices')
      .select('*')
      .eq('id', invoiceId)
      .single();

    if (invoiceError || !invoice) {
      throw new Error('Invoice not found');
    }

    const invoiceData: InvoiceData = {
      invoiceNumber: invoice.invoice_number,
      issueDate: new Date(invoice.issue_date).toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      }),
      dueDate: new Date(invoice.due_date).toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      }),
      billingPeriodStart: new Date(invoice.billing_period_start).toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      }),
      billingPeriodEnd: new Date(invoice.billing_period_end).toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      }),
      billingName: invoice.billing_name,
      billingEmail: invoice.billing_email,
      billingAddress: invoice.billing_address,
      billingCity: invoice.billing_city,
      billingPostalCode: invoice.billing_postal_code,
      billingCountry: invoice.billing_country,
      taxId: invoice.tax_id,
      subtotal: parseFloat(invoice.subtotal),
      taxRate: parseFloat(invoice.tax_rate),
      taxAmount: parseFloat(invoice.tax_amount),
      totalAmount: parseFloat(invoice.total_amount),
      currency: invoice.currency,
      paymentMethod: invoice.payment_method,
      paidAt: invoice.paid_at ? new Date(invoice.paid_at).toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }) : undefined,
    };

    const htmlContent = generateInvoiceHTML(invoiceData);

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
      from: `"SouvenirPickers Billing" <${smtpFrom}>`,
      to: invoiceData.billingEmail,
      subject: `Invoice ${invoice.invoice_number} - SouvenirPickers`,
      html: htmlContent,
    });

    console.log(`Invoice email sent successfully to ${invoiceData.billingEmail}`);

    await supabase
      .from('invoices')
      .update({
        status: 'sent',
        sent_at: new Date().toISOString(),
      })
      .eq('id', invoiceId);

    await supabase.from('notifications').insert({
      user_id: invoice.picker_id,
      type: 'invoice',
      title: 'Invoice Issued',
      message: `Your invoice ${invoice.invoice_number} for €${invoiceData.totalAmount.toFixed(2)} has been issued and sent to ${invoiceData.billingEmail}.`,
      data: { invoice_id: invoiceId, invoice_number: invoice.invoice_number },
    });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Invoice email sent successfully',
        invoiceNumber: invoice.invoice_number,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error sending invoice email:', error);
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

function generateInvoiceHTML(invoice: InvoiceData): string {
  const currencySymbol = invoice.currency === 'EUR' ? '€' : invoice.currency === 'USD' ? '$' : invoice.currency;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invoice ${invoice.invoiceNumber}</title>
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
    .invoice-container {
      max-width: 800px;
      margin: 0 auto;
      background: white;
      padding: 40px;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: start;
      margin-bottom: 40px;
      padding-bottom: 20px;
      border-bottom: 3px solid #2563eb;
    }
    .company-info {
      flex: 1;
    }
    .company-name {
      font-size: 32px;
      font-weight: 700;
      color: #2563eb;
      margin-bottom: 8px;
    }
    .company-details {
      font-size: 14px;
      color: #666;
      line-height: 1.8;
    }
    .invoice-info {
      text-align: right;
    }
    .invoice-title {
      font-size: 36px;
      font-weight: 700;
      color: #333;
      margin-bottom: 8px;
    }
    .invoice-number {
      font-size: 18px;
      color: #666;
      margin-bottom: 16px;
    }
    .invoice-dates {
      font-size: 14px;
      color: #666;
    }
    .invoice-dates div {
      margin-bottom: 4px;
    }
    .section-title {
      font-size: 16px;
      font-weight: 600;
      color: #333;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .billing-info {
      margin-bottom: 40px;
    }
    .billing-details {
      background: #f8fafc;
      padding: 20px;
      border-radius: 8px;
      font-size: 14px;
      line-height: 1.8;
    }
    .billing-name {
      font-weight: 600;
      font-size: 16px;
      margin-bottom: 8px;
      color: #333;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 30px;
    }
    .items-table thead {
      background: #f1f5f9;
    }
    .items-table th {
      padding: 12px;
      text-align: left;
      font-size: 13px;
      font-weight: 600;
      color: #475569;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .items-table th:last-child,
    .items-table td:last-child {
      text-align: right;
    }
    .items-table td {
      padding: 16px 12px;
      border-bottom: 1px solid #e2e8f0;
      font-size: 14px;
    }
    .items-table tbody tr:last-child td {
      border-bottom: 2px solid #cbd5e1;
    }
    .totals {
      margin-left: auto;
      width: 300px;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      padding: 12px 0;
      font-size: 14px;
    }
    .total-row.subtotal {
      color: #666;
    }
    .total-row.tax {
      color: #666;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 16px;
      margin-bottom: 8px;
    }
    .total-row.total {
      font-size: 20px;
      font-weight: 700;
      color: #2563eb;
      padding-top: 16px;
    }
    .payment-info {
      background: #f0f9ff;
      border: 2px solid #bfdbfe;
      border-radius: 8px;
      padding: 20px;
      margin-top: 40px;
    }
    .payment-status {
      display: inline-block;
      background: #10b981;
      color: white;
      padding: 6px 16px;
      border-radius: 20px;
      font-size: 14px;
      font-weight: 600;
      margin-bottom: 12px;
    }
    .payment-details {
      font-size: 14px;
      line-height: 1.8;
      color: #0c4a6e;
    }
    .footer {
      margin-top: 60px;
      padding-top: 30px;
      border-top: 2px solid #e2e8f0;
      text-align: center;
      font-size: 13px;
      color: #94a3b8;
    }
    .footer p {
      margin-bottom: 8px;
    }
    .footer a {
      color: #2563eb;
      text-decoration: none;
    }
    @media print {
      body {
        background: white;
        padding: 0;
      }
      .invoice-container {
        box-shadow: none;
        padding: 20px;
      }
    }
  </style>
</head>
<body>
  <div class="invoice-container">
    <div class="header">
      <div class="company-info">
        <div class="company-name">SouvenirPickers</div>
        <div class="company-details">
          Global Marketplace Platform<br>
          Email: billing@souvenirpickers.com<br>
          Web: www.souvenirpickers.com
        </div>
      </div>
      <div class="invoice-info">
        <div class="invoice-title">INVOICE</div>
        <div class="invoice-number">${invoice.invoiceNumber}</div>
        <div class="invoice-dates">
          <div><strong>Issue Date:</strong> ${invoice.issueDate}</div>
          <div><strong>Due Date:</strong> ${invoice.dueDate}</div>
        </div>
      </div>
    </div>

    <div class="billing-info">
      <div class="section-title">Bill To</div>
      <div class="billing-details">
        <div class="billing-name">${invoice.billingName}</div>
        ${invoice.billingAddress ? `<div>${invoice.billingAddress}</div>` : ''}
        ${invoice.billingCity || invoice.billingPostalCode ? `<div>${invoice.billingCity || ''}${invoice.billingCity && invoice.billingPostalCode ? ', ' : ''}${invoice.billingPostalCode || ''}</div>` : ''}
        ${invoice.billingCountry ? `<div>${invoice.billingCountry}</div>` : ''}
        ${invoice.taxId ? `<div><strong>VAT ID:</strong> ${invoice.taxId}</div>` : ''}
        <div><strong>Email:</strong> ${invoice.billingEmail}</div>
      </div>
    </div>

    <table class="items-table">
      <thead>
        <tr>
          <th>Description</th>
          <th>Period</th>
          <th>Amount</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <strong>SouvenirPickers Picker Subscription</strong><br>
            <span style="color: #666; font-size: 13px;">Monthly marketplace access and tools</span>
          </td>
          <td>
            ${invoice.billingPeriodStart}<br>
            <span style="color: #666;">to</span><br>
            ${invoice.billingPeriodEnd}
          </td>
          <td>${currencySymbol}${invoice.subtotal.toFixed(2)}</td>
        </tr>
      </tbody>
    </table>

    <div class="totals">
      <div class="total-row subtotal">
        <span>Subtotal:</span>
        <span>${currencySymbol}${invoice.subtotal.toFixed(2)}</span>
      </div>
      ${invoice.taxRate > 0 ? `
      <div class="total-row tax">
        <span>VAT (${invoice.taxRate.toFixed(1)}%):</span>
        <span>${currencySymbol}${invoice.taxAmount.toFixed(2)}</span>
      </div>
      ` : ''}
      <div class="total-row total">
        <span>Total:</span>
        <span>${currencySymbol}${invoice.totalAmount.toFixed(2)} ${invoice.currency}</span>
      </div>
    </div>

    ${invoice.paidAt ? `
    <div class="payment-info">
      <div class="payment-status">✓ PAID</div>
      <div class="payment-details">
        <div><strong>Payment Date:</strong> ${invoice.paidAt}</div>
        ${invoice.paymentMethod ? `<div><strong>Payment Method:</strong> ${invoice.paymentMethod}</div>` : ''}
        <div style="margin-top: 12px; color: #065f46;">
          Thank you for your payment! This invoice has been marked as paid.
        </div>
      </div>
    </div>
    ` : ''}

    <div class="footer">
      <p><strong>SouvenirPickers</strong> - Connecting Collectors with Local Pickers Worldwide</p>
      <p>Questions about this invoice? Contact us at <a href="mailto:billing@souvenirpickers.com">billing@souvenirpickers.com</a></p>
      <p style="margin-top: 20px; font-size: 12px;">This is an automatically generated invoice.</p>
    </div>
  </div>
</body>
</html>
  `.trim();
}
