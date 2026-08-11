import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type LabelRequest = {
  order_id: string;
  sendcloud_shipping_method_id: number;
  buyer_name: string;
  buyer_address: string;
  buyer_city: string;
  buyer_postcode: string;
  buyer_country: string;
  buyer_email: string;
  product_name: string;
  weight_kg: number;
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  try {
    const publicKey = Deno.env.get("SENDCLOUD_PUBLIC_KEY");
    const secretKey = Deno.env.get("SENDCLOUD_SECRET_KEY");
    if (!publicKey || !secretKey) return response({ error: "Shipping service is not configured" }, 503);

    const input = await req.json() as LabelRequest;
    if (!input.order_id || !Number.isInteger(input.sendcloud_shipping_method_id) || !input.buyer_name || !input.buyer_address || !input.buyer_city || !input.buyer_postcode || !input.buyer_country || !input.buyer_email || !input.product_name || !Number.isFinite(input.weight_kg) || input.weight_kg <= 0) {
      return response({ error: "Complete order, address, shipping method, and package details are required" }, 400);
    }

    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: order, error: orderError } = await supabase.from("orders").select("id, client_id, shipping_label_url").eq("id", input.order_id).maybeSingle();
    if (orderError) throw orderError;
    if (!order) return response({ error: "Order not found" }, 404);
    if (order.shipping_label_url) return response({ error: "A shipping label already exists for this order" }, 409);

    const credentials = btoa(`${publicKey}:${secretKey}`);
    const sendcloudResponse = await fetch("https://panel.sendcloud.sc/api/v2/parcels", {
      method: "POST",
      headers: { Authorization: `Basic ${credentials}`, "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify({
        parcel: {
          name: input.buyer_name,
          address: input.buyer_address,
          city: input.buyer_city,
          postal_code: input.buyer_postcode,
          country: input.buyer_country.toUpperCase(),
          email: input.buyer_email,
          shipment: { id: input.sendcloud_shipping_method_id },
          weight: input.weight_kg.toFixed(2),
          request_label: true,
          order_number: input.order_id,
          description: input.product_name,
        },
      }),
    });

    if (!sendcloudResponse.ok) return response({ error: "Unable to create shipping label" }, 502);
    const payload = await sendcloudResponse.json() as { parcel?: Record<string, unknown> };
    const parcel = payload.parcel ?? payload as Record<string, unknown>;
    const labelUrl = String(parcel.label?.toString?.() ?? parcel.label_url ?? parcel.label?.label_printer ?? "");
    const trackingNumber = String(parcel.tracking_number ?? "");
    const parcelId = String(parcel.id ?? "");
    if (!labelUrl || !trackingNumber || !parcelId) return response({ error: "Sendcloud returned an incomplete label" }, 502);

    const { error: updateError } = await supabase.from("orders").update({
      shipping_label_url: labelUrl,
      tracking_number: trackingNumber,
      sendcloud_parcel_id: parcelId,
      label_purchased_at: new Date().toISOString(),
      tracking_status: "label_created",
      status: "label_created",
    }).eq("id", input.order_id);
    if (updateError) throw updateError;

    return response({ label_url: labelUrl, tracking_number: trackingNumber, sendcloud_parcel_id: parcelId });
  } catch (error) {
    console.error("create-shipment-label error", error);
    return response({ error: "Unable to create shipping label" }, 500);
  }
});
