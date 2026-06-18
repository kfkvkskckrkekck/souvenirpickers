import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // List all env vars starting with SUPABASE to find the right JWT
    const envInfo: Record<string, string> = {};
    const keysToCheck = [
      "SUPABASE_SERVICE_ROLE_KEY",
      "SUPABASE_ANON_KEY",
      "SUPABASE_URL",
      "SUPABASE_JWKS",
    ];
    for (const k of keysToCheck) {
      const v = Deno.env.get(k);
      if (v) {
        envInfo[k] = v.substring(0, 30) + "..." + " (len=" + v.length + ")";
      }
    }

    // The service role key IS the JWT for calling edge functions with verify_jwt=true
    // If it starts with "eyJ" it's a JWT, if it starts with "sb_" it's an API key
    const isJwt = serviceRoleKey.startsWith("eyJ");

    // Try to find the correct auth token
    // In Supabase, the service role KEY is used as the Authorization bearer token
    // even if it's not a JWT format - Supabase gateway accepts it
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Store the service role key (whatever format it is)
    const { error } = await supabase.rpc("seed_service_role_key_in_vault", {
      p_key: serviceRoleKey,
    });

    if (error) throw error;

    return new Response(
      JSON.stringify({
        success: true,
        message: "Service role key stored",
        isJwt,
        envInfo,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error seeding vault:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
