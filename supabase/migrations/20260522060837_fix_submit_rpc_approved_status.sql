-- Fix submit_expense RPC: remove 'approved' from the submittable-status list.
--
-- An already-approved expense should not be re-submittable:
--   * Regular expenses: approval means the manager signed off; next step is
--     finance processing, not another submission cycle.
--   * Pre-approvals: once approved, the employee confirms the purchase via
--     confirmPurchase, not via submit.
-- Allowing 'approved' caused approved regular expenses to re-enter the routing
-- trigger and potentially route back to pending_manager_approval.
--
-- Only 'draft' and 'rejected' are legitimate re-submission points.

create or replace function turfmapp_expenses.submit_expense(expense_id uuid)
returns void
language plpgsql
security definer
set search_path = turfmapp_expenses, pg_catalog
as $$
declare
  cur_status         turfmapp_expenses.expense_status;
  cur_submitter      uuid;
  expense_workspace  uuid;
  caller_membership  uuid;
begin
  select status, submitted_by_membership_id, workspace_id
    into cur_status, cur_submitter, expense_workspace
    from turfmapp_expenses.expenses
   where id = expense_id;

  if not found then
    raise exception 'expense_not_found' using errcode = 'P0002';
  end if;

  if not turfmapp_expenses.is_workspace_member(expense_workspace) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  caller_membership := turfmapp_expenses.current_membership_id(expense_workspace);
  if caller_membership is null or caller_membership <> cur_submitter then
    raise exception 'not_submitter' using errcode = '42501';
  end if;

  if cur_status not in ('draft', 'rejected') then
    raise exception 'expense_not_submittable' using errcode = '22023',
                                             detail = format('current status: %s', cur_status);
  end if;

  update turfmapp_expenses.expenses
     set status = 'submitted'
   where id = expense_id;
end;
$$;

revoke all on function turfmapp_expenses.submit_expense(uuid) from public;
grant execute on function turfmapp_expenses.submit_expense(uuid) to authenticated;
