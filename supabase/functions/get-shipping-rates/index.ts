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

    let input: ShippingRequest;
    try {
      input = await req.json() as ShippingRequest;
    } catch {
      return response({ error: "Invalid request body" }, 400);
    }

    const country = input.buyer_country?.trim().toUpperCase();
    if (!input.product_id || !input.buyer_postcode || !input.buyer_city || !/^[A-Z]{2}$/.test(country)) {
      return response({ error: "Product and complete buyer address are required" }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseKey) {
      return response({ error: "Database connection is not configured" }, 503);
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    const { data: listing, error: listingError } = await supabase
      .from("listings")
      .select("id, picker_id, weight_kg, length_cm, width_cm, height_cm")
      .eq("id", input.product_id)
      .maybeSingle();
    if (listingError) {
      console.error("Listing query error:", JSON.stringify(listingError));
      return response({ error: `Listing query failed: ${listingError.message || JSON.stringify(listingError)}` }, 500);
    }
    if (!listing) return response({ error: "Product not found" }, 404);

    const weight = Number(listing.weight_kg) > 0 ? Number(listing.weight_kg) : 1;
    const length = Number(listing.length_cm) > 0 ? Number(listing.length_cm) : 20;
    const width = Number(listing.width_cm) > 0 ? Number(listing.width_cm) : 15;
    const height = Number(listing.height_cm) > 0 ? Number(listing.height_cm) : 10;

    const { data: picker, error: pickerError } = await supabase
      .from("picker_profiles")
      .select("user_id")
      .eq("id", listing.picker_id)
      .maybeSingle();
    if (pickerError) {
      console.error("Picker query error:", pickerError);
      return response({ error: "Could not load seller details" }, 500);
    }
    if (!picker) return response({ error: "Seller not found" }, 404);

    const { data: address, error: addressError } = await supabase
      .from("seller_addresses")
      .select("postcode, country_code")
      .eq("seller_id", picker.user_id)
      .eq("is_default", true)
      .maybeSingle();
    if (addressError) {
      console.error("Address query error:", addressError);
      return response({ error: "Could not load seller shipping address" }, 500);
    }
    if (!address) return response({ error: "Seller shipping address is missing. The seller needs to add their shipping address before orders can be placed." }, 422);

    const credentials = btoa(`${publicKey}:${secretKey}`);
    const weightGrams = Math.max(1, Math.round(weight * 1000));
    const params = new URLSearchParams({
      from_postal_code: String(address.postcode),
      from_country: String(address.country_code),
      to_postal_code: input.buyer_postcode.trim(),
      to_country: country,
      weight: String(weightGrams),
      weight_unit: "gram",
    });

    console.log("Fetching SendCloud rates:", { from: address.postcode, from_country: address.country_code, to: input.buyer_postcode, to_country: country, weight: weightGrams });

    let sendcloudResponse: Response;
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 15000);
      sendcloudResponse = await fetch(`https://panel.sendcloud.sc/api/v2/shipping-products?${params}`, {
        headers: { Authorization: `Basic ${credentials}`, Accept: "application/json" },
        signal: controller.signal,
      });
      clearTimeout(timeout);
    } catch (fetchError) {
      const msg = fetchError instanceof DOMException && fetchError.name === "AbortError"
        ? "Shipping rates request timed out. Please try again."
        : "Could not reach the shipping service. Please try again.";
      console.error("SendCloud fetch failed:", fetchError);
      return response({ error: msg }, 502);
    }

    if (!sendcloudResponse.ok) {
      const body = await sendcloudResponse.text().catch(() => "");
      console.error("SendCloud error:", sendcloudResponse.status, body);
      return response({ error: `Shipping rates are unavailable (status ${sendcloudResponse.status}). ${body}` }, 502);
    }

    let payload: Record<string, unknown>;
    try {
      payload = await sendcloudResponse.json();
    } catch {
      console.error("SendCloud returned non-JSON response");
      return response({ error: "Shipping service returned an invalid response. Please try again." }, 502);
    }

    console.log("SendCloud response keys:", Object.keys(payload));
    console.log("SendCloud response sample:", JSON.stringify(payload).slice(0, 2000));

    const products = Array.isArray(payload.products) ? payload.products
      : Array.isArray(payload.shipping_products) ? payload.shipping_products
      : Array.isArray(payload.shipping_methods) ? payload.shipping_methods
      : Array.isArray(payload.results) ? payload.results
      : [];

    const rates = products.map((product) => {
      const p = product as Record<string, unknown>;
      return {
        id: Number(p.id ?? p.shipping_method_id ?? p.method_id ?? 0),
        name: String(p.name ?? p.service_point_name ?? p.product_name ?? "Shipping service"),
        carrier: String(p.carrier ?? p.carrier_name ?? "Sendcloud"),
        min_days: Number(p.min_days ?? p.min_delivery_days ?? p.min_business_days ?? 0),
        max_days: Number(p.max_days ?? p.max_delivery_days ?? p.max_business_days ?? 0),
        price: Number(p.price ?? p.shipping_price ?? p.cost ?? 0),
      };
    }).filter((rate) => Number.isFinite(rate.id) && Number.isFinite(rate.price));

    if (rates.length === 0) {
      return response({ error: `No shipping options are available for this destination. Response: ${JSON.stringify(payload).slice(0, 500)}` }, 404);
    }
    return response({ rates });
  } catch (error) {
    console.error("get-shipping-rates unexpected error:", error);
    const msg = error instanceof Error ? error.message : String(error);
    return response({ error: `Shipping calculation failed: ${msg}` }, 500);
  }
});
