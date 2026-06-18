import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Client-Info, Apikey',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log('Processing pending reminders...');

    // Process delivery confirmation reminders
    const { data: deliveryResult, error: deliveryError } = await supabase
      .rpc('process_pending_reminders');

    if (deliveryError) {
      console.error('Error processing delivery reminders:', deliveryError);
      throw deliveryError;
    }

    console.log('Delivery reminders processed:', deliveryResult);

    // Process trial ending reminders
    const { data: trialResult, error: trialError } = await supabase
      .rpc('process_trial_reminders');

    if (trialError) {
      console.error('Error processing trial reminders:', trialError);
      throw trialError;
    }

    console.log('Trial reminders processed:', trialResult);

    // Check for new trial endings
    const { data: checkResult, error: checkError } = await supabase
      .rpc('check_trial_endings');

    if (checkError) {
      console.error('Error checking trial endings:', checkError);
      throw checkError;
    }

    console.log('Trial endings checked:', checkResult);

    return new Response(
      JSON.stringify({
        success: true,
        delivery_reminders: deliveryResult,
        trial_reminders: trialResult,
        trial_check: checkResult,
        timestamp: new Date().toISOString(),
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error in process-reminders:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});