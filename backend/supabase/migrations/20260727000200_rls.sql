-- ============================================================================
-- GymLog :: Row Level Security
-- ============================================================================
-- Rules in one paragraph:
--   * A user reads and writes only their own workouts and sets.
--   * A trainer gets READ-ONLY access to the workouts of clients whose
--     profiles.trainer_id points at them. They can never write client data.
--   * Exercises: everyone sees the global catalogue plus their own additions.
--     A user's custom exercise is also visible to their trainer, otherwise the
--     trainer's history view would show sets with no exercise name attached.
-- ============================================================================

alter table public.profiles     enable row level security;
alter table public.exercises    enable row level security;
alter table public.workouts     enable row level security;
alter table public.workout_sets enable row level security;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER on purpose: a policy on `profiles` that itself queries
-- `profiles` would recurse infinitely. Running as the owner bypasses RLS for
-- this one narrow lookup.
create or replace function public.is_trainer_of(p_client uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_client
      and p.trainer_id = auth.uid()
  );
$$;

revoke all on function public.is_trainer_of(uuid) from public;
grant execute on function public.is_trainer_of(uuid) to authenticated;

-- Owner of a workout, without tripping over workout RLS from a set policy.
create or replace function public.workout_owner(p_workout uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select w.user_id from public.workouts w where w.id = p_workout;
$$;

revoke all on function public.workout_owner(uuid) from public;
grant execute on function public.workout_owner(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------
create policy "profiles: read own"
  on public.profiles for select
  to authenticated
  using (id = auth.uid());

create policy "profiles: trainer reads clients"
  on public.profiles for select
  to authenticated
  using (trainer_id = auth.uid());

create policy "profiles: update own"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------
create policy "exercises: read global and own"
  on public.exercises for select
  to authenticated
  using (
    is_global
    or created_by = auth.uid()
    or public.is_trainer_of(created_by)
  );

create policy "exercises: insert own custom"
  on public.exercises for insert
  to authenticated
  with check (
    not is_global
    and created_by = auth.uid()
  );

create policy "exercises: update own custom"
  on public.exercises for update
  to authenticated
  using (not is_global and created_by = auth.uid())
  with check (not is_global and created_by = auth.uid());

-- Deliberately no DELETE policy: deleting an exercise would orphan historical
-- sets (and the FK is ON DELETE RESTRICT anyway).

-- ---------------------------------------------------------------------------
-- workouts
-- ---------------------------------------------------------------------------
create policy "workouts: read own"
  on public.workouts for select
  to authenticated
  using (user_id = auth.uid());

create policy "workouts: trainer reads clients"
  on public.workouts for select
  to authenticated
  using (public.is_trainer_of(user_id));

create policy "workouts: insert own"
  on public.workouts for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "workouts: update own"
  on public.workouts for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "workouts: delete own"
  on public.workouts for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- workout_sets
-- ---------------------------------------------------------------------------
create policy "sets: read own"
  on public.workout_sets for select
  to authenticated
  using (public.workout_owner(workout_id) = auth.uid());

create policy "sets: trainer reads clients"
  on public.workout_sets for select
  to authenticated
  using (public.is_trainer_of(public.workout_owner(workout_id)));

create policy "sets: insert own"
  on public.workout_sets for insert
  to authenticated
  with check (public.workout_owner(workout_id) = auth.uid());

create policy "sets: update own"
  on public.workout_sets for update
  to authenticated
  using (public.workout_owner(workout_id) = auth.uid())
  with check (public.workout_owner(workout_id) = auth.uid());

create policy "sets: delete own"
  on public.workout_sets for delete
  to authenticated
  using (public.workout_owner(workout_id) = auth.uid());
