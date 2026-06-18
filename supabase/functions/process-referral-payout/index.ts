import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import Stripe from "npm:stripe@17.5.0";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
  apiVersion: "2024-12-18.acacia",
});

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const { referralId } = await req.json();

    if (!referralId) {
      return new Response(
        JSON.stringify({ error: "referralId is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const { createClient } = await import("npm:@supabase/supabase-js@2.57.4");
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get referral details
    const { data: referral, error: referralError } = await supabase
      .from("referrals")
      .select(`
        *,
        referrer:profiles!referrals_referrer_id_fkey(user_id, stripe_connect_account_id, user_type)
      `)
      .eq("id", referralId)
      .single();

    if (referralError || !referral) {
      console.error("Error fetching referral:", referralError);
      return new Response(
        JSON.stringify({ error: "Referral not found" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Check if referral is completed
    if (referral.status !== "completed") {
      return new Response(
        JSON.stringify({ error: "Referral not completed yet" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Check if payout already processed
    if (referral.stripe_transfer_id) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "Payout already processed",
          transferId: referral.stripe_transfer_id
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const referrer = referral.referrer;

    // Only process if referrer has a Stripe Connect account
    if (!referrer?.stripe_connect_account_id) {
      console.log("Referrer doesn't have Stripe Connect account. Reward stored in database only.");
      return new Response(
        JSON.stringify({
          success: true,
          message: "Reward stored in database (no Stripe Connect account)"
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Create a transfer to the referrer's Stripe Connect account
    const transferAmount = 1000; // €10 in cents

    try {
      const transfer = await stripe.transfers.create({
        amount: transferAmount,
        currency: "eur",
        destination: referrer.stripe_connect_account_id,
        description: `Referral bonus for referring user (Referral ID: ${referralId})`,
        metadata: {
          referral_id: referralId,
          referrer_id: referrer.user_id,
          type: "referral_bonus",
        },
      });

      // Update referral record with Stripe transfer ID
      const { error: updateError } = await supabase
        .from("referrals")
        .update({
          stripe_transfer_id: transfer.id,
          stripe_payout_completed: true,
        })
        .eq("id", referralId);

      if (updateError) {
        console.error("Error updating referral with transfer ID:", updateError);
      }

      // Create a notification for the referrer
      await supabase.from("notifications").insert({
        user_id: referrer.user_id,
        type: "payment",
        title: "Referral Bonus Received!",
        message: "You've received €10 for referring a friend. The bonus has been added to your earnings.",
        metadata: {
          referral_id: referralId,
          transfer_id: transfer.id,
          amount: 10,
        },
      });

      return new Response(
        JSON.stringify({
          success: true,
          transferId: transfer.id,
          amount: transferAmount / 100,
          currency: "EUR",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    } catch (stripeError: any) {
      console.error("Stripe transfer error:", stripeError);
      return new Response(
        JSON.stringify({
          error: "Failed to process Stripe transfer",
          details: stripeError.message,
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }
  } catch (error: any) {
    console.error("Error processing referral payout:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
