import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Stripe from "npm:stripe@14";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2024-04-10",
});

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    // Verify authorization: accept service role key via apikey header or Authorization Bearer
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const apikeyHeader = req.headers.get("apikey");
    const authHeader = req.headers.get("Authorization");
    const token = apikeyHeader || authHeader?.replace("Bearer ", "");

    if (!token || token !== serviceRoleKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Accept both naming conventions: escrowId/pickerId (from DB functions) and order_id/picker_id (legacy)
    const body = await req.json();
    const escrow_id: string | undefined = body.escrowId || body.escrow_id;
    const picker_id: string | undefined = body.pickerId || body.picker_id;
    const order_id: string | undefined = body.orderId || body.order_id;

    if (!picker_id) {
      throw new Error("picker_id is required");
    }
    if (!escrow_id && !order_id) {
      throw new Error("Either escrowId or order_id is required");
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Resolve order_id from escrow_id if not provided
    let resolved_order_id = order_id;
    let resolved_escrow_id = escrow_id;

    if (!resolved_order_id && resolved_escrow_id) {
      const { data: escrow } = await supabase
        .from("payment_escrow")
        .select("order_id")
        .eq("id", resolved_escrow_id)
        .maybeSingle();

      if (!escrow?.order_id) {
        throw new Error("Escrow record not found");
      }
      resolved_order_id = escrow.order_id;
    }

    if (!resolved_escrow_id && resolved_order_id) {
      const { data: escrow } = await supabase
        .from("payment_escrow")
        .select("id")
        .eq("order_id", resolved_order_id)
        .maybeSingle();
      resolved_escrow_id = escrow?.id;
    }

    // Get picker's stripe account
    const { data: payoutInfo } = await supabase
      .from("picker_payout_info")
      .select("stripe_account_id, is_verified")
      .eq("picker_id", picker_id)
      .maybeSingle();

    if (!payoutInfo?.stripe_account_id) {
      throw new Error("Picker has no Stripe account set up");
    }

    if (!payoutInfo.is_verified) {
      throw new Error("Picker Stripe account is not yet verified");
    }

    // Get earnings for this order
    const { data: earning } = await supabase
      .from("picker_earnings")
      .select("*")
      .eq("order_id", resolved_order_id)
      .eq("picker_id", picker_id)
      .maybeSingle();

    if (!earning) throw new Error(`Earning record not found for order ${resolved_order_id} / picker ${picker_id}`);
    if (earning.status === "paid") throw new Error("Already paid out");

    const payoutAmount = Math.round(
      (earning.net_amount + (earning.shipping_amount || 0)) * 100
    );

    if (payoutAmount <= 0) {
      throw new Error("Payout amount must be greater than zero");
    }

    // Create Stripe Transfer to the Express account
    const transfer = await stripe.transfers.create({
      amount: payoutAmount,
      currency: earning.currency || "eur",
      destination: payoutInfo.stripe_account_id,
      metadata: {
        order_id: resolved_order_id!,
        picker_id,
        earning_id: earning.id,
      },
    });

    // Update earning status to paid
    await supabase
      .from("picker_earnings")
      .update({
        status: "paid",
        paid_at: new Date().toISOString(),
      })
      .eq("id", earning.id);

    // Release escrow
    if (resolved_escrow_id) {
      await supabase
        .from("payment_escrow")
        .update({
          status: "released",
          released_at: new Date().toISOString(),
          payout_processed: true,
        })
        .eq("id", resolved_escrow_id);
    } else {
      await supabase
        .from("payment_escrow")
        .update({
          status: "released",
          released_at: new Date().toISOString(),
          payout_processed: true,
        })
        .eq("order_id", resolved_order_id!);
    }

    // Send notification to picker
    await supabase.from("notifications").insert({
      user_id: picker_id,
      type: "payout_completed",
      title: "Payment Received",
      message: `Your payout of ${(payoutAmount / 100).toFixed(2)} ${(earning.currency || "eur").toUpperCase()} has been transferred to your account`,
      link: "/earnings",
    });

    return new Response(
      JSON.stringify({ success: true, transfer_id: transfer.id }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error processing picker payout:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
