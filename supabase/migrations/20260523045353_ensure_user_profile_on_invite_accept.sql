-- Fixes "insert or update on table workspace_memberships violates foreign
-- key constraint" thrown when a brand-new (e.g. just-signed-up) user redeems
-- an invite code.
--
-- workspace_memberships.user_id references turfmapp_expenses.users(id), not
-- auth.users(id) — so accepting an invite requires a profile row to already
-- exist. Until now, the only path that inserted that profile row was
-- create_workspace_with_admin (the "create workspace" flow). A user who
-- signed up and immediately tried to join an existing workspace via code
-- failed the foreign-key check.
--
-- Both accept RPCs now upsert a thin profile row from auth.users metadata
-- before creating the membership. Mirrors what create_workspace_with_admin
-- does at the top of its body.

create or replace function turfmapp_expenses.ensure_user_profile_exists(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path to 'turfmapp_expenses, public'
as $$
begin
  insert into turfmapp_expenses.users (id, email, email_verified_at, display_name, avatar_url)
  select
    au.id,
    lower(coalesce(au.email, '')),
    au.email_confirmed_at,
    coalesce(
      nullif(au.raw_user_meta_data ->> 'display_name', ''),
      nullif(au.raw_user_meta_data ->> 'full_name', ''),
      nullif(au.raw_user_meta_data ->> 'name', ''),
      split_part(coalesce(au.email, ''), '@', 1),
      'New user'
    ),
    au.raw_user_meta_data ->> 'avatar_url'
  from auth.users au
  where au.id = p_user_id
  on conflict (id) do update set
    email = excluded.email,
    email_verified_at = excluded.email_verified_at,
    updated_at = now();
end $$;

-- ---------- 1. Update accept-by-code RPC to call the helper ----------

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
end $$;

grant execute on function turfmapp_expenses.accept_workspace_invite_by_code(text) to authenticated;

-- ---------- 2. Same fix for the legacy UUID-based accept RPC ----------

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

  select lower(email) into v_email from auth.users where id = v_user_id;
  if v_email is null or v_email <> lower(v_invite.email) then
    raise exception 'this invite is not addressed to your account' using errcode = '42501';
  end if;

  perform turfmapp_expenses.ensure_user_profile_exists(v_user_id);

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
end $$;

grant execute on function turfmapp_expenses.accept_workspace_invite(uuid) to authenticated;
