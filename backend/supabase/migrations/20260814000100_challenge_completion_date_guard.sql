-- The app already disables ticking off a future day in the UI, but that's
-- only a courtesy -- nothing stops a trainee from calling the Supabase REST
-- API directly with their own token and posting a completion for a date that
-- hasn't happened yet. This is the actual enforcement: a completion can never
-- be dated later than the moment it's written, evaluated fresh on each
-- insert/update, exactly the write-time check we want.
alter table public.challenge_completions
  add constraint challenge_completions_not_future_ck
  check (completion_date <= current_date);
