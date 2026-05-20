-- Server-side expense workflow: routing, audit events, and notifications.
--
-- The app only ever sets status = 'submitted' (or the terminal action
-- statuses). These triggers decide the real next state from the project's
-- routing_mode / approval_threshold, append an immutable audit row to
-- expense_events, and fan out notifications. Functions are SECURITY DEFINER
-- so the audit/notification writes are not blocked by RLS.

create or replace function public.route_submitted_expense()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  proj public.projects;
  is_new_submission boolean;
begin
  is_new_submission :=
    new.status = 'submitted'
    and (tg_op = 'INSERT' or old.status is distinct from 'submitted');

  if not is_new_submission then
    return new;
  end if;

  select * into proj from public.projects where id = new.project_id;
  if not found then
    return new;
  end if;

  if new.submitted_at is null then
    new.submitted_at := now();
  end if;

  -- Auto-clear when at/under the project approval threshold (threshold 0 = always review).
  if proj.approval_threshold_minor > 0 and new.amount_minor <= proj.approval_threshold_minor then
    if new.type = 'pre_approval' then
      new.status := 'approved';
    else
      new.status := 'ready_for_reimbursement';
    end if;
    return new;
  end if;

  new.status := case proj.routing_mode
    when 'finance_only'             then 'pending_finance_review'
    when 'auto_approve_then_finance' then 'pending_finance_review'
    when 'auto_reimburse'           then 'ready_for_reimbursement'
    else 'pending_manager_approval'
  end;

  return new;
end;
$$;

drop trigger if exists expenses_route_submitted on public.expenses;
create trigger expenses_route_submitted
before insert or update of status on public.expenses
for each row execute function public.route_submitted_expense();

create or replace function public.log_expense_transition()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor uuid;
  event_name text;
  notify_role public.workspace_role;
  member record;
begin
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  actor := coalesce(public.current_membership_id(new.workspace_id), new.submitted_by_membership_id);

  event_name := case new.status
    when 'submitted'                then 'submitted'
    when 'pending_manager_approval' then 'submitted'
    when 'pending_finance_review'   then 'submitted'
    when 'approved'                 then 'approved'
    when 'rejected'                 then 'rejected'
    when 'cancelled'                then 'cancelled'
    when 'purchase_confirmed'       then 'purchase_confirmed'
    when 'ready_for_reimbursement'  then 'approved'
    when 'reimbursed'               then 'reimbursement_sent'
    when 'archived'                 then 'archived'
    else 'status_changed'
  end;

  insert into public.expense_events (expense_id, actor_membership_id, event_type, from_status, to_status, note)
  values (
    new.id,
    actor,
    event_name,
    case when tg_op = 'UPDATE' then old.status else null end,
    new.status,
    null
  );

  -- Notify the submitter on terminal/decision states.
  if new.status in ('approved', 'rejected', 'reimbursed', 'ready_for_reimbursement') then
    insert into public.notifications (workspace_id, recipient_membership_id, actor_membership_id, expense_id, project_id, kind, title, body)
    values (
      new.workspace_id,
      new.submitted_by_membership_id,
      actor,
      new.id,
      new.project_id,
      case new.status
        when 'approved' then 'expense_approved'::public.notification_kind
        when 'rejected' then 'expense_rejected'::public.notification_kind
        else 'reimbursement_sent'::public.notification_kind
      end,
      'Expense ' || replace(new.status::text, '_', ' '),
      new.merchant || ' · ' || to_char(new.amount_minor / 100.0, 'FM999990.00')
    );
  end if;

  -- Notify the queue owners when an expense lands in a review queue.
  if new.status in ('pending_manager_approval', 'pending_finance_review') then
    notify_role := case new.status
      when 'pending_manager_approval' then 'manager'
      else 'finance'
    end;
    for member in
      select wm.id
      from public.workspace_memberships wm
      where wm.workspace_id = new.workspace_id
        and wm.status = 'active'
        and wm.role in (notify_role, 'admin')
    loop
      insert into public.notifications (workspace_id, recipient_membership_id, actor_membership_id, expense_id, project_id, kind, title, body)
      values (
        new.workspace_id,
        member.id,
        actor,
        new.id,
        new.project_id,
        'expense_submitted'::public.notification_kind,
        'Expense awaiting review',
        new.merchant || ' · ' || to_char(new.amount_minor / 100.0, 'FM999990.00')
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists expenses_log_transition on public.expenses;
create trigger expenses_log_transition
after insert or update of status on public.expenses
for each row execute function public.log_expense_transition();
