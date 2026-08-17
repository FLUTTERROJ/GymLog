// Shared by calendar-preview and calendar-send-reminders: turning a raw
// Google Calendar event title into a parsed session, fetching a trainer's
// events from Google, and sending the reminder email. No third-party
// packages -- fetch/URL/Intl are all built into the Deno runtime Edge
// Functions run on.

const TIMEZONE = "Asia/Kolkata";
// Fixed +5:30 offset -- India doesn't observe DST, so this arithmetic is
// safe without pulling in a full timezone library. See the "known
// limitations" note in the plan if this ever needs to be per-trainer.
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

// ---------------------------------------------------------------------------
// Title parsing
// ---------------------------------------------------------------------------

export interface ParsedSession {
  names: string[];
  paidStatus: "Paid" | "Unpaid";
  location: string;
}

/**
 * "Name(s) : Paid/Unpaid : Location" -> structured session, or null if the
 * title doesn't match that shape at all (i.e. it's not a client session --
 * other calendar clutter is meant to be skipped, not guessed at).
 *
 * Handles both conventions seen in real use: multiple names as separate
 * " : "-delimited segments ("Kiran : Rohini : Kavitha : Paid : Anytime"),
 * and multiple names joined with "/" inside one segment
 * ("Yashika / Diksha / Nikita : Paid : Anytime").
 */
export function parseSessionTitle(rawTitle: string): ParsedSession | null {
  const parts = rawTitle
    .split(" : ")
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

// ---------------------------------------------------------------------------
// Date range
// ---------------------------------------------------------------------------

/** [start, end) of "tomorrow" in Asia/Kolkata, as RFC3339 UTC timestamps. */
export function tomorrowRangeUtc(now: Date = new Date()): {
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

// ---------------------------------------------------------------------------
// Google
// ---------------------------------------------------------------------------

export async function refreshGoogleAccessToken(
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

  const data = await response.json();
  return data.access_token as string;
}

export interface CalendarEvent {
  id: string;
  summary: string;
  /** ISO datetime, or a bare date for all-day events. */
  start: string;
}

export async function fetchEventsInRange(
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
      `Google Calendar fetch failed (${response.status}): ${await response.text()}`,
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

// ---------------------------------------------------------------------------
// Email
// ---------------------------------------------------------------------------

export interface ReminderEmailInput {
  to: string;
  traineeName: string;
  sessionStart: string; // ISO
  location: string;
  paidStatus: "Paid" | "Unpaid";
}

export async function sendReminderEmail(
  input: ReminderEmailInput,
  resendApiKey: string,
  fromAddress: string,
): Promise<void> {
  const sessionTime = new Date(input.sessionStart).toLocaleString("en-IN", {
    timeZone: TIMEZONE,
    weekday: "long",
    hour: "numeric",
    minute: "2-digit",
    hour12: true,
  });

  const paymentLine = input.paidStatus === "Unpaid"
    ? "<p>Payment for this session is still pending.</p>"
    : "";

  const html = `
    <p>Hi ${escapeHtml(input.traineeName)},</p>
    <p>Reminder: you have a training session tomorrow, ${escapeHtml(sessionTime)}, at ${escapeHtml(input.location)}.</p>
    ${paymentLine}
    <p>See you there!</p>
  `.trim();

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromAddress,
      to: input.to,
      subject: `Reminder: your session tomorrow at ${sessionTime}`,
      html,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `Resend send failed (${response.status}): ${await response.text()}`,
    );
  }
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
