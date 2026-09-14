import { createClient } from "npm:@supabase/supabase-js@2";

// Inlined because the Supabase dashboard deploys this function as a single
// pasted file and does not bundle repository-relative shared imports.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const headers = { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" };

function finish(redirectTo: string, params: Record<string, string>) {
  const target = new URL(redirectTo);
  Object.entries(params).forEach(([key, value]) => target.searchParams.set(key, value));
  return Response.redirect(target.toString(), 303);
}

Deno.serve(async (req) => {
  const requestUrl = new URL(req.url);
  const state = requestUrl.searchParams.get("state");
  const code = requestUrl.searchParams.get("code");
  if (!state) return new Response("Missing OAuth state", { status: 400, headers });

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const callbackUrl = new URL(
    `${supabaseUrl}/functions/v1/calendar-oauth-callback`,
  );
  callbackUrl.searchParams.set(
    "apikey",
    Deno.env.get("SUPABASE_ANON_KEY")!,
  );
  const service = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: oauthState } = await service
    .from("calendar_oauth_states")
    .select("state, trainer_id, redirect_to, expires_at")
    .eq("state", state)
    .maybeSingle();
  if (!oauthState || new Date(oauthState.expires_at) < new Date()) {
    return new Response("OAuth state expired", { status: 400, headers });
  }
  await service.from("calendar_oauth_states").delete().eq("state", state);

  if (!code) {
    return finish(oauthState.redirect_to, {
      calendar_error: requestUrl.searchParams.get("error") ?? "access_denied",
    });
  }

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: Deno.env.get("GOOGLE_CLIENT_ID")!,
      client_secret: Deno.env.get("GOOGLE_CLIENT_SECRET")!,
      redirect_uri: callbackUrl.toString(),
      grant_type: "authorization_code",
    }),
  });
  const tokens = await tokenResponse.json();
  if (!tokenResponse.ok || !tokens.refresh_token) {
    return finish(oauthState.redirect_to, {
      calendar_error: "refresh_token_missing",
    });
  }

  const profileResponse = await fetch(
    "https://www.googleapis.com/oauth2/v2/userinfo",
    { headers: { Authorization: `Bearer ${tokens.access_token}` } },
  );
  const profile = profileResponse.ok ? await profileResponse.json() : {};
  const { error } = await service.from("google_calendar_connections").upsert({
    trainer_id: oauthState.trainer_id,
    refresh_token: tokens.refresh_token,
    google_email: profile.email ?? null,
  });
  if (error) {
    console.error("Could not store Google calendar connection:", error);
    return finish(oauthState.redirect_to, { calendar_error: "save_failed" });
  }
  return finish(oauthState.redirect_to, { calendar_connected: "1" });
});
