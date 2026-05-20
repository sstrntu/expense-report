-- Tighten WITH CHECK clauses on expense UPDATE policies so the new row's
-- status is constrained to the legitimate target of each role's transition.
-- Previously the WITH CHECK only validated the role/membership, so an actor
-- with the right qualifying-status row could PATCH it to any status,
-- bypassing the workflow (e.g. submitter → reimbursed, manager → reimbursed).

drop policy if exists "submitters can update own draft expenses" on turfmapp_expenses.expenses;

create policy "submitters can update own expenses" on turfmapp_expenses.expenses
for update using (
  turfmapp_expenses.is_expense_submitter(id)
  and status = any(array[
    'draft'::turfmapp_expenses.expense_status,
    'rejected'::turfmapp_expenses.expense_status,
    'approved'::turfmapp_expenses.expense_status
  ])
) with check (
  turfmapp_expenses.is_expense_submitter(id)
  and status = any(array[
    'draft'::turfmapp_expenses.expense_status,
    'submitted'::turfmapp_expenses.expense_status,
    'purchase_confirmed'::turfmapp_expenses.expense_status,
    'cancelled'::turfmapp_expenses.expense_status,
    'archived'::turfmapp_expenses.expense_status
  ])
);

drop policy if exists "approvers can update manager queue expenses" on turfmapp_expenses.expenses;

create policy "approvers can update manager queue expenses" on turfmapp_expenses.expenses
for update using (
  status = 'pending_manager_approval'::turfmapp_expenses.expense_status
  and turfmapp_expenses.can_approve_project(project_id)
) with check (
  turfmapp_expenses.can_approve_project(project_id)
  and status = any(array[
    'approved'::turfmapp_expenses.expense_status,
    'rejected'::turfmapp_expenses.expense_status,
    'pending_finance_review'::turfmapp_expenses.expense_status
  ])
);

drop policy if exists "finance can update finance queue expenses" on turfmapp_expenses.expenses;

create policy "finance can update finance queue expenses" on turfmapp_expenses.expenses
for update using (
  (
    status = any(array[
      'pending_finance_review'::turfmapp_expenses.expense_status,
      'ready_for_reimbursement'::turfmapp_expenses.expense_status,
      'purchase_confirmed'::turfmapp_expenses.expense_status
    ])
    or (status = 'approved'::turfmapp_expenses.expense_status and type = 'reimbursement_claim'::turfmapp_expenses.expense_type)
  )
  and turfmapp_expenses.can_finance_project(project_id)
) with check (
  turfmapp_expenses.can_finance_project(project_id)
  and status = any(array[
    'ready_for_reimbursement'::turfmapp_expenses.expense_status,
    'reimbursed'::turfmapp_expenses.expense_status,
    'rejected'::turfmapp_expenses.expense_status
  ])
);
