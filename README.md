# GymLog

Log the workout you did today; your trainer reads it.

```
├── frontend/   Flutter app (Dart)
└── backend/    Supabase schema, RLS policies, RPC functions, seed data
```

## What it does

- **Sign in** with email + password or with Google.
- **Today** — add the exercises you did. Each one is picked from a searchable
  dropdown; if the exercise isn't in the list, type it and add it, and it stays
  in your dropdown from then on. Enter reps per set, with optional weight.
  Leave a note for your trainer.
- **History** — every past day, newest first, with the full breakdown per day.
- **Your trainer** gets read-only access to your logs once they're linked to
  your account. They cannot edit anything.

## Why there's no API server in `backend/`

Supabase gives you Postgres, auth, an auto-generated REST API over your tables,
and Row Level Security. The Flutter app talks to it directly and RLS decides who
can read what — a hand-written API in the middle would mean re-implementing auth
and those same rules twice, in two places that then have to agree.

So `backend/` is the database as versioned SQL: tables, policies, and two RPC
functions holding the rules that shouldn't live in client code. If you later need
something the client genuinely can't do — a weekly summary email, a webhook —
that becomes a Supabase Edge Function alongside the migrations, not a server.

## Getting it running

1. **[`backend/README.md`](backend/README.md)** — create the Supabase project,
   run the three SQL files, switch on the Google provider. ~10 minutes.
2. **[`frontend/README.md`](frontend/README.md)** — generate the platform
   folders, drop your project URL and anon key into `env.json`, run.

Then, to link yourself to your trainer, run the two `update` statements at the
bottom of the backend README.

## Data model at a glance

```
auth.users ──1:1── profiles ──trainer_id──> profiles (the trainer)
                       │
                       └──< workouts (one per day) ──< workout_sets >── exercises
```

`exercises` holds both the shared catalogue (~75 seeded movements) and each
user's own additions. `workout_sets` is one row per set performed — flat, so
queries stay simple; the app folds sets back under their exercise for display.
