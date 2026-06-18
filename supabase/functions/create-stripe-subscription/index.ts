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
    const stripePriceId = Deno.env.get('STRIPE_SUBSCRIPTION_PRICE_ID');

    if (!stripeSecretKey) {
      throw new Error('Stripe is not configured. Please add STRIPE_SECRET_KEY to your Supabase secrets.');
    }

    if (!stripePriceId) {
      throw new Error('Stripe Price ID is not configured. Please add STRIPE_SUBSCRIPTION_PRICE_ID to your Supabase secrets.');
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const { pickerId, paymentMethodId } = await req.json();

    if (!pickerId || !paymentMethodId) {
      throw new Error('Picker ID and Payment Method ID are required');
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*, stripe_customer_id, stripe_subscription_id, trial_ends_at')
      .eq('id', pickerId)
      .eq('user_type', 'picker')
      .maybeSingle();

    if (profileError || !profile) {
      throw new Error('Picker not found');
    }

    if (!profile.stripe_customer_id) {
      throw new Error('No Stripe customer found. Please contact support.');
    }

    // If subscription already exists, just update the payment method
    if (profile.stripe_subscription_id) {
      // Update default payment method on the subscription
      const updateSubResponse = await fetch(`https://api.stripe.com/v1/subscriptions/${profile.stripe_subscription_id}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          default_payment_method: paymentMethodId,
        }),
      });

      if (!updateSubResponse.ok) {
        const error = await updateSubResponse.json();
        throw new Error(error.error?.message || 'Failed to update subscription payment method');
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: 'Payment method updated for existing subscription',
          subscription_id: profile.stripe_subscription_id,
        }),
        {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    // Calculate trial days remaining
    const trialEndsAt = new Date(profile.trial_ends_at);
    const now = new Date();
    const trialDaysRemaining = Math.max(0, Math.ceil((trialEndsAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)));

    // Create new Stripe Subscription
    const subscriptionParams = new URLSearchParams({
      customer: profile.stripe_customer_id,
      'items[0][price]': stripePriceId,
      default_payment_method: paymentMethodId,
      'metadata[picker_id]': pickerId,
      'metadata[user_type]': 'picker',
    });

    // Add trial if user still has trial days remaining
    if (trialDaysRemaining > 0) {
      subscriptionParams.append('trial_period_days', trialDaysRemaining.toString());
    }

    const subscriptionResponse = await fetch('https://api.stripe.com/v1/subscriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${stripeSecretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: subscriptionParams,
    });

    if (!subscriptionResponse.ok) {
      const error = await subscriptionResponse.json();
      throw new Error(error.error?.message || 'Failed to create subscription');
    }

    const subscription = await subscriptionResponse.json();

    // Update profile with subscription ID
    await supabase
      .from('profiles')
      .update({
        stripe_subscription_id: subscription.id,
        subscription_status: subscription.status,
      })
      .eq('id', pickerId);

    // Send notification
    await supabase
      .from('notifications')
      .insert({
        user_id: pickerId,
        title: trialDaysRemaining > 0 ? 'Free Trial Active' : 'Subscription Activated',
        message: trialDaysRemaining > 0
          ? `Your free trial is active for ${trialDaysRemaining} more days. After that, you'll be automatically charged €10/month.`
          : 'Your subscription has been activated. You will be charged €10/month automatically.',
        type: 'payment',
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Subscription created successfully',
        subscription_id: subscription.id,
        status: subscription.status,
        trial_days: trialDaysRemaining,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error creating subscription:', error);
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
