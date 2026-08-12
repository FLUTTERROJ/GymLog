create table if not exists public.monthly_challenges (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.profiles (id) on delete cascade,
  trainee_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  check (start_date <= end_date)
);

create table if not exists public.challenge_exercises (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.monthly_challenges (id) on delete cascade,
  exercise_name text not null,
  target_reps integer not null check (target_reps > 0),
  target_sets integer not null check (target_sets > 0),
  sort_order integer not null default 0
);

create table if not exists public.challenge_completions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.monthly_challenges (id) on delete cascade,
  exercise_id uuid not null references public.challenge_exercises (id) on delete cascade,
  completion_date date not null,
  completed boolean not null default false,
  completed_at timestamptz,
  unique (challenge_id, exercise_id, completion_date)
);

create index if not exists monthly_challenges_trainee_idx
  on public.monthly_challenges (trainee_id, start_date desc);

create index if not exists challenge_exercises_challenge_idx
  on public.challenge_exercises (challenge_id, sort_order);

create index if not exists challenge_completions_date_idx
  on public.challenge_completions (challenge_id, completion_date);

alter table public.monthly_challenges enable row level security;
alter table public.challenge_exercises enable row level security;
alter table public.challenge_completions enable row level security;

create policy "Monthly challenges: trainer can create for trainees"
  on public.monthly_challenges for insert to authenticated
  with check (trainer_id = auth.uid());

create policy "Monthly challenges: trainer and trainee can read assigned"
  on public.monthly_challenges for select to authenticated
  using (trainer_id = auth.uid() or trainee_id = auth.uid());

create policy "Challenge exercises: trainer and trainee can read assigned"
  on public.challenge_exercises for select to authenticated
  using (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id
        and (c.trainer_id = auth.uid() or c.trainee_id = auth.uid())
    )
  );

create policy "Challenge exercises: trainer can insert"
  on public.challenge_exercises for insert to authenticated
  with check (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainer_id = auth.uid()
    )
  );

create policy "Challenge completions: trainee can read own"
  on public.challenge_completions for select to authenticated
  using (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainee_id = auth.uid()
    )
    or exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainer_id = auth.uid()
    )
  );

create policy "Challenge completions: trainee can upsert own"
  on public.challenge_completions for insert to authenticated
  with check (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainee_id = auth.uid()
    )
  );

create policy "Challenge completions: trainee can update own"
  on public.challenge_completions for update to authenticated
  using (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainee_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.monthly_challenges c
      where c.id = challenge_id and c.trainee_id = auth.uid()
    )
  );
