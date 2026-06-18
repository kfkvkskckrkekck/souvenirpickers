import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

async function calculateTaxRate(countryCode: string): Promise<number> {
  const vatRates: Record<string, number> = {
    'AT': 20, 'BE': 21, 'BG': 20, 'CY': 19, 'CZ': 21,
    'DE': 19, 'DK': 25, 'EE': 20, 'ES': 21, 'FI': 24,
    'FR': 20, 'GR': 24, 'HR': 25, 'HU': 27, 'IE': 23,
    'IT': 22, 'LT': 21, 'LU': 17, 'LV': 21, 'MT': 18,
    'NL': 21, 'PL': 23, 'PT': 23, 'RO': 19, 'SE': 25,
    'SI': 22, 'SK': 20,
  };
  return vatRates[countryCode?.toUpperCase()] || 0;
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
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');

    if (!stripeSecretKey) {
      throw new Error('Stripe is not configured. Please add STRIPE_SECRET_KEY to your Supabase secrets.');
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const { pickerId } = await req.json();

    if (!pickerId) {
      throw new Error('Picker ID is required');
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*, default_payment_card_id, company_name, billing_email, billing_address, billing_city, billing_postal_code, billing_country, tax_id, email, full_name')
      .eq('id', pickerId)
      .eq('user_type', 'picker')
      .maybeSingle();

    if (profileError || !profile) {
      throw new Error('Picker not found');
    }

    if (!profile.stripe_customer_id) {
      throw new Error('No Stripe customer found. Please add a payment method first.');
    }

    if (!profile.default_payment_card_id) {
      throw new Error('No default payment method found. Please add a payment method.');
    }

    const { data: paymentCard, error: cardError } = await supabase
      .from('picker_payment_cards')
      .select('*')
      .eq('id', profile.default_payment_card_id)
      .maybeSingle();

    if (cardError || !paymentCard) {
      throw new Error('Payment method not found');
    }

    const amount = 1000;
    const currency = 'eur';

    const paymentIntentResponse = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        amount: amount.toString(),
        currency: currency,
        customer: profile.stripe_customer_id,
        payment_method: paymentCard.stripe_payment_method_id,
        off_session: 'true',
        confirm: 'true',
        description: 'LiveSouvenir Picker Monthly Subscription',
        'metadata[picker_id]': pickerId,
        'metadata[subscription_type]': 'picker_monthly',
      }),
    });

    if (!paymentIntentResponse.ok) {
      const error = await paymentIntentResponse.json();

      const { error: failError } = await supabase
        .from('picker_subscription_payments')
        .insert({
          picker_id: pickerId,
          amount: (amount / 100).toFixed(2),
          currency: currency,
          payment_status: 'failed',
          billing_period_start: new Date(),
          billing_period_end: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          payment_method_used: `${paymentCard.card_brand} ****${paymentCard.card_last4}`,
          failure_reason: error.error?.message || 'Payment failed',
        });

      await supabase
        .from('profiles')
        .update({
          payment_failed: true,
          subscription_status: 'past_due'
        })
        .eq('id', pickerId);

      throw new Error(error.error?.message || 'Payment failed');
    }

    const paymentIntent = await paymentIntentResponse.json();

    const billingStart = new Date();
    const billingEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

    const { data: paymentRecord, error: paymentError } = await supabase
      .from('picker_subscription_payments')
      .insert({
        picker_id: pickerId,
        amount: (amount / 100).toFixed(2),
        currency: currency,
        stripe_payment_intent_id: paymentIntent.id,
        payment_status: 'succeeded',
        billing_period_start: billingStart,
        billing_period_end: billingEnd,
        payment_method_used: `${paymentCard.card_brand} ****${paymentCard.card_last4}`,
        paid_at: new Date(),
      })
      .select()
      .single();

    if (paymentError) {
      throw paymentError;
    }

    await supabase
      .from('profiles')
      .update({
        last_payment_date: new Date(),
        next_payment_due: billingEnd,
        payment_failed: false,
        subscription_status: 'active',
      })
      .eq('id', pickerId);

    const taxRate = await calculateTaxRate(profile.billing_country || '');
    const subtotal = amount / 100;
    const taxAmount = (subtotal * taxRate) / 100;
    const totalAmount = subtotal + taxAmount;

    const { data: invoiceNumberData } = await supabase.rpc('generate_invoice_number');
    const invoiceNumber = invoiceNumberData || 'INV-ERROR';

    const { data: invoice, error: invoiceError } = await supabase
      .from('invoices')
      .insert({
        invoice_number: invoiceNumber,
        picker_id: pickerId,
        payment_id: paymentRecord.id,
        issue_date: new Date(),
        due_date: new Date(),
        billing_period_start: billingStart,
        billing_period_end: billingEnd,
        subtotal: subtotal.toFixed(2),
        tax_rate: taxRate,
        tax_amount: taxAmount.toFixed(2),
        total_amount: totalAmount.toFixed(2),
        currency: currency.toUpperCase(),
        status: 'paid',
        payment_method: `${paymentCard.card_brand} ****${paymentCard.card_last4}`,
        paid_at: new Date(),
        billing_name: profile.company_name || profile.full_name || 'LiveSouvenir Picker',
        billing_email: profile.billing_email || profile.email,
        billing_address: profile.billing_address,
        billing_city: profile.billing_city,
        billing_postal_code: profile.billing_postal_code,
        billing_country: profile.billing_country,
        tax_id: profile.tax_id,
      })
      .select()
      .single();

    if (!invoiceError && invoice) {
      try {
        await fetch(`${supabaseUrl}/functions/v1/send-invoice-email`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${supabaseKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ invoiceId: invoice.id }),
        });
      } catch (emailError) {
        console.error('Failed to send invoice email:', emailError);
      }
    }

    await supabase
      .from('notifications')
      .insert({
        user_id: pickerId,
        title: 'Subscription Payment Successful',
        message: `Your monthly subscription payment of €${(amount / 100).toFixed(2)} has been processed successfully. Invoice ${invoiceNumber} has been sent to your email.`,
        type: 'payment',
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Subscription payment processed successfully',
        amount: (amount / 100).toFixed(2),
        currency: currency,
        payment_intent_id: paymentIntent.id,
        next_payment_due: billingEnd,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error processing subscription payment:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});