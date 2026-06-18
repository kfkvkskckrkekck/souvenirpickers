import { createClient } from 'npm:@supabase/supabase-js@2';

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
    const { email, redirectTo } = await req.json();

    if (!email) {
      throw new Error('Email is required');
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { data, error } = await supabase.auth.admin.generateLink({
      type: 'recovery',
      email: email,
      options: {
        redirectTo: redirectTo || 'https://souvenirpickers.com',
      },
    });

    if (error) {
      console.error('Error generating link:', error);
      throw error;
    }

    const resetLink = data.properties?.action_link;
    
    if (!resetLink) {
      throw new Error('Failed to generate reset link');
    }

    console.log('Recovery link generated successfully for:', email);

    return new Response(
      JSON.stringify({
        success: true,
        resetLink: resetLink,
        message: 'Recovery link generated successfully. This link is valid for 1 hour.',
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );

  } catch (err: any) {
    console.error('Recovery link generation error:', err);
    return new Response(
      JSON.stringify({
        error: err.message || 'Failed to generate recovery link',
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  }
});