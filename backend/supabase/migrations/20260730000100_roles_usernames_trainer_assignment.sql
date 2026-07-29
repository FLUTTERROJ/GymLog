-- GymLog :: account roles, unique usernames, and per-workout trainer access.

alter table public.profiles
  add column if not exists username text;

alter table public.workouts
  add column if not exists trainer_id uuid references public.profiles (id) on delete set null;

alter table public.profiles
  add constraint profiles_username_format_ck
  check (username is null or username ~ '^[A-Za-z0-9_]{3,30}$');

create unique index if not exists profiles_username_normalized_uniq
  on public.profiles (lower(username)) where username is not null;

create index if not exists workouts_trainer_id_idx on public.workouts (trainer_id);

-- New accounts receive their selected role and username from auth metadata.
-- Existing accounts keep their current profile and are prompted by the app to
-- complete these fields on their next sign-in.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_role text := coalesce(new.raw_user_meta_data ->> 'role', 'trainee');
  requested_username text := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'username', '')), '');
begin
  insert into public.profiles (id, email, full_name, role, username)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    case when requested_role in ('client', 'trainer') then requested_role else 'client' end,
    requested_username
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Secure trainer lookup: trainees can discover only trainer id, username, and
-- display name, never emails or other profile fields.
create or replace function public.search_trainers(p_query text default '')
returns table (id uuid, username text, full_name text)
language sql
security definer
stable
set search_path = public
as $$
  select p.id, p.username, p.full_name
  from public.profiles p
  where auth.uid() is not null
    and p.role = 'trainer'
    and p.username is not null
    and lower(p.username) like '%' || lower(btrim(p_query)) || '%'
  order by p.username
  limit 30;
$$;

-- Trainer dashboard source. A trainer sees only users with at least one
-- workout explicitly assigned to them.
create or replace function public.get_my_trainees()
returns table (id uuid, username text, full_name text, workout_count bigint, latest_workout_date date)
language sql
security definer
stable
set search_path = public
as $$
  select p.id, p.username, p.full_name, count(w.id), max(w.workout_date)
  from public.workouts w
  join public.profiles p on p.id = w.user_id
  where w.trainer_id = auth.uid()
  group by p.id, p.username, p.full_name
  order by max(w.workout_date) desc;
$$;

-- Narrow helpers avoid RLS recursion when a set or custom exercise is read.
create or replace function public.workout_trainer(p_workout uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$ select w.trainer_id from public.workouts w where w.id = p_workout; $$;

create or replace function public.is_trainer_for_exercise_owner(p_owner uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.workouts w
    where w.user_id = p_owner and w.trainer_id = auth.uid()
  );
$$;

revoke all on function public.search_trainers(text), public.get_my_trainees(), public.workout_trainer(uuid), public.is_trainer_for_exercise_owner(uuid) from public;
grant execute on function public.search_trainers(text), public.get_my_trainees(), public.workout_trainer(uuid), public.is_trainer_for_exercise_owner(uuid) to authenticated;

-- Replace the original client->trainer-profile security with per-workout
-- assignment. Trainers remain strictly read-only.
drop policy if exists "profiles: trainer reads clients" on public.profiles;
drop policy if exists "exercises: read global and own" on public.exercises;
drop policy if exists "workouts: trainer reads clients" on public.workouts;
drop policy if exists "sets: trainer reads clients" on public.workout_sets;

create policy "exercises: read global own or assigned trainee"
  on public.exercises for select to authenticated
  using (is_global or created_by = auth.uid() or public.is_trainer_for_exercise_owner(created_by));

create policy "workouts: trainer reads assigned"
  on public.workouts for select to authenticated
  using (trainer_id = auth.uid());

create policy "sets: trainer reads assigned"
  on public.workout_sets for select to authenticated
  using (public.workout_trainer(workout_id) = auth.uid());
