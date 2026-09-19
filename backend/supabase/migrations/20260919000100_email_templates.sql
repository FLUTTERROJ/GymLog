create table public.email_templates (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.profiles (id) on delete cascade,
  location text not null check (length(btrim(location)) between 1 and 120),
  paid_status text not null check (paid_status in ('Paid', 'Unpaid')),
  subject text not null check (length(btrim(subject)) between 1 and 200),
  body text not null check (length(btrim(body)) between 1 and 10000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (trainer_id, location, paid_status)
);

create index email_templates_trainer_idx
  on public.email_templates (trainer_id);

create trigger email_templates_touch_updated_at
  before update on public.email_templates
  for each row execute function public.touch_updated_at();

alter table public.email_templates enable row level security;

create policy "email templates: trainer manages own"
  on public.email_templates for all
  to authenticated
  using (trainer_id = auth.uid())
  with check (trainer_id = auth.uid());
