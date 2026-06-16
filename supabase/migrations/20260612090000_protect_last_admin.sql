-- A workspace must always keep at least one active admin. Memberships,
-- invites, projects, and categories are all admin-gated in RLS, so a
-- workspace whose last admin is demoted, suspended, or removed becomes
-- permanently unmanageable from the app. The Permissions UI locks the last
-- admin's row, but the rule has to live here to also cover direct API calls
-- and any future client.

create or replace function turfmapp_expenses.protect_last_admin()
returns trigger
language plpgsql
security definer
set search_path to 'turfmapp_expenses, public'
as $$
declare
  v_other_admin_exists boolean;
begin
  -- Only guard transitions that take an *active admin* out of that state.
  if old.role <> 'admin' or old.status <> 'active' then
    return coalesce(new, old);
  end if;
  if tg_op = 'UPDATE' and new.role = 'admin' and new.status = 'active' then
    return new;
  end if;

  -- During a workspace cascade-delete the parent row is already gone; the
  -- rule only protects live workspaces, so let the cascade proceed.
  if tg_op = 'DELETE' and not exists (
    select 1 from turfmapp_expenses.workspaces w where w.id = old.workspace_id
  ) then
    return old;
  end if;

  select exists (
    select 1
    from turfmapp_expenses.workspace_memberships wm
    where wm.workspace_id = old.workspace_id
      and wm.id <> old.id
      and wm.role = 'admin'
      and wm.status = 'active'
  ) into v_other_admin_exists;

  if not v_other_admin_exists then
    raise exception 'a workspace must keep at least one active admin'
      using errcode = 'P0001';
  end if;

  return coalesce(new, old);
end $$;

drop trigger if exists protect_last_admin on turfmapp_expenses.workspace_memberships;
create trigger protect_last_admin
before update or delete on turfmapp_expenses.workspace_memberships
for each row execute function turfmapp_expenses.protect_last_admin();
