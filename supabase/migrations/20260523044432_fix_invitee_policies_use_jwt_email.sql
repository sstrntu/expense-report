-- Fixes "permission denied for table users" surfaced after sign-in.
--
-- The two policies added in 20260523040112_invitees_can_read_own_invites.sql
-- read from auth.users to look up the current user's email:
--   (select email from auth.users where id = auth.uid())
-- The `authenticated` role doesn't have SELECT on auth.users (and shouldn't —
-- it would expose every user's email). Postgres reports this as
-- "permission denied for table users" using the unqualified name, which is
-- easy to mistake for the renamed turfmapp_expenses.users table.
--
-- The Supabase-blessed alternative is auth.email(), which extracts the email
-- claim from the caller's JWT — no table access, zero RLS overhead. We drop
-- and recreate the two policies using auth.email() instead.

drop policy if exists "invitees can read their own pending invites"
  on turfmapp_expenses.workspace_invites;

create policy "invitees can read their own pending invites"
on turfmapp_expenses.workspace_invites
for select
using (
  status = 'pending'
  and lower(email) = lower(coalesce(auth.email(), ''))
);

drop policy if exists "invitees can read invited workspaces"
  on turfmapp_expenses.workspaces;

create policy "invitees can read invited workspaces"
on turfmapp_expenses.workspaces
for select
using (
  exists (
    select 1
    from turfmapp_expenses.workspace_invites i
    where i.workspace_id = workspaces.id
      and i.status = 'pending'
      and lower(i.email) = lower(coalesce(auth.email(), ''))
  )
);
