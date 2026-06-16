-- Submitting to a project requires participation, not mere visibility.
--
-- reviewer_project_visibility (applied 2026-06-15) widened can_access_project
-- so workspace managers/finance can SEE every project and review expenses with
-- full project context. But expense INSERT keyed off that same function, so the
-- read widening leaked into write access: managers/finance could SUBMIT to
-- private/team projects they aren't members of.
--
-- Split the concern. A dedicated can_submit_to_project encodes the
-- participation rule and now backs the INSERT policy; can_access_project keeps
-- the broader read visibility. The predicate mirrors the client's
-- canCurrentUserSubmit exactly:
--   * workspace admin                                          -> submit anywhere
--   * project member with a submit-capable role
--     (submitter/approver/finance/project_admin; NOT viewer)   -> submit there
--   * non-member on a workspace-visible project                -> submit there
--   * everyone else — incl. manager/finance holding only
--     read visibility, and explicit project viewers            -> may NOT submit
--
-- Net change vs. the pre-widening baseline: identical, except an explicit
-- project 'viewer' can no longer submit (the old can_access_project admitted
-- any member regardless of role). The client already blocked viewers, so this
-- only tightens the server to match — no app behavior changes.

create or replace function turfmapp_expenses.can_submit_to_project(project_id uuid)
returns boolean
language sql
security definer
set search_path to 'turfmapp_expenses, public'
stable
as $$
  select exists (
    select 1
    from turfmapp_expenses.projects p
    left join turfmapp_expenses.project_memberships pm
      on pm.project_id = p.id
      and pm.workspace_membership_id = turfmapp_expenses.current_membership_id(p.workspace_id)
    where p.id = can_submit_to_project.project_id
      and turfmapp_expenses.is_workspace_member(p.workspace_id)
      and (
        turfmapp_expenses.has_workspace_role(p.workspace_id, array['admin'::turfmapp_expenses.workspace_role])
        or (pm.id is not null and pm.role in (
              'submitter'::turfmapp_expenses.project_role,
              'approver'::turfmapp_expenses.project_role,
              'finance'::turfmapp_expenses.project_role,
              'project_admin'::turfmapp_expenses.project_role))
        or (pm.id is null and p.visibility = 'workspace')
      )
  );
$$;

drop policy if exists "members can create own expenses" on turfmapp_expenses.expenses;

create policy "members can create own expenses" on turfmapp_expenses.expenses
for insert with check (
  turfmapp_expenses.current_membership_id(workspace_id) = submitted_by_membership_id
  and turfmapp_expenses.can_submit_to_project(project_id)
);
