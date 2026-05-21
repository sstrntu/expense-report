-- SECURITY DEFINER RPC for the draft → submitted transition.
--
-- Problem: the `route_submitted_expense` BEFORE trigger rewrites
-- `new.status` from 'submitted' to the routed state (pending_manager_approval,
-- approved, ready_for_reimbursement, pending_finance_review) based on project
-- routing_mode + approval_threshold. RLS WITH CHECK runs on the *final* row
-- value, so a direct PATCH from a submitter client fails:
--     "new row violates row-level security policy for table 'expenses'"
--
-- A submitter is morally allowed to land their row in whatever state the
-- trigger picks — they initiated the transition. Expressing that in a
-- WITH CHECK clause would have to list every routed status, which over-grants
-- (a malicious caller could PATCH status='approved' directly, bypassing the
-- trigger). A SECURITY DEFINER RPC keeps the surface tight: it accepts only
-- one input (the expense id), verifies the caller is the original submitter,
-- verifies the current status is submittable, then writes status='submitted'
-- — letting the trigger route the rest.
--
-- Idempotent in spirit but not literally: calling on an already-submitted
-- row raises `expense_not_submittable` rather than silently no-opping, so
-- the client doesn't think a duplicate submit succeeded.

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

  if cur_status not in ('draft', 'rejected', 'approved') then
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

-- Also grant SELECT on fx_rates to service_role. The convert-currency edge
-- function uses the service role to read the cache and to upsert (which needs
-- SELECT for the ON CONFLICT lookup). The original migration only granted
-- SELECT to authenticated, leaving service_role unable to read its own cache.
grant select on turfmapp_expenses.fx_rates to service_role;
