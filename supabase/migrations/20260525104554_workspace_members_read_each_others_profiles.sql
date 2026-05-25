-- Lets workspace members read each other's user profile rows so the
-- Permissions screen can render display_name + email instead of falling
-- back to the placeholder "Member" + blank email.
--
-- Original "users can read own profile" policy is restricted to id = auth.uid(),
-- which means joining workspace_memberships → users(...) only returns the
-- current user's row populated; everyone else came back as null embedded.
--
-- New policy is scoped to "you and them share at least one active workspace
-- membership" so this doesn't widen access to every user in the database.
-- A user who's never been in a workspace with you stays invisible.

create policy "workspace members can read each others profiles"
on turfmapp_expenses.users
for select
using (
  exists (
    select 1
    from turfmapp_expenses.workspace_memberships me
    join turfmapp_expenses.workspace_memberships them
      on them.workspace_id = me.workspace_id
    where me.user_id = auth.uid()
      and me.status = 'active'
      and them.user_id = users.id
      and them.status = 'active'
  )
);
