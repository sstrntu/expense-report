-- Fix: finance (and admin, via can_finance_project) can now update expenses
-- in all states that appear in the finance reimbursement queue:
--   - pending_finance_review / ready_for_reimbursement (original)
--   - purchase_confirmed (pre-approval purchase was confirmed)
--   - approved where type = reimbursement_claim (direct reimbursement path)

drop policy if exists "finance can update finance queue expenses" on turfmapp_expenses.expenses;

create policy "finance can update finance queue expenses" on turfmapp_expenses.expenses
for update using (
  (
    status in ('pending_finance_review', 'ready_for_reimbursement', 'purchase_confirmed')
    or (status = 'approved' and type = 'reimbursement_claim')
  )
  and turfmapp_expenses.can_finance_project(project_id)
) with check (turfmapp_expenses.can_finance_project(project_id));
