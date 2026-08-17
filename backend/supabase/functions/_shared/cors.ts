// The Flutter web build calls Edge Functions directly from the browser
// (supabase_flutter's functions.invoke hits the HTTPS endpoint straight from
// the page on web), so preflight OPTIONS requests need a CORS response.
// Mobile builds ignore this entirely -- no browser involved.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};
