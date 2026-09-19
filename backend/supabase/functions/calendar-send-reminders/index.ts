// Cron-triggered (see backend/README.md for the pg_cron schedule). No user
// session -- runs as the service role, loops every connected trainer, and
// emails each mapped trainee whose session is tomorrow. Guarded by a shared
// secret header since, unlike calendar-preview, this one has real side
// effects (sends email) on behalf of every trainer in the system.
//
// Idempotent by design: session_reminders has a unique (trainer_id,
// calendar_event_id, trainee_id), and a row's email_sent_at is only set
// after the Gmail API confirms the send. Running this twice in a day sends
// nothing twice.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};
const TIMEZONE = "Australia/Sydney";

type PaidStatus = "Paid" | "Unpaid";
type ParsedSession = {
  names: string[];
  paidStatus: PaidStatus;
  location: string;
};

function parseSessionTitle(rawTitle: string): ParsedSession | null {
  const parts = rawTitle.split(/\s*:\s*/).map((p) => p.trim()).filter(Boolean);
  if (parts.length < 2) return null;
  const location = parts[parts.length - 1];
  const paidRaw = parts[parts.length - 2].toLowerCase();
  if (paidRaw !== "paid" && paidRaw !== "unpaid") return null;
  const names = parts
    .slice(0, -2)
    .flatMap((part) => part.split("/"))
    .map((name) => name.trim())
    .filter(Boolean);
  return names.length === 0
    ? null
    : { names, paidStatus: paidRaw === "paid" ? "Paid" : "Unpaid", location };
}

function tomorrowRangeUtc(now = new Date()) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const get = (type: string) => parts.find((p) => p.type === type)!.value;
  const todayUtc = Date.UTC(
    Number(get("year")),
    Number(get("month")) - 1,
    Number(get("day")),
  );
  const offsetParts = new Intl.DateTimeFormat("en-US", {
    timeZone: TIMEZONE,
    timeZoneName: "longOffset",
  }).formatToParts(now);
  const offset = offsetParts.find((part) => part.type === "timeZoneName")?.value;
  const offsetMatch = offset?.match(/GMT([+-])(\d{2})(?::(\d{2}))?/);
  const offsetMs = offsetMatch
    ? (Number(offsetMatch[2]) * 60 + Number(offsetMatch[3] ?? 0)) *
      60 *
      1000 *
      (offsetMatch[1] === "+" ? 1 : -1)
    : 10 * 60 * 60 * 1000;
  const tomorrow = todayUtc + 24 * 60 * 60 * 1000 - offsetMs;
  return {
    timeMin: new Date(tomorrow).toISOString(),
    timeMax: new Date(tomorrow + 24 * 60 * 60 * 1000).toISOString(),
  };
}

function isSydneyEightPm(now = new Date()): boolean {
  const parts = new Intl.DateTimeFormat("en-AU", {
    timeZone: TIMEZONE,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(now);
  const hour = parts.find((part) => part.type === "hour")?.value;
  const minute = parts.find((part) => part.type === "minute")?.value;
  return hour === "20" && minute === "00";
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
      `Google token refresh failed (${response.status}): ${await response.text()}`,
    );
  }
  return (await response.json()).access_token as string;
}

async function fetchEventsInRange(
  accessToken: string,
  timeMin: string,
  timeMax: string,
) {
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
      `Google Calendar fetch failed (${response.status}): ${await response.text()}`,
    );
  }
  const data = await response.json();
  return ((data.items ?? []) as Array<Record<string, any>>)
    .filter((item) => item.status !== "cancelled" && item.summary)
    .map((item) => ({
      id: item.id as string,
      summary: item.summary as string,
      start: (item.start?.dateTime ?? item.start?.date) as string,
    }));
}

