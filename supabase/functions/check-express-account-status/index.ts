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
    const { picker_id } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: payoutInfo } = await supabase
      .from("picker_payout_info")
      .select("stripe_account_id, is_verified")
      .eq("picker_id", picker_id)
      .maybeSingle();

    if (!payoutInfo?.stripe_account_id) {
      return new Response(
        JSON.stringify({ status: "not_created", is_verified: false }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    // Fetch live status from Stripe
    const account = await stripe.accounts.retrieve(payoutInfo.stripe_account_id);

    // If account is US-locked and unverified, reset it so picker can start fresh
    if (
      account.country === 'US' &&
      !account.payouts_enabled &&
      !account.charges_enabled
    ) {
      console.log(`Resetting US-locked unverified account for picker ${picker_id}`);

      // Delete the locked account from Stripe
      await stripe.accounts.del(payoutInfo.stripe_account_id);

      // Remove from database so fresh account is created on next setup attempt
      await supabase
        .from("picker_payout_info")
        .update({ stripe_account_id: null, is_verified: false })
        .eq("picker_id", picker_id);

      return new Response(
        JSON.stringify({ status: 'not_created', is_verified: false }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        }
      );
    }

    const isVerified =
      account.charges_enabled &&
      account.payouts_enabled &&
      (!account.requirements?.currently_due || account.requirements.currently_due.length === 0);

    // Update DB if status changed
    if (isVerified !== payoutInfo.is_verified) {
      await supabase
        .from("picker_payout_info")
        .update({ is_verified: isVerified })
        .eq("picker_id", picker_id);
    }

    return new Response(
      JSON.stringify({
        status: isVerified ? "verified" : "pending",
        is_verified: isVerified,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        requirements: account.requirements?.currently_due || [],
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error checking Express account status:", error);
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
