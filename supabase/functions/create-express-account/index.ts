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
    const body = await req.json();
    console.log("Request body:", body);

    const { picker_id, picker_email, return_url, refresh_url, country } = body;

    console.log("Creating Express account for picker:", picker_id);
    console.log("Return URL:", return_url);
    console.log("Refresh URL:", refresh_url);

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Check if picker already has a Stripe account
    const { data: existing } = await supabase
      .from("picker_payout_info")
      .select("stripe_account_id")
      .eq("picker_id", picker_id)
      .maybeSingle();

    let stripeAccountId = existing?.stripe_account_id;

    if (!stripeAccountId) {
      // Create new Express account for individual person
      const createParams: any = {
        type: "express",
        email: picker_email,
        business_type: "individual", // Individual person, not business
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        settings: {
          payouts: {
            schedule: { interval: "manual" },
          },
        },
      };

      // Only set country if explicitly passed — otherwise let Stripe show the picker
      if (country) {
        createParams.country = country;
      }

      const account = await stripe.accounts.create(createParams);
      stripeAccountId = account.id;

      // Save to picker_payout_info (use upsert with onConflict to handle existing records)
      const { error: insertError } = await supabase
        .from("picker_payout_info")
        .upsert({
          picker_id,
          stripe_account_id: stripeAccountId,
          is_verified: false,
          details_submitted: false,
        }, {
          onConflict: 'picker_id'
        });

      if (insertError) {
        console.error("Error saving payout info:", insertError);
        throw new Error(`Failed to save payout info: ${insertError.message}`);
      }

      // Also save to profiles table
      const { error: profileError } = await supabase
        .from("profiles")
        .update({ stripe_account_id: stripeAccountId })
        .eq("id", picker_id);

      if (profileError) {
        console.error("Error updating profile:", profileError);
      }
    }

    // Validate required URLs
    if (!return_url || !refresh_url) {
      throw new Error("return_url and refresh_url are required");
    }

    // Generate onboarding link
    const accountLink = await stripe.accountLinks.create({
      account: stripeAccountId,
      refresh_url: refresh_url,
      return_url: return_url,
      type: "account_onboarding",
    });

    return new Response(
      JSON.stringify({ url: accountLink.url, stripe_account_id: stripeAccountId }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error("Error creating Express account:", error);
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