async function sendReminderEmail(
  input: {
    to: string;
    traineeName: string;
    sessionStart: string;
    location: string;
    paidStatus: PaidStatus;
    subjectTemplate?: string;
    bodyTemplate?: string;
  },
  accessToken: string,
) {
  const sessionTime = new Date(input.sessionStart).toLocaleString("en-IN", {
    timeZone: TIMEZONE,
    weekday: "long",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });
  const values: Record<string, string> = {
    traineeName: input.traineeName,
    sessionTime,
    location: input.location,
    paidStatus: input.paidStatus,
  };
  const replace = (value: string) =>
    value.replace(
      /\{(traineeName|sessionTime|location|paidStatus)\}/g,
      (_, key: string) => escapeHtml(values[key]),
    );
  const html = input.bodyTemplate
    ? replace(input.bodyTemplate).replace(/\n/g, "<br>")
    : `<p>Hi ${escapeHtml(input.traineeName)},</p><p>Reminder: you have a training session tomorrow, ${escapeHtml(sessionTime)}, at ${escapeHtml(input.location)}.</p>${input.paidStatus === "Unpaid" ? "<p>Payment for this session is still pending.</p>" : ""}<p>See you there!</p>`;
  const subject = input.subjectTemplate
    ? replace(input.subjectTemplate)
    : `Reminder: your session tomorrow at ${sessionTime}`;
  const message = [
    `To: ${input.to}`,
    `Subject: =?UTF-8?B?${toBase64(subject)}?=`,
    "MIME-Version: 1.0",
    "Content-Type: text/html; charset=UTF-8",
    "",
    html,
  ].join("\r\n");
  const response = await fetch(
    "https://gmail.googleapis.com/gmail/v1/users/me/messages/send",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ raw: toBase64Url(message) }),
    },
  );
  if (!response.ok) {
    throw new Error(`Gmail send failed (${response.status}): ${await response.text()}`);
  }
}

function toBase64(value: string) {
  return btoa(String.fromCharCode(...new TextEncoder().encode(value)));
}

function toBase64Url(value: string) {
  return toBase64(value).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  if (!isSydneyEightPm()) {
    return new Response(
      JSON.stringify({ skipped: true, reason: "Not 8:00 PM Australia/Sydney" }),
      { headers: jsonHeaders },
    );
  }

  const cronSecret = Deno.env.get("CRON_SECRET")!;
  if (req.headers.get("X-Cron-Secret") !== cronSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const googleClientId = Deno.env.get("GOOGLE_CLIENT_ID")!;
  const googleClientSecret = Deno.env.get("GOOGLE_CLIENT_SECRET")!;

  const { data: connections, error: connectionsError } = await supabase
    .from("google_calendar_connections")
    .select("trainer_id, refresh_token");

  if (connectionsError) {
    console.error("Could not load calendar connections:", connectionsError);
    return new Response(
      JSON.stringify({ error: "Could not load calendar connections" }),
      { status: 500, headers: jsonHeaders },
    );
  }

  const { timeMin, timeMax } = tomorrowRangeUtc();
  const summary: Array<Record<string, unknown>> = [];

  for (const connection of connections ?? []) {
    const trainerId = connection.trainer_id as string;
    try {
      const result = await processTrainer({
        supabase,
        trainerId,
        refreshToken: connection.refresh_token as string,
        googleClientId,
        googleClientSecret,
        timeMin,
        timeMax,
      });
      summary.push({ trainerId, ...result });
    } catch (error) {
      // One trainer's revoked token or a transient Google error shouldn't
      // stop everyone else's reminders from going out.
      console.error(`Reminder run failed for trainer ${trainerId}:`, error);
      summary.push({ trainerId, error: String(error) });
    }
  }

  return new Response(JSON.stringify({ ranAt: new Date().toISOString(), summary }), {
    headers: jsonHeaders,
  });
});

