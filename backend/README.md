# GymLog — Backend

Supabase *is* the backend. There is no separate API server: the Flutter app talks
to Supabase over HTTPS, and **Row Level Security** is what enforces "you only see
your own workouts, your trainer sees yours read-only". Putting a Node/Python API
in the middle would mean re-implementing auth and those same rules a second time.

So what lives here is the database itself, as versioned SQL.

```
backend/
└── supabase/
    ├── migrations/
    │   ├── 20260727000100_init.sql                              tables, triggers, RPC functions
    │   ├── 20260727000200_rls.sql                                row level security policies
    │   ├── 20260730000100_roles_usernames_trainer_assignment.sql roles, usernames, per-workout trainer access
    │   ├── 20260812000100_monthly_challenges.sql                 trainer-assigned challenges
    │   ├── 20260814000100_challenge_completion_date_guard.sql    blocks future-dated completions
    │   └── 20260817000100_calendar_reminders.sql                 Google Calendar -> trainee email reminders
    ├── functions/
    │   ├── calendar-preview/           live parse of tomorrow's calendar (called by the app)
    │   ├── calendar-send-reminders/    cron-triggered, sends the actual emails
    │   └── _shared/                    title parsing, Google/Resend calls, shared by both
    └── seed.sql                        ~75 starter exercises
```

## Schema

| Table | What it holds |
|---|---|
| `profiles` | One row per auth user. Carries `role` and `trainer_id` (the trainer allowed to read this client's logs). Created automatically by a trigger on signup — email *and* Google. |
| `exercises` | The dropdown's contents. `is_global = true` rows are the shipped catalogue everyone sees; anything a user types that isn't in the list is stored as a private row owned by them. |
| `workouts` | One row per user per calendar day (`unique (user_id, workout_date)`), plus optional notes. |
| `workout_sets` | The actual work: `workout_id` + `exercise_id` + `set_number` + `reps` + optional `weight_kg`. Flat on purpose — the app groups sets under their exercise for display. |

### RPC functions

Two things the app calls instead of writing raw inserts, because both have a rule
attached that shouldn't live in client code:

- **`add_exercise(p_name, p_muscle_group)`** — used when the user adds an exercise
  the dropdown doesn't have. If the name already exists (globally or for that
  user, case/whitespace-insensitive) it returns the existing row instead of
  inserting, so the picker never fills up with `Bench Press` / `bench press` /
  `  Bench press `.
- **`get_or_create_workout(p_date)`** — returns today's (or any past date's)
  workout row, creating it on first use. Keeps the one-workout-per-day rule in
  the database.

### Security model

- Every table has RLS enabled, and there is **no policy granting cross-user
  writes** — a trainer physically cannot modify a client's log.
- `is_trainer_of()` and `workout_owner()` are `SECURITY DEFINER`. That's
  deliberate: a policy on `profiles` that queries `profiles` recurses infinitely,
  and a policy on `workout_sets` that queries `workouts` would be blocked by
  `workouts`' own RLS. Both functions are narrow lookups and are revoked from
  `public`.
- `exercises` has no DELETE policy — removing an exercise would orphan historical
  sets. The FK is `ON DELETE RESTRICT` as a second line of defence.

## Setting it up

### 1. Create the project

Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**.
Pick a region near you. Save the database password somewhere.

From **Project Settings → API**, copy:

- **Project URL** → `SUPABASE_URL`
- **anon / public key** → `SUPABASE_ANON_KEY`

The anon key is meant to ship inside the app; it's RLS that protects your data,
not the secrecy of that key. The **service_role** key is the one that must never
touch the Flutter app.

### 2. Apply the schema

**Option A — dashboard (fastest).** Open **SQL Editor** and run, in this order:

1. `supabase/migrations/20260727000100_init.sql`
2. `supabase/migrations/20260727000200_rls.sql`
3. `supabase/seed.sql`

**Option B — CLI (better once you start changing things).**

```bash
npm install -g supabase
```

Then from the `backend/` directory:

```bash
supabase init
```

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

```bash
supabase db push
```

`supabase init` will create a `config.toml`; keep the `migrations/` folder above
as-is and it will pick them up. Seed with:

```bash
supabase db execute --file supabase/seed.sql
```

### 3. Configure auth

**Authentication → Providers → Email** — on by default. If you want signups to
work without a round trip to the inbox while you're testing, turn *Confirm email*
off. Turn it back on before real users touch it.

