-- Let submitters cancel (withdraw) their own expense while it is still in
-- flight. The app has always offered "Cancel submission" on pending
-- expenses, but the UPDATE policy's USING clause only admitted rows in
-- draft / rejected / approved, so cancelling a submitted or
-- pending-approval/-finance expense failed RLS even for the submitter.
--
-- The WITH CHECK target set is unchanged: from any of these states the
-- submitter can still only move the row to draft / submitted /
-- purchase_confirmed / cancelled / archived — never to an approval state.
-- Note that pending states are not in the WITH CHECK set, so a submitter
-- cannot silently edit fields while keeping the expense in review; any
-- update must move it out of the pending state.

drop policy if exists "submitters can update own expenses" on turfmapp_expenses.expenses;

create policy "submitters can update own expenses" on turfmapp_expenses.expenses
for update using (
  turfmapp_expenses.is_expense_submitter(id)
  and status = any(array[
    'draft'::turfmapp_expenses.expense_status,
    'rejected'::turfmapp_expenses.expense_status,
    'approved'::turfmapp_expenses.expense_status,
    'submitted'::turfmapp_expenses.expense_status,
    'scan_processing'::turfmapp_expenses.expense_status,
    'pending_manager_approval'::turfmapp_expenses.expense_status,
    'pending_finance_review'::turfmapp_expenses.expense_status
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