async function processTrainer(args: {
  supabase: ReturnType<typeof createClient>;
  trainerId: string;
  refreshToken: string;
  googleClientId: string;
  googleClientSecret: string;
  timeMin: string;
  timeMax: string;
}) {
  const {
    supabase,
    trainerId,
    refreshToken,
    googleClientId,
    googleClientSecret,
    timeMin,
    timeMax,
  } = args;

  const accessToken = await refreshGoogleAccessToken(
    refreshToken,
    googleClientId,
    googleClientSecret,
  );
  const events = await fetchEventsInRange(accessToken, timeMin, timeMax);

  const parsedEvents = events
    .map((event) => ({ event, session: parseSessionTitle(event.summary) }))
    .filter((e): e is { event: typeof e.event; session: NonNullable<typeof e.session> } =>
      e.session !== null
    );

  if (parsedEvents.length === 0) {
    return { eventsChecked: 0, emailsSent: 0 };
  }

  // Every distinct name across tomorrow's events -> resolve once, not per event.
  const distinctNames = Array.from(
    new Set(parsedEvents.flatMap((e) => e.session.names.map((n) => n.toLowerCase()))),
  );

  const { data: mappings } = await supabase
    .from("calendar_name_mappings")
    .select("calendar_name_normalized, trainee_id")
    .eq("trainer_id", trainerId)
    .in("calendar_name_normalized", distinctNames);

  const traineeIdByName = new Map(
    (mappings ?? []).map((m: any) => [m.calendar_name_normalized, m.trainee_id as string]),
  );

  const traineeIds = Array.from(new Set(traineeIdByName.values()));
  if (traineeIds.length === 0) {
    return { eventsChecked: parsedEvents.length, emailsSent: 0, unmappedOnly: true };
  }

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, email, username, full_name")
    .in("id", traineeIds);

  const profileById = new Map((profiles ?? []).map((p: any) => [p.id, p]));
  const { data: templates } = await supabase
    .from("email_templates")
    .select("location, paid_status, subject, body")
    .eq("trainer_id", trainerId);
  const templateByKey = new Map(
    (templates ?? []).map((template: any) => [
      `${template.location.trim().toLowerCase()}::${template.paid_status}`,
      template,
    ]),
  );

  const eventIds = parsedEvents.map((e) => e.event.id);
  const { data: existingReminders } = await supabase
    .from("session_reminders")
    .select("calendar_event_id, trainee_id, email_sent_at")
    .eq("trainer_id", trainerId)
    .in("calendar_event_id", eventIds);

  const alreadySent = new Set(
    (existingReminders ?? [])
      .filter((r: any) => r.email_sent_at !== null)
      .map((r: any) => `${r.calendar_event_id}::${r.trainee_id}`),
  );

  let emailsSent = 0;

  for (const { event, session } of parsedEvents) {
    for (const rawName of session.names) {
      const traineeId = traineeIdByName.get(rawName.toLowerCase());
      if (!traineeId) continue; // unmapped -- surfaced in the preview screen instead

      const dedupeKey = `${event.id}::${traineeId}`;
      if (alreadySent.has(dedupeKey)) continue;

      const profile = profileById.get(traineeId);
      if (!profile?.email) continue;

      const traineeName = profile.username ?? profile.full_name ?? "there";
      const template = templateByKey.get(
        `${session.location.trim().toLowerCase()}::${session.paidStatus}`,
      );

      try {
        await sendReminderEmail(
          {
            to: profile.email,
            traineeName,
            sessionStart: event.start,
            location: session.location,
            paidStatus: session.paidStatus,
            subjectTemplate: template?.subject,
            bodyTemplate: template?.body,
          },
          accessToken,
        );

        await supabase.from("session_reminders").upsert(
          {
            trainer_id: trainerId,
            calendar_event_id: event.id,
            trainee_id: traineeId,
            session_start: event.start,
            raw_title: event.summary,
            paid_status: session.paidStatus,
            location: session.location,
            email_sent_at: new Date().toISOString(),
          },
          { onConflict: "trainer_id,calendar_event_id,trainee_id" },
        );

        emailsSent += 1;
      } catch (error) {
        // Record the attempt without email_sent_at so it's retried next run,
        // rather than silently failing forever.
        console.error(
          `Reminder email failed for trainee ${traineeId}, event ${event.id}:`,
          error,
        );
        await supabase.from("session_reminders").upsert(
          {
            trainer_id: trainerId,
            calendar_event_id: event.id,
            trainee_id: traineeId,
            session_start: event.start,
            raw_title: event.summary,
            paid_status: session.paidStatus,
            location: session.location,
            email_sent_at: null, // explicit: this attempt failed, retry next run
          },
          { onConflict: "trainer_id,calendar_event_id,trainee_id" },
        );
      }
    }
  }

  return { eventsChecked: parsedEvents.length, emailsSent };
}
