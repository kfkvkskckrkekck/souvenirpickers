const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  const smtpHost = Deno.env.get('SMTP_HOST');
  const smtpPort = Deno.env.get('SMTP_PORT');
  const smtpUser = Deno.env.get('SMTP_USER');
  const smtpPass = Deno.env.get('SMTP_PASS');
  const smtpFrom = Deno.env.get('SMTP_FROM');

  const missing = [];
  if (!smtpHost) missing.push('SMTP_HOST');
  if (!smtpPort) missing.push('SMTP_PORT');
  if (!smtpUser) missing.push('SMTP_USER');
  if (!smtpPass) missing.push('SMTP_PASS');
  if (!smtpFrom) missing.push('SMTP_FROM');

  const result = {
    timestamp: new Date().toISOString(),
    configured: missing.length === 0,
    missing: missing,
    secrets: {
      SMTP_HOST: smtpHost ? `Found: ${smtpHost}` : false,
      SMTP_PORT: smtpPort ? `Found: ${smtpPort}` : false,
      SMTP_USER: smtpUser ? `Found: ${smtpUser}` : false,
      SMTP_PASS: smtpPass ? `Found (${smtpPass.length} characters)` : false,
      SMTP_FROM: smtpFrom ? `Found: ${smtpFrom}` : false,
    },
    allEnvVars: Object.keys(Deno.env.toObject()).filter(k => k.includes('SMTP')),
  };

  return new Response(
    JSON.stringify(result, null, 2),
    {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json',
      },
    }
  );
});