**Authentication → Providers → Google** — enable it, then paste in a Google OAuth
client ID and secret from the [Google Cloud console](https://console.cloud.google.com/apis/credentials)
(APIs & Services → Credentials → Create credentials → OAuth client ID → **Web
application**). Into that Google client's *Authorized redirect URIs* put the
callback URL Supabase shows you on the same screen:

```
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

**Authentication → URL Configuration → Redirect URLs** — add the app's deep link
so Google can hand the session back to the installed app:

```
io.supabase.gymlog://login-callback/
```

Add `http://localhost:3000` too if you plan to run the Flutter web build.

### 4. Link a client to their trainer

There's no invite flow yet — for now it's one statement. Make the trainer's
account a trainer, then point the client at them:

```sql
update public.profiles set role = 'trainer' where email = 'trainer@example.com';
```

```sql
update public.profiles
set trainer_id = (select id from public.profiles where email = 'trainer@example.com')
where email = 'client@example.com';
```

From that point the trainer's account can read that client's `workouts`,
`workout_sets` and custom `exercises`, and nothing else.

## Google Calendar reminders (trainer feature)

A trainer connects their Google Calendar once; a scheduled Edge Function reads
tomorrow's events, parses each title as `Name(s) : Paid/Unpaid : Location`,
resolves each name against a mapping the trainer sets up once per trainee, and
emails a reminder via Resend the evening before. See
`supabase/migrations/20260817000100_calendar_reminders.sql` for the schema and
`supabase/functions/` for the two Edge Functions (`calendar-preview`, called
live by the app; `calendar-send-reminders`, cron-triggered).

This is the one feature in this project that needs setup outside the SQL
editor. All of it is one-time.

### 1. Apply the migration

Same as any other migration — SQL editor, run
`supabase/migrations/20260817000100_calendar_reminders.sql`.

### 2. Google Cloud Console (same project as Google sign-in)

1. **APIs & Services → Library** → enable the **Google Calendar API**.
2. **APIs & Services → OAuth consent screen → Data Access** → add scope
   `https://www.googleapis.com/auth/calendar.readonly`.
3. Because that's a "sensitive" scope, the consent screen has to either be
   fully verified by Google (overkill for one trainer) or stay in **Testing**
   mode with explicit test users — under **Audience**, add the trainer's own
   Google account as a test user. Testing mode caps you at 100 test users,
   which is plenty here.
4. You already have a Google OAuth client ID/secret from setting up Google
   sign-in (`Authentication → Providers → Google` in Supabase) — reuse those
   same values as Edge Function secrets below, no new Google OAuth client
   needed.

### 3. Resend (or another transactional email provider)

1. Sign up at [resend.com](https://resend.com), grab an API key.
2. **Verify a sending domain.** The sandbox address (`onboarding@resend.dev`)
   only delivers to your own account email — sending real reminders to
   trainees requires a verified domain with the DNS records Resend gives you.
   If you don't have a domain to verify, this blocks real sends until you get
   one.
3. Once verified, decide the "from" address (e.g. `reminders@yourdomain.com`)
   — this becomes the `REMINDER_FROM_ADDRESS` secret below.

### 4. Supabase secrets

**Edge Functions → Secrets** in the dashboard (no CLI needed):

| Secret | Value |
|---|---|
| `GOOGLE_CLIENT_ID` | Same as the Google sign-in provider |
| `GOOGLE_CLIENT_SECRET` | Same as the Google sign-in provider |
| `RESEND_API_KEY` | From Resend |
| `REMINDER_FROM_ADDRESS` | Your verified Resend "from" address |
| `CRON_SECRET` | Any random string you generate — this is the shared secret that stops random requests from triggering `calendar-send-reminders` and emailing everyone |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` don't need setting — every Edge
Function gets those two injected automatically.

### 5. Deploy the two functions

**Edge Functions** in the dashboard → **Deploy a new function** → paste in
the contents of `supabase/functions/calendar-preview/index.ts`, name it
`calendar-preview`. Repeat for `calendar-send-reminders`. Both import from
`../_shared/calendar.ts` and `../_shared/cors.ts` — if the dashboard editor
doesn't let you add extra files to a function, inline those two shared files'
contents directly into each `index.ts` instead of importing them (functionally
identical, just less DRY). The CLI (`supabase functions deploy`) handles the
shared-file structure as-is if you'd rather use that.

### 6. Schedule the daily send

**Database → Cron Jobs** → new job → HTTP request:

- **URL**: `https://YOUR_PROJECT_REF.functions.supabase.co/calendar-send-reminders`
- **Method**: POST
- **Headers**: `X-Cron-Secret: <the CRON_SECRET value from step 4>`
- **Schedule**: `30 12 * * *` (6:00pm IST, i.e. the evening before each
  session) — adjust as you like.

Equivalent raw SQL, if you'd rather run it directly (requires the `pg_cron`
and `pg_net` extensions, enabled the same way from **Database → Extensions**):

```sql
select cron.schedule(
  'daily-calendar-reminders',
  '30 12 * * *',
  $$
  select net.http_post(
    url := 'https://YOUR_PROJECT_REF.functions.supabase.co/calendar-send-reminders',
    headers := jsonb_build_object('X-Cron-Secret', 'YOUR_CRON_SECRET'),
    body := '{}'::jsonb
  );
  $$
);
```

### 7. Trainer-side setup, in the app

Open the calendar icon on the trainees screen → **Connect Google Calendar** →
approve the consent screen. Then, for each name that shows up under "Names
from your calendar," tap it and pick which trainee it refers to — one-time
per name, reused automatically after that.

### Testing before relying on it

- `calendar-preview` is safe to call anytime (read-only) — open the calendar
  screen in the app and confirm tomorrow's events show up parsed correctly.
- To test an actual send without waiting for the cron schedule, invoke
  `calendar-send-reminders` directly with `curl`, using the same
  `X-Cron-Secret` header, and check that exactly one email arrives and a row
  lands in `session_reminders`. Run it again immediately after — it should
  send nothing the second time.

## Checking RLS actually works

Worth doing once, from the SQL editor:

```sql
-- pretend to be a specific user
set local role authenticated;
set local request.jwt.claims = '{"sub":"<some-user-uuid>","role":"authenticated"}';
select count(*) from public.workouts;  -- only that user's rows
```

Run it with two different UUIDs and confirm the counts differ.
