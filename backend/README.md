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
    │   ├── 20260727000100_init.sql   tables, triggers, RPC functions
    │   └── 20260727000200_rls.sql    row level security policies
    └── seed.sql                      ~75 starter exercises
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

## Checking RLS actually works

Worth doing once, from the SQL editor:

```sql
-- pretend to be a specific user
set local role authenticated;
set local request.jwt.claims = '{"sub":"<some-user-uuid>","role":"authenticated"}';
select count(*) from public.workouts;  -- only that user's rows
```

Run it with two different UUIDs and confirm the counts differ.
