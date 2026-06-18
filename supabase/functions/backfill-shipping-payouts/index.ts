import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!;

    // Only callable with service role key
    const apikeyHeader = req.headers.get('apikey');
    const authHeader = req.headers.get('Authorization');
    const token = apikeyHeader || authHeader?.replace('Bearer ', '');
    if (!token || token !== supabaseKey) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Find all paid orders with unpaid shipping (no shipping_transfer_id)
    const { data: orders, error: fetchError } = await supabase
      .from('orders')
      .select(`
        id,
        picker_id,
        transportation_cost,
        status,
        payment_status,
        payment_escrow!inner(id, shipping_transfer_id, shipping_paid_at),
        picker_payout_info:picker_payout_info!left(stripe_account_id, is_verified)
      `)
      .gt('transportation_cost', 0)
      .eq('payment_status', 'paid')
      .is('payment_escrow.shipping_transfer_id', null);

    if (fetchError) throw fetchError;

    const results: Record<string, unknown>[] = [];

    for (const order of (orders || [])) {
      const payoutInfo = Array.isArray(order.picker_payout_info)
        ? order.picker_payout_info[0]
        : order.picker_payout_info;

      if (!payoutInfo?.stripe_account_id || !payoutInfo?.is_verified) {
        results.push({
          order_id: order.id,
          status: 'skipped',
          reason: 'Picker has no verified Stripe account',
        });
        continue;
      }

      const shippingAmountInCents = Math.round(Number(order.transportation_cost) * 100);

      try {
        // Determine currency from escrow record
        const { data: escrow } = await supabase
          .from('payment_escrow')
          .select('currency')
          .eq('order_id', order.id)
          .maybeSingle();

        const currency = (escrow?.currency || 'eur').toLowerCase();

        const transferData = new URLSearchParams({
          amount: shippingAmountInCents.toString(),
          currency,
          destination: payoutInfo.stripe_account_id,
          'metadata[order_id]': order.id,
          'metadata[type]': 'shipping_backfill',
          description: `Shipping backfill for Order #${order.id.substring(0, 8)}`,
        });

        const transferResponse = await fetch('https://api.stripe.com/v1/transfers', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${stripeSecretKey}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: transferData.toString(),
        });

        const transfer = await transferResponse.json();

        if (!transferResponse.ok) {
          results.push({
            order_id: order.id,
            status: 'failed',
            reason: transfer.error?.message || 'Stripe transfer failed',
          });
          continue;
        }

        // Record the transfer in DB
        await supabase.rpc('record_shipping_payout', {
          p_order_id: order.id,
          p_transfer_id: transfer.id,
          p_shipping_amount: Number(order.transportation_cost),
        });

        // Notify picker
        await supabase.from('notifications').insert({
          user_id: order.picker_id,
          title: 'Shipping Payment Received',
          message: `Your shipping fee of €${Number(order.transportation_cost).toFixed(2)} for Order #${order.id.substring(0, 8)} has been transferred to your account.`,
          type: 'payment',
          link: '/earnings',
        });

        results.push({
          order_id: order.id,
          status: 'success',
          transfer_id: transfer.id,
          amount: order.transportation_cost,
          currency,
        });
      } catch (err) {
        results.push({
          order_id: order.id,
          status: 'error',
          reason: err instanceof Error ? err.message : String(err),
        });
      }
    }

    const summary = {
      total: results.length,
      success: results.filter((r) => r.status === 'success').length,
      skipped: results.filter((r) => r.status === 'skipped').length,
      failed: results.filter((r) => r.status === 'failed' || r.status === 'error').length,
      details: results,
    };

    console.log('Backfill complete:', JSON.stringify(summary));

    return new Response(JSON.stringify(summary), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Backfill error:', error);
    return new Response(JSON.stringify({ error: error instanceof Error ? error.message : String(error) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
