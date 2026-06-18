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

    if (!stripeSecretKey) {
      throw new Error('Stripe is not configured. Please add STRIPE_SECRET_KEY to your Supabase secrets.');
    }

    const isTestMode = stripeSecretKey.startsWith('sk_test_');
    console.log('[save-payment-method] Stripe mode:', isTestMode ? 'TEST' : 'LIVE');

    const supabase = createClient(supabaseUrl, supabaseKey);

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

    const { paymentMethodId } = await req.json();

    if (!paymentMethodId) {
      throw new Error('Payment method ID is required');
    }

    console.log('[save-payment-method] User ID:', user.id);
    console.log('[save-payment-method] Payment Method ID:', paymentMethodId);

    // Query profile with service role (bypasses RLS)
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('stripe_customer_id, user_type')
      .eq('id', user.id)
      .maybeSingle();

    console.log('[save-payment-method] Profile found:', !!profile);

    if (profileError) {
      console.error('[save-payment-method] Error fetching profile:', profileError);
      throw new Error('Unable to fetch user profile: ' + profileError.message);
    }

    // If profile doesn't exist, create it (fallback)
    let userType: string;
    let customerId: string | null;

    if (!profile) {
      console.log('[save-payment-method] Profile not found, creating...');

      const { data: newProfile, error: createError } = await supabase
        .from('profiles')
        .insert({
          id: user.id,
          email: user.email,
          full_name: user.user_metadata?.full_name || 'User',
          user_type: user.user_metadata?.user_type || 'client',
        })
        .select('stripe_customer_id, user_type')
        .single();

      if (createError || !newProfile) {
        console.error('[save-payment-method] Failed to create profile:', createError);
        throw new Error('Profile setup incomplete. Please log out and sign in again.');
      }

      userType = newProfile.user_type;
      customerId = newProfile.stripe_customer_id;
      console.log('[save-payment-method] Profile created with type:', userType);
    } else {
      userType = profile.user_type;
      customerId = profile.stripe_customer_id;
    }

    // Validate user type
    if (userType !== 'picker' && userType !== 'client') {
      throw new Error('Only pickers and clients can add payment methods');
    }

    // Create Stripe customer if needed
    if (!customerId) {
      console.log('[save-payment-method] Creating Stripe customer...');

      const customerResponse = await fetch('https://api.stripe.com/v1/customers', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          email: user.email || '',
          'metadata[user_id]': user.id,
          'metadata[user_type]': userType,
        }),
      });

      if (!customerResponse.ok) {
        const error = await customerResponse.json();
        throw new Error(error.error?.message || 'Failed to create Stripe customer');
      }

      const customer = await customerResponse.json();
      customerId = customer.id;

      await supabase
        .from('profiles')
        .update({ stripe_customer_id: customerId })
        .eq('id', user.id);

      console.log('[save-payment-method] Stripe customer created:', customerId);
    }

    // Attach payment method to customer
    console.log('[save-payment-method] Attaching payment method to customer...');

    let attachResponse = await fetch(
      `https://api.stripe.com/v1/payment_methods/${paymentMethodId}/attach`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          customer: customerId,
        }),
      }
    );

    // If customer doesn't exist, create a new one
    if (!attachResponse.ok) {
      const error = await attachResponse.json();

      // Check if the error is about a non-existent customer
      if (error.error?.code === 'resource_missing' || error.error?.message?.includes('No such customer')) {
        console.log('[save-payment-method] Customer not found in Stripe, creating new one...');

        // Create new Stripe customer
        const customerResponse = await fetch('https://api.stripe.com/v1/customers', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${stripeSecretKey}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({
            email: user.email || '',
            'metadata[user_id]': user.id,
            'metadata[user_type]': userType,
          }),
        });

        if (!customerResponse.ok) {
          const custError = await customerResponse.json();
          throw new Error(custError.error?.message || 'Failed to create Stripe customer');
        }

        const customer = await customerResponse.json();
        customerId = customer.id;

        // Update database with new customer ID
        await supabase
          .from('profiles')
          .update({ stripe_customer_id: customerId })
          .eq('id', user.id);

        console.log('[save-payment-method] New Stripe customer created:', customerId);

        // Retry attaching payment method with new customer
        attachResponse = await fetch(
          `https://api.stripe.com/v1/payment_methods/${paymentMethodId}/attach`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${stripeSecretKey}`,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
              customer: customerId,
            }),
          }
        );

        if (!attachResponse.ok) {
          const retryError = await attachResponse.json();
          throw new Error(retryError.error?.message || 'Failed to attach payment method');
        }
      } else {
        throw new Error(error.error?.message || 'Failed to attach payment method');
      }
    }

    const paymentMethod = await attachResponse.json();

    // Save to database
    let savedCard;
    let isDefault;

    if (userType === 'picker') {
      const { data: existingCards } = await supabase
        .from('picker_payment_cards')
        .select('id')
        .eq('picker_id', user.id);

      isDefault = !existingCards || existingCards.length === 0;

      const { data, error: saveError } = await supabase
        .from('picker_payment_cards')
        .insert({
          picker_id: user.id,
          stripe_payment_method_id: paymentMethodId,
          brand: paymentMethod.card.brand,
          last_four: paymentMethod.card.last4,
          exp_month: paymentMethod.card.exp_month,
          exp_year: paymentMethod.card.exp_year,
          cardholder_name: paymentMethod.billing_details?.name || '',
          is_default: isDefault,
        })
        .select()
        .single();

      if (saveError) throw saveError;
      savedCard = data;
    } else {
      const { data: existingCards } = await supabase
        .from('collector_payment_methods')
        .select('id')
        .eq('user_id', user.id);

      isDefault = !existingCards || existingCards.length === 0;

      const { data, error: saveError } = await supabase
        .from('collector_payment_methods')
        .insert({
          user_id: user.id,
          stripe_payment_method_id: paymentMethodId,
          type: 'credit_card',
          brand: paymentMethod.card.brand,
          last_four: paymentMethod.card.last4,
          exp_month: paymentMethod.card.exp_month,
          exp_year: paymentMethod.card.exp_year,
          is_default: isDefault,
        })
        .select()
        .single();

      if (saveError) throw saveError;
      savedCard = data;
    }

    // Set as default in Stripe if this is the first card
    if (isDefault) {
      await fetch(`https://api.stripe.com/v1/customers/${customerId}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          'invoice_settings[default_payment_method]': paymentMethodId,
        }),
      });

      await supabase
        .from('profiles')
        .update({ default_payment_card_id: savedCard.id })
        .eq('id', user.id);
    }

    console.log('[save-payment-method] Payment method saved successfully');

    return new Response(
      JSON.stringify({
        success: true,
        card: savedCard,
        message: 'Payment method saved successfully',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('[save-payment-method] Error:', error);
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
