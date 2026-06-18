import "jsr:@supabase/functions-js/edge-runtime.d.ts";

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
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const { createClient } = await import("npm:@supabase/supabase-js@2");
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: pickers, error: pickersError } = await supabase
      .from("profiles")
      .select("id")
      .eq("user_type", "picker");

    if (pickersError) throw pickersError;

    let successCount = 0;
    let errorCount = 0;

    for (const picker of pickers || []) {
      try {
        const { error } = await supabase.rpc("generate_revenue_insights", {
          p_picker_id: picker.id,
        });

        if (error) {
          console.error(`Error generating insights for picker ${picker.id}:`, error);
          errorCount++;
        } else {
          successCount++;
        }
      } catch (err) {
        console.error(`Failed for picker ${picker.id}:`, err);
        errorCount++;
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Generated insights for ${successCount} pickers`,
        successCount,
        errorCount,
        totalPickers: pickers?.length || 0,
      }),
      {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error: any) {
    console.error("Error in generate-insights:", error);
    return new Response(
      JSON.stringify({
        error: error.message || "Failed to generate insights",
      }),
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