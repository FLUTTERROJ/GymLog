-- SyncFit :: let a signed-in user create their own missing profile row.
--
-- profiles rows are meant to be created automatically by the
-- on_auth_user_created trigger (see 20260727000100_init.sql), but that
-- hasn't reliably fired for every sign-in path -- observed in practice for
-- Google-only sign-ups (no prior email/password account) across several
-- accounts and several weeks, despite the trigger being present and
-- enabled. Rather than depend on fully understanding an opaque trigger
-- timing issue inside Supabase Auth's own internals, the app now
-- self-heals: if a signed-in user has no profile row, it creates one for
-- itself. This policy is what makes that legal under RLS.
--
-- Scoped to exactly the same identity check as every other "own row"
-- policy on this table -- a user can only ever insert a row for themself.
create policy "profiles: insert own"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());
