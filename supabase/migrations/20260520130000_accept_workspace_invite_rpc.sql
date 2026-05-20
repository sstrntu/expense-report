-- SECURITY DEFINER RPC for invitees to accept a workspace invite.
-- Required because the joining user isn't a workspace member yet, and
-- workspace_memberships.INSERT is restricted to admins of that workspace.
-- The function verifies the invite is addressed to the user's auth email,
-- atomically marks the invite accepted, and creates/reactivates the
-- membership row.

create or replace function turfmapp_expenses.accept_workspace_invite(invite_id uuid)
returns turfmapp_expenses.workspace_memberships
language plpgsql
security definer
set search_path to 'turfmapp_expenses, public'
as $$
declare
  v_user_id uuid;
  v_email text;
  v_invite turfmapp_expenses.workspace_invites;
  v_existing turfmapp_expenses.workspace_memberships;
  v_new turfmapp_expenses.workspace_memberships;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  -- FOR UPDATE so two concurrent accepts can't both succeed.
  select * into v_invite
  from turfmapp_expenses.workspace_invites
  where id = invite_id
  for update;

  if not found then
    raise exception 'invite not found' using errcode = 'P0002';
  end if;

  if v_invite.status <> 'pending' then
    raise exception 'invite is not pending (status: %)', v_invite.status using errcode = '22023';
  end if;

  if v_invite.expires_at < now() then
    update turfmapp_expenses.workspace_invites set status = 'expired' where id = v_invite.id;
    raise exception 'invite has expired' using errcode = '22023';
  end if;

  -- The invite must be addressed to this user's auth email.
  select lower(email) into v_email from auth.users where id = v_user_id;
  if v_email is null or v_email <> lower(v_invite.email) then
    raise exception 'this invite is not addressed to your account' using errcode = '42501';
  end if;

  -- Reactivate an existing membership in place; otherwise insert a new one.
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

  update turfmapp_expenses.workspace_invites
  set status = 'accepted', accepted_by_user_id = v_user_id
  where id = v_invite.id;

  return v_new;
end;
$$;

grant execute on function turfmapp_expenses.accept_workspace_invite(uuid) to authenticated;
