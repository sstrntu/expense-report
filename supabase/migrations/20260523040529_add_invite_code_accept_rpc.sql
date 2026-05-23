-- Adds a human-friendly 6-digit code to workspace_invites + an
-- accept-by-code RPC. Replaces the typed-UUID join flow with something users
-- can actually read out loud.
--
-- Security model: the code itself is the shared secret. Anyone who has the
-- code can join the workspace (no email match required) — matches the user's
-- "simple and straightforward" goal. Mitigated by:
--   - one active code per pending invite, enforced by a unique index
--   - 7-day default expiry (already set by application code)
--   - one-time use (status flips to 'accepted' on first redeem)
-- Email-based auto-detect (the policy in migration 20260523040112) stays in
-- place but isn't wired to UI yet — that's a future iteration.

-- ---------- 1. Code generator + column ----------

create or replace function turfmapp_expenses.generate_invite_code()
returns text
language plpgsql
volatile
as $$
begin
  -- 6 numeric digits, zero-padded. random() is good enough at this scale
  -- because the unique-pending index forces a retry on collision.
  return lpad((floor(random() * 1000000))::int::text, 6, '0');
end $$;

alter table turfmapp_expenses.workspace_invites
  add column if not exists code text;

-- Backfill existing rows. Loop on collision because random() can repeat.
do $$
declare
  v_id uuid;
  v_code text;
begin
  for v_id in
    select id from turfmapp_expenses.workspace_invites where code is null
  loop
    loop
      v_code := turfmapp_expenses.generate_invite_code();
      begin
        update turfmapp_expenses.workspace_invites set code = v_code where id = v_id;
        exit;
      exception when unique_violation then
        -- Try again with a different code.
      end;
    end loop;
  end loop;
end $$;

alter table turfmapp_expenses.workspace_invites
  alter column code set default turfmapp_expenses.generate_invite_code(),
  alter column code set not null;

-- Only pending codes need to be unique. Once accepted/expired/cancelled, the
-- same code can reappear on a future invite without ambiguity.
create unique index if not exists workspace_invites_code_pending_uidx
  on turfmapp_expenses.workspace_invites(code)
  where status = 'pending';

-- ---------- 2. Accept-by-code RPC ----------

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

  -- Strip everything that isn't a digit so users can type "123-456" or
  -- "123 456" without us caring.
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

  -- Reactivate an existing membership in place; otherwise insert a new one.
  -- (A user previously removed from this workspace can rejoin via a new code.)
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
