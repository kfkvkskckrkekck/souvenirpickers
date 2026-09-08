import { createClient } from 'npm:@supabase/supabase-js@2';

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
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY');
    const supabase = createClient(supabaseUrl, supabaseKey);

    if (!stripeSecretKey) {
      throw new Error('Stripe is not configured. Please add STRIPE_SECRET_KEY to Supabase secrets.');
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const { orderId, amount, currency = 'eur', productAmount, shippingAmount } = await req.json();

    if (!orderId || !amount) {
      throw new Error('Missing required fields');
    }

    console.log('Fetching order:', { orderId, userId: user.id, productAmount, shippingAmount });

    // Use service role to bypass RLS and get order details
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .maybeSingle();

    if (orderError) {
      console.error('Order query error:', orderError);
      throw new Error('Order not found or unauthorized: ' + orderError.message);
    }

    if (!order) {
      console.error('Order not found for id:', orderId);
      throw new Error('Order not found or unauthorized');
    }

    // Verify the user owns this order
    if (order.client_id !== user.id) {
      console.error('User does not own order:', { userId: user.id, clientId: order.client_id });
      throw new Error('Order not found or unauthorized');
    }

    console.log('Order found:', { orderId: order.id, pickerId: order.picker_id });

    // Check if picker has payout account set up
    const { data: payoutInfo, error: payoutError } = await supabase
      .from('picker_payout_info')
      .select('stripe_account_id, is_verified, details_submitted, bank_account_name, bank_account_number')
      .eq('picker_id', order.picker_id)
      .maybeSingle();

    if (payoutError) {
      console.error('Error checking picker payout info:', payoutError);
    }

    // Validate picker has either Stripe Connect OR manual bank account set up
    const hasStripeConnect = payoutInfo?.stripe_account_id && payoutInfo?.is_verified;
    const hasManualBankAccount = payoutInfo?.bank_account_name && payoutInfo?.bank_account_number;

    if (!hasStripeConnect && !hasManualBankAccount) {
      throw new Error('The picker has not completed their payout account setup. Please ask them to set up their bank account in their profile before you can complete this purchase.');
    }

    console.log('Picker payout validated:', {
      hasStripeConnect,
      hasManualBankAccount,
      isVerified: payoutInfo?.is_verified,
      detailsSubmitted: payoutInfo?.details_submitted
    });

    // Idempotency guard: React StrictMode (dev), a retry, or the user
    // reopening the payment step can call this twice for the same order.
    // Reuse the existing pending intent instead of creating a second Stripe
    // PaymentIntent and violating the one-row-per-order unique constraint on
    // payment_escrow.
    const { data: existingIntent, error: existingIntentError } = await supabase
      .from('payment_intents')
      .select('client_secret, stripe_payment_intent_id, amount, currency')
      .eq('order_id', orderId)
      .eq('status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existingIntentError) {
      console.error('Error checking for existing payment intent:', existingIntentError);
    }

    if (existingIntent) {
      return new Response(
        JSON.stringify({
          clientSecret: existingIntent.client_secret,
          paymentIntentId: existingIntent.stripe_payment_intent_id,
          amount: existingIntent.amount,
          currency: existingIntent.currency,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const amountInCents = Math.round(amount * 100);

    // Simple payment intent - all payments go to platform account
    // Platform handles paying pickers separately
    const paymentIntentData = new URLSearchParams({
      amount: amountInCents.toString(),
      currency: currency.toLowerCase(),
      'metadata[order_id]': orderId,
      'metadata[user_id]': user.id,
      'metadata[picker_id]': order.picker_id,
      description: `LiveSouvenir Order #${orderId.substring(0, 8)}`,
    });

    const stripeResponse = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: paymentIntentData.toString(),
    });

    if (!stripeResponse.ok) {
      const errorData = await stripeResponse.json();
      throw new Error(errorData.error?.message || 'Failed to create payment intent with Stripe');
    }

    const stripePaymentIntent = await stripeResponse.json();

    const { data: paymentIntent, error: piError } = await supabase
      .from('payment_intents')
      .insert({
        user_id: user.id,
        order_id: orderId,
        stripe_payment_intent_id: stripePaymentIntent.id,
        amount: amount,
        currency: currency,
        status: 'pending',
        client_secret: stripePaymentIntent.client_secret,
        metadata: {
          user_id: user.id,
          order_id: orderId,
          picker_id: order.picker_id,
        },
      })
      .select()
      .single();

    if (piError) {
      throw piError;
    }

    // Create escrow record with split payment amounts
    const productAmt = productAmount || (amount - (shippingAmount || 0));
    const shippingAmt = shippingAmount || 0;

    const { error: escrowError } = await supabase
      .from('payment_escrow')
      .insert({
        order_id: orderId,
        amount: amount,
        item_amount: productAmt,
        product_amount: productAmt,
        shipping_amount: shippingAmt,
        currency: currency,
        status: 'held',
        held_at: new Date().toISOString(),
      });

    if (escrowError) {
      console.error('Error creating escrow:', escrowError);
      throw new Error('Failed to create escrow record: ' + escrowError.message);
    }

    // Create picker earnings record (will be updated to 'paid' when payout completes)
    const platformFeeRate = 0.10;
    const grossAmount = productAmt;
    const platformFee = Math.round(grossAmount * platformFeeRate * 100) / 100;
    const netAmount = grossAmount - platformFee;

    const { error: earningsError } = await supabase
      .from('picker_earnings')
      .insert({
        picker_id: order.picker_id,
        order_id: orderId,
        amount: grossAmount,
        platform_fee: platformFee,
        net_amount: netAmount,
        shipping_amount: shippingAmt,
        currency: currency,
        status: 'pending',
      });

    if (earningsError) {
      console.error('Error creating earnings record:', earningsError);
    }

    // Note: Shipping transfer happens in webhook after payment succeeds
    // This ensures funds are available before attempting the transfer

    return new Response(
      JSON.stringify({
        clientSecret: stripePaymentIntent.client_secret,
        paymentIntentId: stripePaymentIntent.id,
        amount: amount,
        currency: currency,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
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