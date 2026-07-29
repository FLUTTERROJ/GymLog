-- ============================================================================
-- GymLog :: core schema
-- ============================================================================
-- Entities:
--   profiles      1:1 with auth.users, carries the client -> trainer link
--   exercises     global catalogue + per-user custom additions
--   workouts      one row per user per calendar day
--   workout_sets  the actual logged work (exercise + reps + optional weight)
-- ============================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  full_name   text,
  role        text not null default 'client' check (role in ('client', 'trainer')),
  -- the trainer allowed to read this client's logs
  trainer_id  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index profiles_trainer_id_idx on public.profiles (trainer_id);

create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Create the profile row automatically whenever a user signs up (email or OAuth).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------
-- `is_global` rows ship with the app and are visible to everybody.
-- Anything a user types into the picker that isn't in the list gets stored as a
-- private row owned by them (is_global = false, created_by = them).
create table public.exercises (
  id               uuid primary key default gen_random_uuid(),
  name             text not null check (length(btrim(name)) between 1 and 80),
  name_normalized  text generated always as (lower(btrim(name))) stored,
  muscle_group     text,
  is_global        boolean not null default false,
  created_by       uuid references auth.users (id) on delete cascade,
  created_at       timestamptz not null default now(),

  -- a global exercise has no owner; a custom one must have one
  constraint exercises_ownership_ck check (
    (is_global and created_by is null) or (not is_global and created_by is not null)
  )
);

-- No two global exercises share a name, and no user can create the same custom
-- exercise twice. Partial indexes so a user *may* shadow a global name if they
-- somehow race it -- the add_exercise() RPC below prevents that in practice.
create unique index exercises_global_name_uniq
  on public.exercises (name_normalized) where is_global;

create unique index exercises_user_name_uniq
  on public.exercises (created_by, name_normalized) where not is_global;

create index exercises_created_by_idx on public.exercises (created_by);

-- ---------------------------------------------------------------------------
-- workouts (one per user per day)
-- ---------------------------------------------------------------------------
create table public.workouts (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  workout_date  date not null default current_date,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  unique (user_id, workout_date)
);

create index workouts_user_date_idx on public.workouts (user_id, workout_date desc);

create trigger workouts_touch_updated_at
  before update on public.workouts
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- workout_sets
-- ---------------------------------------------------------------------------
-- One row per set actually performed. Grouping sets back under their exercise
-- is done in the client, which keeps this table flat and easy to query.
create table public.workout_sets (
  id           uuid primary key default gen_random_uuid(),
  workout_id   uuid not null references public.workouts (id) on delete cascade,
  exercise_id  uuid not null references public.exercises (id) on delete restrict,
  set_number   integer not null check (set_number between 1 and 50),
  reps         integer not null check (reps between 1 and 1000),
  weight_kg    numeric(6, 2) check (weight_kg >= 0),
  created_at   timestamptz not null default now(),

  unique (workout_id, exercise_id, set_number)
);

create index workout_sets_workout_idx on public.workout_sets (workout_id);
create index workout_sets_exercise_idx on public.workout_sets (exercise_id);

-- ---------------------------------------------------------------------------
-- RPC: add_exercise
-- ---------------------------------------------------------------------------
-- Called when the user types an exercise the dropdown doesn't have.
-- Returns the existing row if the name already exists (global or theirs) so we
-- never end up with "Bench Press" / "bench press" duplicates in the picker.
create or replace function public.add_exercise(
  p_name text,
  p_muscle_group text default null
)
returns public.exercises
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_norm text := lower(btrim(coalesce(p_name, '')));
  v_row  public.exercises;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  if v_norm = '' then
    raise exception 'Exercise name cannot be empty' using errcode = '22023';
  end if;

  select * into v_row
  from public.exercises e
  where e.name_normalized = v_norm
    and (e.is_global or e.created_by = v_uid)
  order by e.is_global desc
  limit 1;

  if found then
    return v_row;
  end if;

  insert into public.exercises (name, muscle_group, is_global, created_by)
  values (btrim(p_name), nullif(btrim(coalesce(p_muscle_group, '')), ''), false, v_uid)
  returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: get_or_create_workout
-- ---------------------------------------------------------------------------
-- The client needs a workout id before it can attach sets. Doing it here keeps
-- the "one workout per day" rule out of the app code.
create or replace function public.get_or_create_workout(p_date date default current_date)
returns public.workouts
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.workouts;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  if p_date > current_date then
    raise exception 'Cannot log a workout in the future' using errcode = '22023';
  end if;

  insert into public.workouts (user_id, workout_date)
  values (v_uid, p_date)
  on conflict (user_id, workout_date) do update
    set updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;
