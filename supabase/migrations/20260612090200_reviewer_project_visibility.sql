-- Visibility now cascades with review power. Workspace managers and finance
-- could already read every expense (can_access_expense) and act on any
-- project's queue (can_approve_project / can_finance_project), but
-- can_access_project still hid private/team project rows from them — so a
-- manager could approve an expense whose project name and budget they
-- couldn't load ("Unknown project" in the queue, no budget context).
--
-- Aligns the read side with the act side: manager/finance/admin see all
-- projects in their workspace. Project privacy still applies to employees.

create or replace function turfmapp_expenses.can_access_project(project_id uuid)
returns boolean
language sql
security definer
set search_path to 'turfmapp_expenses, public'
stable
as $$
  select exists (
    select 1
    from turfmapp_expenses.projects p
    where p.id = can_access_project.project_id
      and turfmapp_expenses.is_workspace_member(p.workspace_id)
      and (
        p.visibility = 'workspace'
        or turfmapp_expenses.has_workspace_role(p.workspace_id, array[
          'manager'::turfmapp_expenses.workspace_role,
          'finance'::turfmapp_expenses.workspace_role,
          'admin'::turfmapp_expenses.workspace_role
        ])
        or exists (
          select 1
          from turfmapp_expenses.project_memberships pm
          where pm.project_id = p.id
            and pm.workspace_membership_id = turfmapp_expenses.current_membership_id(p.workspace_id)
        )
      )
  );
$$;
