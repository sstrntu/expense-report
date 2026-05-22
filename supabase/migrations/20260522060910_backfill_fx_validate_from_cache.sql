-- Harden backfill_expense_fx: validate the supplied FX rate against the
-- fx_rates cache before writing it to the expense row.
--
-- The original RPC accepted any numeric rate from the caller, letting a
-- workspace member forge FX values on unsnapshotted rows to inflate or deflate
-- converted amounts in the dashboard. The fix: cross-check the supplied rate
-- against the fx_rates cache row for the same (from, to, date) triple. If no
-- cache row exists OR the caller's rate deviates by more than 1% from the
-- stored rate, the call is rejected. Only the edge function writes to fx_rates
-- (using service_role), so its values are authoritative.

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
  workspace     uuid;
  cached_rate   numeric;
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

  -- Validate the supplied rate against the fx_rates cache.
  -- The edge function always writes to fx_rates before returning, so a cache
  -- miss means the caller didn't go through the edge function.
  select r.rate into cached_rate
    from turfmapp_expenses.fx_rates r
   where r.from_currency = (select amount_currency from turfmapp_expenses.expenses where id = expense_id)
     and r.to_currency   = backfill_expense_fx.base_currency
     and r.as_of_date    = backfill_expense_fx.fx_rate_as_of
   limit 1;

  if cached_rate is null then
    raise exception 'rate_not_cached' using errcode = '22023',
      detail = 'FX rate must be fetched via the convert-currency edge function before backfilling';
  end if;

  -- Allow ≤1% deviation to absorb minor floating-point rounding differences.
  if abs(backfill_expense_fx.fx_rate - cached_rate) / cached_rate > 0.01 then
    raise exception 'rate_mismatch' using errcode = '22023',
      detail = format('supplied rate %s deviates >1%% from cached rate %s', backfill_expense_fx.fx_rate, cached_rate);
  end if;

  update turfmapp_expenses.expenses e
     set base_currency        = backfill_expense_fx.base_currency,
         amount_in_base_minor = backfill_expense_fx.amount_in_base_minor,
         fx_rate              = backfill_expense_fx.fx_rate,
         fx_rate_as_of        = backfill_expense_fx.fx_rate_as_of,
         fx_source            = backfill_expense_fx.fx_source
   where e.id = expense_id
     and e.amount_in_base_minor is null;
end;
$$;

revoke all on function turfmapp_expenses.backfill_expense_fx(uuid, text, integer, numeric, date, text) from public;
grant execute on function turfmapp_expenses.backfill_expense_fx(uuid, text, integer, numeric, date, text)
  to authenticated;
