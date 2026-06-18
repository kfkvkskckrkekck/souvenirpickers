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
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { pickerId } = await req.json();

    if (!pickerId) {
      throw new Error('Picker ID is required');
    }

    const billingStart = new Date();
    billingStart.setDate(1);
    const billingEnd = new Date(billingStart);
    billingEnd.setMonth(billingEnd.getMonth() + 1);

    const { error: paymentError } = await supabase
      .from('picker_subscription_payments')
      .insert({
        picker_id: pickerId,
        amount: 5.00,
        currency: 'eur',
        stripe_payment_intent_id: `test_pi_${Date.now()}`,
        payment_status: 'succeeded',
        billing_period_start: billingStart.toISOString(),
        billing_period_end: billingEnd.toISOString(),
        payment_method_used: 'Test Card',
        paid_at: new Date().toISOString(),
      });

    if (paymentError) throw paymentError;

    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        last_payment_date: new Date().toISOString(),
        next_payment_due: billingEnd.toISOString(),
        payment_failed: false,
        subscription_status: 'active',
      })
      .eq('id', pickerId);

    if (updateError) throw updateError;

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Payment processed successfully',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error: any) {
    console.error('Error processing test payment:', error);
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
