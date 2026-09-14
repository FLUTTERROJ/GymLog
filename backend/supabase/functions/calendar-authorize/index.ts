import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const scopes = [
  "https://www.googleapis.com/auth/calendar.readonly",
  "https://www.googleapis.com/auth/gmail.send",
].join(" ");

function randomState(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  const headers = { ...corsHeaders, "Content-Type": "application/json" };
  const auth = req.headers.get("Authorization");
  if (!auth) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers,
    });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: auth } },
  });
  const { data: { user }, error } = await caller.auth.getUser();
  if (error || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers,
    });
  }

  const body = await req.json();
  const redirectTo = body.redirect_to as string;
  if (!redirectTo || !/^https?:\/\/|^io\.supabase\.syncfit:\/\//.test(redirectTo)) {
    return new Response(JSON.stringify({ error: "Invalid redirect URL" }), {
      status: 400,
      headers,
    });
  }

  const state = randomState();
  const service = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  await service.from("calendar_oauth_states").insert({
    state,
    trainer_id: user.id,
    redirect_to: redirectTo,
    expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
  });

  const callback = `${url}/functions/v1/calendar-oauth-callback`;
  const google = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  google.searchParams.set("client_id", Deno.env.get("GOOGLE_CLIENT_ID")!);
  google.searchParams.set("redirect_uri", callback);
  google.searchParams.set("response_type", "code");
  google.searchParams.set("scope", scopes);
  google.searchParams.set("access_type", "offline");
  google.searchParams.set("prompt", "consent");
  google.searchParams.set("state", state);

  return new Response(JSON.stringify({ url: google.toString() }), { headers });
});
