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
      throw new Error('Stripe is not configured');
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const now = new Date();
    const trialEndDate = new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000);

    const { data: pickersNeedingPayment, error: pickersError } = await supabase
      .from('profiles')
      .select('id, email, full_name, next_payment_due, trial_end_date, stripe_customer_id, default_payment_card_id')
      .eq('user_type', 'picker')
      .or(`next_payment_due.lte.${now.toISOString()},and(trial_end_date.lte.${now.toISOString()},next_payment_due.is.null)`)
      .not('stripe_customer_id', 'is', null)
      .not('default_payment_card_id', 'is', null);

    if (pickersError) {
      throw pickersError;
    }

    if (!pickersNeedingPayment || pickersNeedingPayment.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No subscriptions due for payment',
          processed: 0,
        }),
        {
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        }
      );
    }

    const results = [];

    for (const picker of pickersNeedingPayment) {
      try {
        const { data: paymentCard } = await supabase
          .from('picker_payment_cards')
          .select('*')
          .eq('id', picker.default_payment_card_id)
          .maybeSingle();

        if (!paymentCard) {
          await supabase
            .from('notifications')
            .insert({
              user_id: picker.id,
              title: 'Payment Method Required',
              message: 'Please add a payment method to continue your subscription.',
              type: 'payment',
            });
          continue;
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
            customer: picker.stripe_customer_id,
            payment_method: paymentCard.stripe_payment_method_id,
            off_session: 'true',
            confirm: 'true',
            description: 'LiveSouvenir Picker Monthly Subscription',
            metadata: JSON.stringify({
              picker_id: picker.id,
              subscription_type: 'picker_monthly',
            }),
          }),
        });

        if (!paymentIntentResponse.ok) {
          const error = await paymentIntentResponse.json();

          await supabase
            .from('picker_subscription_payments')
            .insert({
              picker_id: picker.id,
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
              subscription_status: 'past_due',
            })
            .eq('id', picker.id);

          await supabase
            .from('notifications')
            .insert({
              user_id: picker.id,
              title: 'Subscription Payment Failed',
              message: `Your subscription payment of €${(amount / 100).toFixed(2)} failed. Please update your payment method to continue using LiveSouvenir as a Picker.`,
              type: 'payment',
            });

          results.push({
            picker_id: picker.id,
            status: 'failed',
            error: error.error?.message,
          });

          continue;
        }

        const paymentIntent = await paymentIntentResponse.json();

        const billingStart = new Date();
        const billingEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

        await supabase
          .from('picker_subscription_payments')
          .insert({
            picker_id: picker.id,
            amount: (amount / 100).toFixed(2),
            currency: currency,
            stripe_payment_intent_id: paymentIntent.id,
            payment_status: 'succeeded',
            billing_period_start: billingStart,
            billing_period_end: billingEnd,
            payment_method_used: `${paymentCard.card_brand} ****${paymentCard.card_last4}`,
            paid_at: new Date(),
          });

        await supabase
          .from('profiles')
          .update({
            last_payment_date: new Date(),
            next_payment_due: billingEnd,
            payment_failed: false,
            subscription_status: 'active',
          })
          .eq('id', picker.id);

        await supabase
          .from('notifications')
          .insert({
            user_id: picker.id,
            title: 'Subscription Payment Successful',
            message: `Your monthly subscription payment of €${(amount / 100).toFixed(2)} has been processed successfully. Thank you for being a LiveSouvenir Picker!`,
            type: 'payment',
          });

        results.push({
          picker_id: picker.id,
          status: 'success',
          amount: (amount / 100).toFixed(2),
          payment_intent_id: paymentIntent.id,
        });

      } catch (error) {
        console.error(`Error processing payment for picker ${picker.id}:`, error);
        results.push({
          picker_id: picker.id,
          status: 'error',
          error: error.message,
        });
      }
    }

    const successCount = results.filter(r => r.status === 'success').length;
    const failureCount = results.filter(r => r.status !== 'success').length;

    return new Response(
      JSON.stringify({
        success: true,
        message: `Processed ${results.length} subscriptions: ${successCount} successful, ${failureCount} failed`,
        processed: results.length,
        successful: successCount,
        failed: failureCount,
        results: results,
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error processing monthly subscriptions:', error);
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