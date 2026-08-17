// Cron-triggered (see backend/README.md for the pg_cron schedule). No user
// session -- runs as the service role, loops every connected trainer, and
// emails each mapped trainee whose session is tomorrow. Guarded by a shared
// secret header since, unlike calendar-preview, this one has real side
// effects (sends email) on behalf of every trainer in the system.
//
// Idempotent by design: session_reminders has a unique (trainer_id,
// calendar_event_id, trainee_id), and a row's email_sent_at is only set
// after Resend confirms the send. Running this twice in a day sends nothing
// twice.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  fetchEventsInRange,
  parseSessionTitle,
  refreshGoogleAccessToken,
  sendReminderEmail,
  tomorrowRangeUtc,
} from "../_shared/calendar.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

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
  const resendApiKey = Deno.env.get("RESEND_API_KEY")!;
  const fromAddress = Deno.env.get("REMINDER_FROM_ADDRESS")!;

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
        resendApiKey,
        fromAddress,
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
  resendApiKey: string;
  fromAddress: string;
  timeMin: string;
  timeMax: string;
}) {
  const {
    supabase,
    trainerId,
    refreshToken,
    googleClientId,
    googleClientSecret,
    resendApiKey,
    fromAddress,
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

      try {
        await sendReminderEmail(
          {
            to: profile.email,
            traineeName,
            sessionStart: event.start,
            location: session.location,
            paidStatus: session.paidStatus,
          },
          resendApiKey,
          fromAddress,
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
