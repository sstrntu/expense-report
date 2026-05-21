-- Fix the route_submitted_expense trigger's cross-currency threshold comparison.
--
-- Before: compared `new.amount_minor` (in expense.currency) against
-- `proj.approval_threshold_minor` (in proj.budget_currency). When the
-- expense and project use different currencies, that's an apples-to-oranges
-- comparison: a 1,172 THB receipt (≈$35) shows up as 117200 minor units,
-- which exceeds a 10000-minor ($100) USD threshold, so it routes to
-- pending_manager_approval instead of auto-approving.
--
-- After: use the FX snapshot when one exists and its base currency matches
-- the project's base. Fall back to the native amount when there's no
-- snapshot (legacy rows pending backfill) or when the expense's native
-- currency already matches the project base (no conversion needed). The
-- comparison currency is now always the project's threshold currency.

create or replace function turfmapp_expenses.route_submitted_expense()
returns trigger
language plpgsql
security definer
set search_path = turfmapp_expenses, public
as $$
declare
  proj turfmapp_expenses.projects;
  is_new_submission boolean;
  effective_amount_minor integer;
begin
  is_new_submission :=
    new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from 'submitted');
  if not is_new_submission then
    return new;
  end if;

  select * into proj from turfmapp_expenses.projects where id = new.project_id;
  if not found then
    return new;
  end if;

  if new.submitted_at is null then
    new.submitted_at := now();
  end if;

  -- Pick the amount to compare against the threshold:
  --   1. If the expense's native currency already matches the project base,
  --      use it directly — no conversion needed.
  --   2. Otherwise, use the FX-snapshotted amount if its currency matches
  --      the project base (it always should — both come from project.budget.currency).
  --   3. Fall back to native amount as a last resort for legacy rows missing
  --      a snapshot. This is the pre-fix behaviour: imprecise across
  --      currencies but consistent with what the system did before.
  effective_amount_minor := case
    when new.currency = proj.budget_currency then new.amount_minor
    when new.amount_in_base_minor is not null
      and new.base_currency = proj.budget_currency then new.amount_in_base_minor
    else new.amount_minor
  end;

  if proj.approval_threshold_minor > 0
     and effective_amount_minor <= proj.approval_threshold_minor then
    if new.type = 'pre_approval' then
      new.status := 'approved';
    else
      new.status := 'ready_for_reimbursement';
    end if;
    return new;
  end if;

  new.status := case proj.routing_mode
    when 'finance_only'              then 'pending_finance_review'
    when 'auto_approve_then_finance' then 'pending_finance_review'
    when 'auto_reimburse'            then 'ready_for_reimbursement'
    else 'pending_manager_approval'
  end;
  return new;
end;
$$;
