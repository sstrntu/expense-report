-- Lets an admin scope an invite to a specific project. The invitee still
-- gets a workspace_memberships row (so they can sign in and use the app),
-- and when project_id is set the accept RPC also creates the matching
-- project_membership row atomically. Removes the "invite to workspace,
-- then track them down in Manage Projects to add to a project" two-step.

alter table turfmapp_expenses.workspace_invites
  add column if not exists project_id uuid references turfmapp_expenses.projects(id) on delete set null,
  add column if not exists project_role turfmapp_expenses.project_role;

-- Constraint: both fields must be set together, or both null. Anything in
-- between would be an invalid invite the accept RPC couldn't honour.
alter table turfmapp_expenses.workspace_invites
  drop constraint if exists workspace_invites_project_pair;
alter table turfmapp_expenses.workspace_invites
  add constraint workspace_invites_project_pair
  check ((project_id is null and project_role is null) or
         (project_id is not null and project_role is not null));

-- Replace the accept-by-code RPC so it also creates the project_membership
-- row when the invite targets a project. Same return shape as before.
create or replace function turfmapp_expenses.accept_workspace_invite_by_code(p_code text)
returns turfmapp_expenses.workspace_memberships
language plpgsql
security definer
set search_path to 'turfmapp_expenses, public'
as $$
declare
  v_user_id uuid;
  v_invite turfmapp_expenses.workspace_invites;
  v_existing turfmapp_expenses.workspace_memberships;
  v_new turfmapp_expenses.workspace_memberships;
  v_normalized text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  v_normalized := regexp_replace(coalesce(p_code, ''), '[^0-9]', '', 'g');
  if length(v_normalized) <> 6 then
    raise exception 'invite code must be 6 digits' using errcode = '22023';
  end if;

  select * into v_invite
  from turfmapp_expenses.workspace_invites
  where code = v_normalized and status = 'pending'
  for update;

  if not found then
    raise exception 'invite code not found' using errcode = 'P0002';
  end if;

  if v_invite.expires_at < now() then
    update turfmapp_expenses.workspace_invites set status = 'expired' where id = v_invite.id;
    raise exception 'invite has expired' using errcode = '22023';
  end if;

  -- Ensure the profile row exists before we try to FK against it.
  perform turfmapp_expenses.ensure_user_profile_exists(v_user_id);

  -- Workspace membership: reactivate if present, otherwise insert fresh.
  select * into v_existing
  from turfmapp_expenses.workspace_memberships
  where workspace_id = v_invite.workspace_id and user_id = v_user_id;

  if found then
    update turfmapp_expenses.workspace_memberships
    set status = 'active', role = v_invite.role, removed_at = null
    where id = v_existing.id
    returning * into v_new;
  else
    insert into turfmapp_expenses.workspace_memberships (workspace_id, user_id, role, status)
    values (v_invite.workspace_id, v_user_id, v_invite.role, 'active')
    returning * into v_new;
  end if;

  -- Project-level membership, if the invite targets a project. Upsert by
  -- (project_id, workspace_membership_id) so re-accepting a similar invite
  -- updates the role rather than failing on the unique constraint.
  if v_invite.project_id is not null and v_invite.project_role is not null then
    insert into turfmapp_expenses.project_memberships (project_id, workspace_membership_id, role)
    values (v_invite.project_id, v_new.id, v_invite.project_role)
    on conflict (project_id, workspace_membership_id) do update
      set role = excluded.role,
          updated_at = now();
  end if;

  update turfmapp_expenses.workspace_invites
  set status = 'accepted', accepted_by_user_id = v_user_id
  where id = v_invite.id;

  return v_new;
end $$;

grant execute on function turfmapp_expenses.accept_workspace_invite_by_code(text) to authenticated;
