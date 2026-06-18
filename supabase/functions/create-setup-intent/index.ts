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
      console.error('STRIPE_SECRET_KEY not found in environment variables');
      throw new Error('Stripe is not configured. Please add your Stripe secret key.');
    }

    console.log('[create-setup-intent] Stripe key starts with:', stripeSecretKey.substring(0, 20));

    const supabase = createClient(supabaseUrl, supabaseKey);

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      console.error('Auth error:', authError);
      throw new Error('Unauthorized');
    }

    console.log('User authenticated:', user.id);

    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_customer_id, user_type')
      .eq('id', user.id)
      .maybeSingle();

    console.log('Profile found:', profile);

    if (!profile) {
      throw new Error('Profile not found');
    }

    // Allow both pickers and clients (collectors) to add payment methods
    if (profile.user_type !== 'picker' && profile.user_type !== 'client') {
      throw new Error('Only pickers and collectors can add payment methods. Current user type: ' + profile.user_type);
    }

    let customerId = profile.stripe_customer_id;

    if (!customerId) {
      const customerParams = new URLSearchParams({
        email: user.email || '',
        'metadata[user_id]': user.id,
        'metadata[user_type]': 'picker',
      });

      const customerResponse = await fetch('https://api.stripe.com/v1/customers', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: customerParams,
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
    }

    const setupIntentResponse = await fetch('https://api.stripe.com/v1/setup_intents', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        customer: customerId,
        'payment_method_types[]': 'card',
      }),
    });

    if (!setupIntentResponse.ok) {
      const error = await setupIntentResponse.json();
      throw new Error(error.error?.message || 'Failed to create setup intent');
    }

    const setupIntent = await setupIntentResponse.json();

    return new Response(
      JSON.stringify({
        success: true,
        clientSecret: setupIntent.client_secret,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error creating setup intent:', error);
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
