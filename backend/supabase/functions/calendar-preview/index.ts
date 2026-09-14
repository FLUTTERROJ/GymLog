// Called by the Flutter app with the trainer's own session. Fetches
// tomorrow's calendar events, parses each title, and reports which detected
// names are already mapped to a trainee -- backs the mapping screen with
// live data instead of a stale cache. Never sends anything.
//
// Self-contained (no ../_shared imports): deployed via dashboard paste,
// which doesn't resolve relative imports across files the way the CLI does.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

const TIMEZONE = "Asia/Kolkata";
// Fixed +5:30 offset -- India doesn't observe DST, so this arithmetic is
// safe without pulling in a full timezone library.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

interface ParsedSession {
  names: string[];
  paidStatus: "Paid" | "Unpaid";
  location: string;
}

/**
 * "Name(s) : Paid/Unpaid : Location" -> structured session, or null if the
 * title doesn't match that shape at all (i.e. it's not a client session --
 * other calendar clutter is meant to be skipped, not guessed at).
 */
function parseSessionTitle(rawTitle: string): ParsedSession | null {
  const parts = rawTitle
    .split(/\s*:\s*/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  if (parts.length < 2) return null;

  const location = parts[parts.length - 1];
  const paidRaw = parts[parts.length - 2].toLowerCase();
  if (paidRaw !== "paid" && paidRaw !== "unpaid") return null;

  const nameParts = parts.slice(0, parts.length - 2);
  const names = nameParts
    .flatMap((part) => part.split("/"))
    .map((n) => n.trim())
    .filter((n) => n.length > 0);

  if (names.length === 0) return null;

  return {
    names,
    paidStatus: paidRaw === "paid" ? "Paid" : "Unpaid",
    location,
  };
}

/** [start, end) of "tomorrow" in Asia/Kolkata, as RFC3339 UTC timestamps. */
function tomorrowRangeUtc(now: Date = new Date()): {
  timeMin: string;
  timeMax: string;
} {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)!.value;

  const todayUtcMidnight = Date.UTC(
    Number(get("year")),
    Number(get("month")) - 1,
    Number(get("day")),
  );
  const dayMs = 24 * 60 * 60 * 1000;
  const tomorrowLocalMidnightUtc = todayUtcMidnight + dayMs - IST_OFFSET_MS;
  const dayAfterLocalMidnightUtc = tomorrowLocalMidnightUtc + dayMs;

  return {
    timeMin: new Date(tomorrowLocalMidnightUtc).toISOString(),
    timeMax: new Date(dayAfterLocalMidnightUtc).toISOString(),
  };
}

async function refreshGoogleAccessToken(
  refreshToken: string,
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });

  if (!response.ok) {
    throw new Error(
      `Google token refresh failed (${response.status}): ${await response
        .text()}`,
    );
  }

  const data = await response.json();
  return data.access_token as string;
}

interface CalendarEvent {
  id: string;
  summary: string;
  /** ISO datetime, or a bare date for all-day events. */
  start: string;
}

async function fetchEventsInRange(
  accessToken: string,
  timeMin: string,
  timeMax: string,
): Promise<CalendarEvent[]> {
  const url = new URL(
    "https://www.googleapis.com/calendar/v3/calendars/primary/events",
  );
  url.searchParams.set("timeMin", timeMin);
  url.searchParams.set("timeMax", timeMax);
  url.searchParams.set("singleEvents", "true");
  url.searchParams.set("orderBy", "startTime");
  url.searchParams.set("maxResults", "250");

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new Error(
      `Google Calendar fetch failed (${response.status}): ${await response
        .text()}`,
    );
  }

  const data = await response.json();
  const items = (data.items ?? []) as Array<Record<string, any>>;

  return items
    .filter((item) => item.status !== "cancelled" && item.summary)
    .map((item) => ({
      id: item.id as string,
      summary: item.summary as string,
      start: (item.start?.dateTime ?? item.start?.date) as string,
    }));
}

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
  );

  // getUser() with no argument reads from a session established on this
  // client (via a prior sign-in call) -- this client has never signed in,
  // it only received the caller's token in a header, so the token has to
  // be passed explicitly or there's nothing for it to check.
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  const { data: { user }, error: userError } = await callerClient.auth
    .getUser(jwt);
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
      .filter((
        e,
      ): e is { event: typeof e.event; session: NonNullable<typeof e.session> } =>
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
