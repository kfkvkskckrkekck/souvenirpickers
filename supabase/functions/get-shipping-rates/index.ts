import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

type ShippingRequest = {
  product_id: string;
  buyer_postcode: string;
  buyer_city: string;
  buyer_country: string;
};

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 200, headers: corsHeaders });
  if (req.method !== "POST") return response({ error: "Method not allowed" }, 405);

  try {
    const publicKey = Deno.env.get("SENDCLOUD_PUBLIC_KEY");
    const secretKey = Deno.env.get("SENDCLOUD_SECRET_KEY");
    if (!publicKey || !secretKey) return response({ error: "Shipping service is not configured" }, 503);

    const input = await req.json() as ShippingRequest;
    const country = input.buyer_country?.trim().toUpperCase();
    if (!input.product_id || !input.buyer_postcode || !input.buyer_city || !/^[A-Z]{2}$/.test(country)) {
      return response({ error: "Product and complete buyer address are required" }, 400);
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: listing, error: listingError } = await supabase
      .from("listings")
      .select("id, picker_id, weight_kg, length_cm, width_cm, height_cm")
      .eq("id", input.product_id)
      .maybeSingle();
    if (listingError) throw listingError;
    if (!listing) return response({ error: "Product not found" }, 404);

    const dimensions = [listing.weight_kg, listing.length_cm, listing.width_cm, listing.height_cm];
    if (dimensions.some((value) => value === null || value === undefined || Number(value) <= 0)) {
      return response({ error: "Product package dimensions are missing" }, 422);
    }

    const { data: picker, error: pickerError } = await supabase
      .from("picker_profiles")
      .select("user_id")
      .eq("id", listing.picker_id)
      .maybeSingle();
    if (pickerError) throw pickerError;
    if (!picker) return response({ error: "Seller not found" }, 404);

    const { data: address, error: addressError } = await supabase
      .from("seller_addresses")
      .select("postcode, country_code")
      .eq("seller_id", picker.user_id)
      .eq("is_default", true)
      .maybeSingle();
    if (addressError) throw addressError;
    if (!address) return response({ error: "Seller shipping address is missing" }, 422);

    const credentials = btoa(`${publicKey}:${secretKey}`);
    const params = new URLSearchParams({
      from_postal_code: address.postcode,
      from_country: address.country_code,
      to_postal_code: input.buyer_postcode.trim(),
      to_country: country,
      weight: String(Number(listing.weight_kg).toFixed(2)),
      length: String(Number(listing.length_cm).toFixed(2)),
      width: String(Number(listing.width_cm).toFixed(2)),
      height: String(Number(listing.height_cm).toFixed(2)),
    });

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    let sendcloudResponse: Response;
    try {
      sendcloudResponse = await fetch(`https://panel.sendcloud.sc/api/v2/shipping-methods?${params}`, {
        headers: { Authorization: `Basic ${credentials}`, Accept: "application/json" },
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }

    if (!sendcloudResponse.ok) return response({ error: "Shipping rates are unavailable" }, 502);
    const payload = await sendcloudResponse.json() as { shipping_methods?: Array<Record<string, unknown>> };
    const methods = Array.isArray(payload.shipping_methods) ? payload.shipping_methods : [];
    const rates = methods.map((method) => ({
      id: Number(method.id),
      name: String(method.name ?? method.service_point_name ?? "Shipping service"),
      carrier: String(method.carrier ?? method.carrier_name ?? "Sendcloud"),
      min_days: Number(method.min_days ?? method.min_delivery_days ?? 0),
      max_days: Number(method.max_days ?? method.max_delivery_days ?? 0),
      price: Number(method.price ?? method.shipping_price ?? 0),
    })).filter((rate) => Number.isFinite(rate.id) && Number.isFinite(rate.price));

    if (rates.length === 0) return response({ error: "No shipping rates found" }, 404);
    return response({ rates });
  } catch (error) {
    console.error("get-shipping-rates error", error);
    return response({ error: error instanceof DOMException && error.name === "AbortError" ? "Shipping rates request timed out" : "Unable to calculate shipping rates" }, 500);
  }
});
