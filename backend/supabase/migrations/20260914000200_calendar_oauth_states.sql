create table public.calendar_oauth_states (
  state text primary key,
  trainer_id uuid not null references auth.users(id) on delete cascade,
  redirect_to text not null,
  expires_at timestamptz not null
);

alter table public.calendar_oauth_states enable row level security;
