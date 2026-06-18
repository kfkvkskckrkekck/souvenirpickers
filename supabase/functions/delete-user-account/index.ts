import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    });

    // Get the authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    // Verify the user's token and get their ID
    const token = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const userId = user.id;

    // Delete the user's profile which will CASCADE to all related tables
    // Thanks to the CASCADE constraints, this will automatically clean up:
    // - picker_profiles, picker_payout_info, listings, orders
    // - conversations, messages, notifications, reviews
    // - referrals, payment methods, subscriptions, etc.

    await supabase.from('profiles').delete().eq('id', userId);

    // Finally delete the auth user
    const { error: deleteError } = await supabase.auth.admin.deleteUser(userId);

    if (deleteError) {
      console.error('Error deleting auth user:', deleteError);
      throw new Error(`Failed to delete user account: ${deleteError.message}`);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Account deleted successfully'
      }),
      {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      }
    );
  } catch (error) {
    console.error('Error deleting account:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to delete account',
        details: error instanceof Error ? error.stack : undefined
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
