import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey, Stripe-Signature',
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
    const stripeWebhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
    const supabase = createClient(supabaseUrl, supabaseKey);

    const signature = req.headers.get('stripe-signature');
    const body = await req.text();

    if (stripeWebhookSecret && signature) {
      console.log('Webhook signature verification would happen here');
    }

    const event = JSON.parse(body);
    console.log('Stripe webhook event:', event.type);

    switch (event.type) {
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object;
        console.log('Payment succeeded:', paymentIntent.id);

        const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!;

        const { error: updateError } = await supabase
          .from('payment_intents')
          .update({
            status: 'succeeded',
            updated_at: new Date().toISOString()
          })
          .eq('stripe_payment_intent_id', paymentIntent.id);

        if (updateError) {
          console.error('Error updating payment intent:', updateError);
        }

        const { data: paymentIntentRecord } = await supabase
          .from('payment_intents')
          .select('order_id, amount')
          .eq('stripe_payment_intent_id', paymentIntent.id)
          .maybeSingle();

        if (paymentIntentRecord) {
          await supabase
            .from('orders')
            .update({
              status: 'paid',
              payment_status: 'paid',
              updated_at: new Date().toISOString()
            })
            .eq('id', paymentIntentRecord.order_id);

          const { data: order } = await supabase
            .from('orders')
            .select('picker_id, client_id, id, transportation_cost')
            .eq('id', paymentIntentRecord.order_id)
            .single();

          if (order) {
            // Ensure escrow record exists (may have failed during create-payment-intent)
            const { data: existingEscrow } = await supabase
              .from('payment_escrow')
              .select('id')
              .eq('order_id', order.id)
              .maybeSingle();

            if (!existingEscrow) {
              const productAmount = (paymentIntentRecord.amount || 0) - (order.transportation_cost || 0);
              await supabase.from('payment_escrow').insert({
                order_id: order.id,
                amount: paymentIntentRecord.amount,
                item_amount: productAmount,
                product_amount: productAmount,
                shipping_amount: order.transportation_cost || 0,
                currency: paymentIntent.currency || 'eur',
                status: 'held',
                held_at: new Date().toISOString(),
              });
              console.log('Created missing escrow record for order:', order.id);
            }

            // Ensure picker_earnings record exists
            const { data: existingEarning } = await supabase
              .from('picker_earnings')
              .select('id')
              .eq('order_id', order.id)
              .eq('picker_id', order.picker_id)
              .maybeSingle();

            if (!existingEarning) {
              const productAmount = (paymentIntentRecord.amount || 0) - (order.transportation_cost || 0);
              const platformFee = Math.round(productAmount * 0.10 * 100) / 100;
              const netAmount = productAmount - platformFee;
              await supabase.from('picker_earnings').insert({
                picker_id: order.picker_id,
                order_id: order.id,
                amount: productAmount,
                platform_fee: platformFee,
                net_amount: netAmount,
                shipping_amount: order.transportation_cost || 0,
                currency: paymentIntent.currency || 'eur',
                status: 'pending',
              });
              console.log('Created missing earnings record for order:', order.id);
            }

            // Transfer shipping funds immediately now that payment succeeded
            if (order.transportation_cost && order.transportation_cost > 0) {
              const { data: payoutInfo } = await supabase
                .from('picker_payout_info')
                .select('stripe_account_id, payouts_enabled')
                .eq('picker_id', order.picker_id)
                .maybeSingle();

              if (payoutInfo?.stripe_account_id && payoutInfo?.payouts_enabled) {
                console.log('Processing immediate shipping transfer:', {
                  amount: order.transportation_cost,
                  pickerId: order.picker_id,
                  stripeAccountId: payoutInfo.stripe_account_id
                });

                try {
                  const shippingAmountInCents = Math.round(order.transportation_cost * 100);

                  const transferData = new URLSearchParams({
                    amount: shippingAmountInCents.toString(),
                    currency: paymentIntent.currency,
                    destination: payoutInfo.stripe_account_id,
                    'metadata[order_id]': order.id,
                    'metadata[type]': 'shipping',
                    description: `Shipping cost for Order #${order.id.substring(0, 8)}`,
                  });

                  const transferResponse = await fetch('https://api.stripe.com/v1/transfers', {
                    method: 'POST',
                    headers: {
                      'Authorization': `Bearer ${stripeSecretKey}`,
                      'Content-Type': 'application/x-www-form-urlencoded',
                    },
                    body: transferData.toString(),
                  });

                  if (transferResponse.ok) {
                    const transfer = await transferResponse.json();
                    console.log('Shipping transfer successful:', transfer.id);

                    // Record shipping payout in database
                    await supabase.rpc('record_shipping_payout', {
                      p_order_id: order.id,
                      p_transfer_id: transfer.id,
                      p_shipping_amount: order.transportation_cost,
                    });
                  } else {
                    const errorData = await transferResponse.json();
                    console.error('Shipping transfer failed:', errorData);
                  }
                } catch (transferError) {
                  console.error('Error transferring shipping funds:', transferError);
                }
              } else {
                console.log('Picker does not have Stripe Connect enabled - shipping transfer skipped');
              }
            }

            await supabase
              .from('notifications')
              .insert([
                {
                  user_id: order.picker_id,
                  title: 'Payment Received',
                  message: `Payment of €${paymentIntentRecord.amount} received for order. Start preparing the items!`,
                  type: 'payment',
                  link: `/orders`,
                },
                {
                  user_id: order.client_id,
                  title: 'Payment Successful',
                  message: `Your payment of €${paymentIntentRecord.amount} was successful. The picker will start working on your order.`,
                  type: 'payment',
                  link: `/orders`,
                },
              ]);

            try {
              await fetch(`${supabaseUrl}/functions/v1/send-payment-confirmation`, {
                method: 'POST',
                headers: {
                  'Authorization': `Bearer ${supabaseKey}`,
                  'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                  orderId: paymentIntentRecord.order_id,
                  paymentIntentId: paymentIntent.id
                }),
              });
            } catch (emailError) {
              console.error('Failed to send payment confirmation email:', emailError);
            }
          }
        }
        break;
      }

      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object;
        console.log('Payment failed:', paymentIntent.id);

        await supabase
          .from('payment_intents')
          .update({ 
            status: 'failed',
            updated_at: new Date().toISOString()
          })
          .eq('stripe_payment_intent_id', paymentIntent.id);

        const { data: paymentIntentRecord } = await supabase
          .from('payment_intents')
          .select('order_id')
          .eq('stripe_payment_intent_id', paymentIntent.id)
          .maybeSingle();

        if (paymentIntentRecord) {
          await supabase
            .from('orders')
            .update({ 
              status: 'payment_failed',
              payment_status: 'failed',
              updated_at: new Date().toISOString()
            })
            .eq('id', paymentIntentRecord.order_id);

          const { data: order } = await supabase
            .from('orders')
            .select('client_id')
            .eq('id', paymentIntentRecord.order_id)
            .single();

          if (order) {
            await supabase
              .from('notifications')
              .insert({
                user_id: order.client_id,
                title: 'Payment Failed',
                message: 'Your payment failed. Please try again or use a different payment method.',
                type: 'payment',
                link: `/orders`,
              });
          }
        }
        break;
      }

      case 'transfer.created':
      case 'transfer.paid': {
        const transfer = event.data.object;
        console.log('Transfer event:', event.type, transfer.id);
        break;
      }

      case 'account.updated': {
        const account = event.data.object;
        console.log('Connect account updated:', account.id);

        const isVerified =
          account.charges_enabled &&
          account.payouts_enabled &&
          (!account.requirements?.currently_due || account.requirements.currently_due.length === 0);

        await supabase
          .from('picker_payout_info')
          .update({
            is_verified: isVerified,
            updated_at: new Date().toISOString(),
          })
          .eq('stripe_account_id', account.id);
        break;
      }

      case 'transfer.created': {
        const transfer = event.data.object;
        console.log('Transfer created:', transfer.id, 'to:', transfer.destination);
        break;
      }

      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const subscription = event.data.object;
        const pickerId = subscription.metadata?.picker_id;

        if (pickerId) {
          await supabase
            .from('profiles')
            .update({
              stripe_subscription_id: subscription.id,
              subscription_status: subscription.status,
              updated_at: new Date().toISOString(),
            })
            .eq('id', pickerId);

          console.log(`Subscription ${subscription.status} for picker ${pickerId}`);
        }
        break;
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object;
        const pickerId = subscription.metadata?.picker_id;

        if (pickerId) {
          await supabase
            .from('profiles')
            .update({
              subscription_status: 'cancelled',
              subscription_cancelled_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            })
            .eq('id', pickerId);

          await supabase
            .from('notifications')
            .insert({
              user_id: pickerId,
              title: 'Subscription Cancelled',
              message: 'Your subscription has been cancelled. You will lose access to picker features soon.',
              type: 'payment',
            });

          console.log(`Subscription cancelled for picker ${pickerId}`);
        }
        break;
      }

      case 'customer.subscription.trial_will_end': {
        const subscription = event.data.object;
        const pickerId = subscription.metadata?.picker_id;

        if (pickerId) {
          const trialEnd = new Date(subscription.trial_end * 1000);
          const daysRemaining = Math.ceil((trialEnd.getTime() - Date.now()) / (1000 * 60 * 60 * 24));

          await supabase
            .from('notifications')
            .insert({
              user_id: pickerId,
              title: 'Trial Ending Soon',
              message: `Your free trial ends in ${daysRemaining} days. Make sure you have a valid payment method on file to continue using LiveSouvenir.`,
              type: 'payment',
            });

          console.log(`Trial ending notification sent to picker ${pickerId}`);
        }
        break;
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object;
        const subscription = invoice.subscription;

        if (subscription && invoice.billing_reason === 'subscription_cycle') {
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email, full_name')
            .eq('stripe_subscription_id', subscription)
            .maybeSingle();

          if (profile) {
            await supabase
              .from('picker_subscription_payments')
              .insert({
                picker_id: profile.id,
                amount: (invoice.amount_paid / 100).toFixed(2),
                currency: invoice.currency,
                stripe_payment_intent_id: invoice.payment_intent,
                payment_status: 'succeeded',
                billing_period_start: new Date(invoice.period_start * 1000),
                billing_period_end: new Date(invoice.period_end * 1000),
                payment_method_used: 'Stripe Subscription',
                paid_at: new Date(invoice.status_transitions.paid_at * 1000),
              });

            await supabase
              .from('profiles')
              .update({
                last_payment_date: new Date(invoice.status_transitions.paid_at * 1000),
                next_payment_due: new Date(invoice.period_end * 1000),
                payment_failed: false,
                subscription_status: 'active',
              })
              .eq('id', profile.id);

            await supabase
              .from('notifications')
              .insert({
                user_id: profile.id,
                title: 'Subscription Payment Successful',
                message: `Your monthly subscription payment of €${(invoice.amount_paid / 100).toFixed(2)} was successful. Thank you for being a LiveSouvenir Picker!`,
                type: 'payment',
              });

            console.log(`Subscription payment recorded for picker ${profile.id}`);
          }
        }
        break;
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object;
        const subscription = invoice.subscription;

        if (subscription) {
          const { data: profile } = await supabase
            .from('profiles')
            .select('id, email')
            .eq('stripe_subscription_id', subscription)
            .maybeSingle();

          if (profile) {
            await supabase
              .from('profiles')
              .update({
                payment_failed: true,
                subscription_status: 'past_due',
              })
              .eq('id', profile.id);

            await supabase
              .from('notifications')
              .insert({
                user_id: profile.id,
                title: 'Subscription Payment Failed',
                message: `Your subscription payment of €${(invoice.amount_due / 100).toFixed(2)} failed. Please update your payment method to avoid service interruption.`,
                type: 'payment',
              });

            console.log(`Payment failed for picker ${profile.id}`);
          }
        }
        break;
      }

      default:
        console.log('Unhandled webhook event type:', event.type);
    }

    return new Response(
      JSON.stringify({ received: true }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(
      JSON.stringify({ received: true, error: error.message }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});
