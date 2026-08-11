import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

async function verifySignature(body: string, signature: string | null, secret: string): Promise<boolean> {
  if (!signature) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  const expected = Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
  return signature.replace(/^sha256=/, "").toLowerCase() === expected;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  try {
    const secret = Deno.env.get("SENDCLOUD_SECRET_KEY");
    if (!secret) return response({ error: "Webhook is not configured" }, 503);
    const body = await req.text();
    if (!(await verifySignature(body, req.headers.get("x-sendcloud-signature"), secret))) return response({ error: "Invalid signature" }, 401);

    const payload = JSON.parse(body) as Record<string, unknown>;
    const parcel = (payload.parcel ?? payload) as Record<string, unknown>;
    const parcelId = String(parcel.id ?? parcel.parcel_id ?? "");
    const status = String(parcel.status ?? parcel.tracking_status ?? "").toLowerCase();
    const allowedStatuses = new Set(["pending", "label_created", "picked_up", "in_transit", "out_for_delivery", "delivered", "exception", "cancelled"]);
    if (!parcelId || !allowedStatuses.has(status)) return response({ error: "Invalid parcel update" }, 400);

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { error } = await supabase.from("orders").update({ tracking_status: status }).eq("sendcloud_parcel_id", parcelId);
    if (error) throw error;
    return response({ received: true });
  } catch (error) {
    console.error("sendcloud-webhook error", error);
    return response({ error: "Unable to process webhook" }, 500);
  }
});
