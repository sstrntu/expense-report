-- Reimbursement now writes the finance audit trail. Previously the client's
-- markReimbursed only PATCHed status='reimbursed' and discarded the
-- ReimbursementInput entirely, so payment_records (the table designed to hold
-- "who paid what, when, how, with what proof") was never written — the
-- "finance can create payment records" policy had no caller.
--
-- A SECURITY DEFINER RPC does both writes in one transaction so the status
-- change and its payment record can't drift apart (a non-atomic two-call
-- client could leave a reimbursed expense with no record, or an orphan record
-- on a still-queued expense). Authorization is re-checked inside because
-- security definer bypasses RLS — it mirrors the "finance can update finance
-- queue expenses" USING set and the payment_records INSERT policy.
--
-- The paid amount + currency are taken from the expense row itself, not from
-- the caller: amount_minor already reflects any final purchase amount written
-- at purchase-confirmation time, and deriving it server-side means a client
-- can't record a payment for an amount that differs from the expense.

create or replace function turfmapp_expenses.mark_expense_reimbursed(
  p_expense_id uuid,
  p_payment_method turfmapp_expenses.reimbursement_payment_method,
  p_paid_at timestamptz,
  p_reference text default null,
  p_proof_attachment_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = turfmapp_expenses, pg_catalog
as $$
declare
  cur_status    turfmapp_expenses.expense_status;
  cur_type      turfmapp_expenses.expense_type;
  exp_workspace uuid;
  exp_project   uuid;
  amt_minor     integer;
  cur_code      char(3);
  caller_member uuid;
begin
  select status, type, workspace_id, project_id, amount_minor, currency
    into cur_status, cur_type, exp_workspace, exp_project, amt_minor, cur_code
    from turfmapp_expenses.expenses
   where id = p_expense_id
     and deleted_at is null;

  if not found then
    raise exception 'expense_not_found' using errcode = 'P0002';
  end if;

  -- Authorization: caller must be able to finance this project (workspace
  -- finance/admin, or project finance/project_admin).
  if not turfmapp_expenses.can_finance_project(exp_project) then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  caller_member := turfmapp_expenses.current_membership_id(exp_workspace);
  if caller_member is null then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  -- Same reimbursable-from set as the finance UPDATE policy's USING clause.
  if not (
    cur_status in ('pending_finance_review', 'ready_for_reimbursement', 'purchase_confirmed')
    or (cur_status = 'approved' and cur_type = 'reimbursement_claim')
  ) then
    raise exception 'expense_not_reimbursable' using errcode = '22023',
      detail = format('current status: %s', cur_status);
  end if;

  -- Proof attachment, when supplied, must belong to this expense — stops a
  -- caller pinning an unrelated (or another workspace's) attachment id.
  if p_proof_attachment_id is not null and not exists (
    select 1 from turfmapp_expenses.attachments a
    where a.id = p_proof_attachment_id
      and a.expense_id = p_expense_id
      and a.deleted_at is null
  ) then
    raise exception 'proof_attachment_invalid' using errcode = '22023';
  end if;

  -- Audit record first, then the status transition — both in this txn.
  insert into turfmapp_expenses.payment_records (
    expense_id, paid_by_membership_id, payment_method,
    amount_minor, currency, paid_at, reference, proof_attachment_id
  ) values (
    p_expense_id, caller_member, p_payment_method,
    amt_minor, cur_code, p_paid_at, nullif(p_reference, ''), p_proof_attachment_id
  );

  update turfmapp_expenses.expenses
     set status = 'reimbursed'
   where id = p_expense_id;
end;
$$;

revoke all on function turfmapp_expenses.mark_expense_reimbursed(
  uuid, turfmapp_expenses.reimbursement_payment_method, timestamptz, text, uuid
) from public;
grant execute on function turfmapp_expenses.mark_expense_reimbursed(
  uuid, turfmapp_expenses.reimbursement_payment_method, timestamptz, text, uuid
) to authenticated;
