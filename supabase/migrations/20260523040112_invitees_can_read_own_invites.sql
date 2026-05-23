-- Lets invitees discover pending invites addressed to their own email without
-- needing to know the workspace or the invite UUID. Powers the new onboarding
-- flow where the iOS app auto-detects pending invites for a newly signed-in
-- user and renders them as one-tap "Join" cards.

create policy "invitees can read their own pending invites"
on turfmapp_expenses.workspace_invites
for select
using (
  status = 'pending'
  and lower(email) = lower(coalesce((select email from auth.users where id = auth.uid()), ''))
);

-- Companion view that joins the invite to a thin slice of the workspace
-- (name + brand color) so the iOS layer can render a meaningful card
-- without unlocking the full workspaces table for non-members.
-- security_invoker keeps RLS on the underlying tables intact.
create or replace view turfmapp_expenses.pending_invites_for_me
with (security_invoker = true)
as
select
  i.id                                  as invite_id,
  i.workspace_id,
  i.email,
  i.role,
  i.status,
  i.expires_at,
  i.created_at,
  w.name                                as workspace_name,
  w.brand_color                         as workspace_brand_color,
  w.default_currency                    as workspace_default_currency
from turfmapp_expenses.workspace_invites i
join turfmapp_expenses.workspaces w on w.id = i.workspace_id
where i.status = 'pending';

grant select on turfmapp_expenses.pending_invites_for_me to authenticated;

-- Companion policy: invitees can read the workspace row referenced by an
-- invite addressed to them. Scoped via the pending invite check so we don't
-- broaden the workspaces table to all authenticated users.
create policy "invitees can read invited workspaces"
on turfmapp_expenses.workspaces
for select
using (
  exists (
    select 1
    from turfmapp_expenses.workspace_invites i
    where i.workspace_id = workspaces.id
      and i.status = 'pending'
      and lower(i.email) = lower(coalesce((select email from auth.users where id = auth.uid()), ''))
  )
);
