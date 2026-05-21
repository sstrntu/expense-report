-- One-time FX backfill RPC.
--
-- The expense UPDATE policies are workflow-state aware (submitters on drafts,
-- approvers on manager queue, finance on finance queue). A plain PATCH from
-- the client to stamp FX snapshot columns on a `reimbursed` row would silently
-- return zero rows because no policy permits that combination. FX fields are
-- administrative metadata, not workflow state, so we expose them via a tight
-- SECURITY DEFINER RPC that:
--   1. Verifies the caller is a member of the expense's workspace.
--   2. Only fills snapshot columns that are currently NULL — never clobbers a
--      real create-time snapshot.
--   3. Touches nothing else: no status change, no native amount change.
--
-- Idempotent: calling twice with the same args is a no-op after the first call
-- because of the NULL guard. Safe to retry from the backfill loop on launch.

create or replace function turfmapp_expenses.backfill_expense_fx(
  expense_id uuid,
  base_currency text,
  amount_in_base_minor integer,
  fx_rate numeric,
  fx_rate_as_of date,
  fx_source text
) returns void
language plpgsql
security definer
set search_path = turfmapp_expenses, pg_catalog
as $$
declare
  workspace uuid;
begin
  select e.workspace_id into workspace
    from turfmapp_expenses.expenses e
   where e.id = expense_id;

  if workspace is null then
    raise exception 'expense_not_found' using errcode = 'P0002';
  end if;

  if not turfmapp_expenses.is_workspace_member(workspace) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  update turfmapp_expenses.expenses e
     set base_currency        = backfill_expense_fx.base_currency,
         amount_in_base_minor = backfill_expense_fx.amount_in_base_minor,
         fx_rate              = backfill_expense_fx.fx_rate,
         fx_rate_as_of        = backfill_expense_fx.fx_rate_as_of,
         fx_source            = backfill_expense_fx.fx_source
   where e.id = expense_id
     and e.amount_in_base_minor is null;  -- never overwrite an existing snapshot
end;
$$;

-- Authenticated callers only — anon has no business touching expense rows.
revoke all on function turfmapp_expenses.backfill_expense_fx(uuid, text, integer, numeric, date, text) from public;
grant execute on function turfmapp_expenses.backfill_expense_fx(uuid, text, integer, numeric, date, text)
  to authenticated;
