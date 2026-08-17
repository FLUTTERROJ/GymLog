-- GymLog :: Google Calendar -> automatic trainee reminders.
--
-- A trainer connects their Google Calendar once. A scheduled Edge Function
-- reads tomorrow's events, parses each title as "Name(s) : Paid/Unpaid :
-- Location", resolves each name against a per-trainer mapping to an actual
-- trainee account, and emails a reminder. See backend/README.md for the
-- external setup (Google Cloud, Resend, secrets, cron) this depends on.

-- ---------------------------------------------------------------------------
-- google_calendar_connections
-- ---------------------------------------------------------------------------
-- Holds the trainer's Google refresh token. Deliberately has NO select policy
-- below -- the token must never be readable through the client API, only by
-- an Edge Function using the service-role key, which bypasses RLS entirely.
create table public.google_calendar_connections (
  trainer_id     uuid primary key references public.profiles (id) on delete cascade,
  refresh_token  text not null,
  google_email   text,
  connected_at   timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create trigger google_calendar_connections_touch_updated_at
  before update on public.google_calendar_connections
  for each row execute function public.touch_updated_at();

alter table public.google_calendar_connections enable row level security;

-- Deliberately three narrow policies, not `for all` -- a `for all` policy
-- grants SELECT too, which would expose refresh_token to the owning
-- trainer's own client. Status is only ever read through the RPC below.
create policy "calendar connections: trainer inserts own"
  on public.google_calendar_connections for insert
  to authenticated
  with check (trainer_id = auth.uid());

create policy "calendar connections: trainer updates own"
  on public.google_calendar_connections for update
  to authenticated
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

create policy "calendar connections: trainer deletes own"
  on public.google_calendar_connections for delete
  to authenticated
  using (trainer_id = auth.uid());

-- Narrow, safe read: connected status + which Google account, never the token.
create or replace function public.get_calendar_connection_status()
returns table (connected boolean, google_email text, connected_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select true, c.google_email, c.connected_at
  from public.google_calendar_connections c
  where c.trainer_id = auth.uid()
  union all
  select false, null, null
  where not exists (
    select 1 from public.google_calendar_connections c
    where c.trainer_id = auth.uid()
  )
  limit 1;
$$;

revoke all on function public.get_calendar_connection_status() from public;
grant execute on function public.get_calendar_connection_status() to authenticated;

-- ---------------------------------------------------------------------------
-- calendar_name_mappings
-- ---------------------------------------------------------------------------
-- Links a name as it appears in the trainer's calendar (first name, nickname,
-- whatever they actually type) to a real trainee account. Manual and
-- per-trainer on purpose -- calendar titles have no stable identifier to
-- match against automatically.
create table public.calendar_name_mappings (
  id                        uuid primary key default gen_random_uuid(),
  trainer_id                uuid not null references public.profiles (id) on delete cascade,
  calendar_name             text not null check (length(btrim(calendar_name)) between 1 and 80),
  calendar_name_normalized  text generated always as (lower(btrim(calendar_name))) stored,
  trainee_id                uuid not null references public.profiles (id) on delete cascade,
  created_at                timestamptz not null default now(),

  unique (trainer_id, calendar_name_normalized)
);

create index calendar_name_mappings_trainer_idx on public.calendar_name_mappings (trainer_id);

alter table public.calendar_name_mappings enable row level security;

create policy "name mappings: trainer manages own"
  on public.calendar_name_mappings for all
  to authenticated
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());

-- ---------------------------------------------------------------------------
-- session_reminders
-- ---------------------------------------------------------------------------
-- One row per (calendar event, trainee) the reminder pipeline has seen. The
-- unique constraint is what makes sending idempotent -- the cron job can run
-- twice a day and never double-email anyone.
create table public.session_reminders (
  id                 uuid primary key default gen_random_uuid(),
  trainer_id         uuid not null references public.profiles (id) on delete cascade,
  calendar_event_id  text not null,
  trainee_id         uuid not null references public.profiles (id) on delete cascade,
  session_start      timestamptz not null,
  raw_title          text not null,
  paid_status        text not null,
  location           text not null,
  email_sent_at      timestamptz,
  created_at         timestamptz not null default now(),

  unique (trainer_id, calendar_event_id, trainee_id)
);

create index session_reminders_trainer_idx on public.session_reminders (trainer_id, session_start desc);
create index session_reminders_trainee_idx on public.session_reminders (trainee_id, session_start desc);

alter table public.session_reminders enable row level security;

create policy "session reminders: trainer reads own"
  on public.session_reminders for select
  to authenticated
  using (trainer_id = auth.uid());

create policy "session reminders: trainee reads own"
  on public.session_reminders for select
  to authenticated
  using (trainee_id = auth.uid());

-- No client INSERT/UPDATE/DELETE policies -- only the service-role Edge
-- Function writes these, which bypasses RLS entirely.
