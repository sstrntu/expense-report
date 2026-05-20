-- Security hardening: remove the legacy grant_anon_access overreach from the
-- expense app's own objects. RLS gates rows but TRUNCATE bypasses RLS, so an
-- anon (public key) client could otherwise wipe these tables. The app only
-- uses the authenticated role.

revoke all privileges on table
  public.users,
  public.workspaces,
  public.workspace_memberships,
  public.workspace_invites,
  public.projects,
  public.project_memberships,
  public.categories,
  public.project_category_rules,
  public.expenses,
  public.expense_events,
  public.attachments,
  public.receipt_scans,
  public.receipt_scan_fields,
  public.payment_records,
  public.notifications,
  public.user_preferences
from anon;

revoke execute on function
  public.route_submitted_expense(),
  public.log_expense_transition(),
  public.receipts_object_workspace(text)
from anon;
