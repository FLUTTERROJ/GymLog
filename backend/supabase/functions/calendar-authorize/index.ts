import { createClient } from "npm:@supabase/supabase-js@2";

// Inlined from ../_shared/cors.ts -- kept self-contained since this
// function is deployed via dashboard paste, which doesn't resolve
// relative imports across files the way the CLI does.
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

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
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }
  const headers = { ...corsHeaders, "Content-Type": "application/json" };
  const auth = req.headers.get("Authorization");
  if (!auth) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers,
    });
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!);
  // getUser() with no argument reads from a session established on this
  // client (via a prior sign-in call) -- this client has never signed in,
  // it only received the caller's token in a header, so the token has to
  // be passed explicitly or there's nothing for it to check.
  const jwt = auth.replace(/^Bearer\s+/i, "");
  const { data: { user }, error } = await caller.auth.getUser(jwt);
  if (error || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers,
    });
  }

  const body = await req.json();
  const redirectTo = body.redirect_to as string;
  if (
    !redirectTo ||
    !/^https?:\/\/|^io\.supabase\.syncfit:\/\//.test(redirectTo)
  ) {
    return new Response(JSON.stringify({ error: "Invalid redirect URL" }), {
      status: 400,
      headers,
    });
  }

  const state = randomState();
  const service = createClient(
    url,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  await service.from("calendar_oauth_states").insert({
    state,
    trainer_id: user.id,
    redirect_to: redirectTo,
    expires_at: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
  });

  // Google redirects the user's browser straight to this URL -- a plain
  // navigation, not a request our code makes, so it can never carry a
  // custom Authorization/apikey header. This project's Edge Functions
  // gateway requires an apikey on every request regardless (there's no
  // per-function exemption for it, unlike JWT verification), so the only
  // way to satisfy that here is to put it in the URL itself as a query
  // parameter, which Supabase's gateway also accepts.
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const callback = `${url}/functions/v1/calendar-oauth-callback?apikey=${
    encodeURIComponent(anonKey)
  }`;
  const google = new URL("https://accounts.google.com/o/oauth2/v2/auth");
  google.searchParams.set("client_id", Deno.env.get("GOOGLE_CLIENT_ID")!);
  google.searchParams.set("redirect_uri", callback);
  google.searchParams.set("response_type", "code");
  google.searchParams.set("scope", scopes);
  google.searchParams.set("access_type", "offline");
  // "select_account" forces the account chooser to show every time, rather
  // than Google silently using whichever account happens to already be
  // signed into that browser -- which has nothing to do with which account
  // was used to sign into the app itself.
  google.searchParams.set("prompt", "consent select_account");
  google.searchParams.set("state", state);

  return new Response(JSON.stringify({ url: google.toString() }), {
    headers,
  });
});
