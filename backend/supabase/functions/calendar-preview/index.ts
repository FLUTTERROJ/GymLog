// Called by the Flutter app with the trainer's own session. Fetches
// tomorrow's calendar events, parses each title, and reports which detected
// names are already mapped to a trainee -- backs the mapping screen with
// live data instead of a stale cache. Never sends anything.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  fetchEventsInRange,
  parseSessionTitle,
  refreshGoogleAccessToken,
  tomorrowRangeUtc,
} from "../_shared/calendar.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;

  // Scoped to the caller's own JWT, used only to verify who's asking.
  const callerClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await callerClient.auth
    .getUser();
  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  // google_calendar_connections has no client-readable SELECT policy at all
  // (see the migration) -- reading the refresh token requires the
  // service-role key regardless of who's calling.
  const serviceClient = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: connection } = await serviceClient
    .from("google_calendar_connections")
    .select("refresh_token")
    .eq("trainer_id", user.id)
    .maybeSingle();

  if (!connection) {
    return new Response(
      JSON.stringify({ connected: false, sessions: [], names: [] }),
      { headers: jsonHeaders },
    );
  }

  try {
    const accessToken = await refreshGoogleAccessToken(
      connection.refresh_token,
      Deno.env.get("GOOGLE_CLIENT_ID")!,
      Deno.env.get("GOOGLE_CLIENT_SECRET")!,
    );

    const { timeMin, timeMax } = tomorrowRangeUtc();
    const events = await fetchEventsInRange(accessToken, timeMin, timeMax);

    const parsed = events
      .map((event) => ({ event, session: parseSessionTitle(event.summary) }))
      .filter((e): e is { event: typeof e.event; session: NonNullable<typeof e.session> } =>
        e.session !== null
      );

    const distinctNames = Array.from(
      new Set(parsed.flatMap((e) => e.session.names)),
    );

    const { data: mappings } = await serviceClient
      .from("calendar_name_mappings")
      .select(
        "calendar_name_normalized, trainee_id, trainee:profiles!calendar_name_mappings_trainee_id_fkey(username, full_name)",
      )
      .eq("trainer_id", user.id);

    const mappingByNormalized = new Map(
      (mappings ?? []).map((m: any) => [m.calendar_name_normalized, m]),
    );

    const names = distinctNames.map((name) => {
      const mapping = mappingByNormalized.get(name.toLowerCase());
      const trainee = mapping?.trainee as
        | { username: string | null; full_name: string | null }
        | undefined;
      return {
        name,
        mapped: !!mapping,
        traineeId: mapping?.trainee_id ?? null,
        traineeLabel: trainee?.username ?? trainee?.full_name ?? null,
      };
    });

    const sessions = parsed.map(({ event, session }) => ({
      eventId: event.id,
      title: event.summary,
      start: event.start,
      names: session.names,
      paidStatus: session.paidStatus,
      location: session.location,
    }));

    return new Response(
      JSON.stringify({ connected: true, sessions, names }),
      { headers: jsonHeaders },
    );
  } catch (error) {
    console.error("calendar-preview failed:", error);
    return new Response(
      JSON.stringify({
        error: "Could not read your calendar. Try reconnecting it.",
      }),
      { status: 502, headers: jsonHeaders },
    );
  }
});
