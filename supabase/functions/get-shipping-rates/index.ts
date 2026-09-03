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
      return response({ error: "Could not load product details" }, 500);
    }
    if (!listing) return response({ error: "Product not found" }, 404);

    const weight = Number(listing.weight_kg) > 0 ? Number(listing.weight_kg) : 1;

    const { data: picker, error: pickerError } = await supabase
      .from("picker_profiles")
      .select("user_id")
      .eq("id", listing.picker_id)
      .maybeSingle();
    if (pickerError) {
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
      return response({ error: "Could not load seller shipping address" }, 500);
    }
    if (!address) return response({ error: "Seller shipping address is missing. The seller needs to add their shipping address before orders can be placed." }, 422);

    const credentials = btoa(`${publicKey}:${secretKey}`);
    const authHeader = { Authorization: `Basic ${credentials}`, Accept: "application/json" };
    const fromCountry = String(address.country_code);
    const toCountry = country;
    const fromPostalCode = String(address.postcode);
    const toPostalCode = input.buyer_postcode.trim();
    const weightGrams = Math.max(1, Math.round(weight * 1000));

    // Step 1: Get available shipping products for this route
    const productsParams = new URLSearchParams({
      from_postal_code: fromPostalCode,
      from_country: fromCountry,
      to_postal_code: toPostalCode,
      to_country: toCountry,
      weight: String(weightGrams),
      weight_unit: "gram",
    });

    let productsResponse: Response;
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 15000);
      productsResponse = await fetch(`https://panel.sendcloud.sc/api/v2/shipping-products?${productsParams}`, {
        headers: authHeader,
        signal: controller.signal,
      });
      clearTimeout(timeout);
    } catch (fetchError) {
      const msg = fetchError instanceof DOMException && fetchError.name === "AbortError"
        ? "Shipping rates request timed out. Please try again."
        : "Could not reach the shipping service. Please try again.";
      return response({ error: msg }, 502);
    }

    if (!productsResponse.ok) {
      return response({ error: "Shipping rates are currently unavailable. Please try again or contact support." }, 502);
    }

    let productsData: unknown;
    try {
      productsData = await productsResponse.json();
    } catch {
      return response({ error: "Shipping service returned an invalid response. Please try again." }, 502);
    }

    // shipping-products returns a flat array of product objects, each with a "methods" array
    const products = Array.isArray(productsData) ? productsData : [];
    if (products.length === 0) {
      return response({ error: "No shipping options are available for this destination. Please contact the seller." }, 404);
    }

    // Collect all methods with their product info
    type MethodInfo = {
      method_id: number;
      method_name: string;
      product_name: string;
      carrier: string;
    };
    const allMethods: MethodInfo[] = [];
    for (const product of products) {
      const p = product as Record<string, unknown>;
      const productName = String(p.name ?? "Shipping service");
      const carrier = String(p.carrier ?? "Sendcloud");
      const methods = Array.isArray(p.methods) ? p.methods : [];
      for (const method of methods) {
        const m = method as Record<string, unknown>;
        const methodId = Number(m.id);
        if (Number.isFinite(methodId) && methodId > 0) {
          allMethods.push({
            method_id: methodId,
            method_name: String(m.name ?? productName),
            product_name: productName,
            carrier,
          });
        }
      }
    }

    if (allMethods.length === 0) {
      return response({ error: "No shipping options are available for this destination. Please contact the seller." }, 404);
    }

    // Step 2: Get prices for each method (limited to first 10 to avoid too many calls)
    const methodsToPrice = allMethods.slice(0, 10);
    const pricePromises = methodsToPrice.map(async (method) => {
      const priceParams = new URLSearchParams({
        shipping_method_id: String(method.method_id),
        from_country: fromCountry,
        to_country: toCountry,
        weight: String(weightGrams),
        weight_unit: "gram",
      });
      try {
        const priceResp = await fetch(`https://panel.sendcloud.sc/api/v2/shipping-price?${priceParams}`, {
          headers: authHeader,
        });
        if (!priceResp.ok) return null;
        const priceData = await priceResp.json() as Record<string, unknown>;
        const price = Number(priceData.price ?? priceData.shipping_price ?? 0);
        const minDays = Number(priceData.min_days ?? priceData.min_delivery_days ?? 0);
        const maxDays = Number(priceData.max_days ?? priceData.max_delivery_days ?? 0);
        return {
          id: method.method_id,
          name: method.method_name,
          carrier: method.carrier,
          min_days: minDays,
          max_days: maxDays,
          price,
        };
      } catch {
        return null;
      }
    });

    const priceResults = await Promise.all(pricePromises);
    const rates = priceResults
      .filter((r): r is NonNullable<typeof r> => r !== null)
      .filter((r) => Number.isFinite(r.price));

    if (rates.length === 0) {
      return response({ error: "No shipping options are available for this destination. Please contact the seller." }, 404);
    }
    return response({ rates });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return response({ error: `Shipping calculation failed: ${msg}` }, 500);
  }
});
