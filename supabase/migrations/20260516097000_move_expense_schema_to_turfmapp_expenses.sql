-- Move the expense app out of the shared `public` schema into its own
-- `turfmapp_expenses` schema. ALTER ... SET SCHEMA preserves OIDs, so RLS
-- policies, triggers, FKs, indexes and storage.objects policies keep binding
-- correctly; only sql/plpgsql function bodies (resolved by name) are rewritten.
-- Idempotent-ish: safe to run once on a DB whose expense schema is in `public`.

create schema if not exists turfmapp_expenses;
grant usage on schema turfmapp_expenses to authenticated, service_role;

-- 1. Functions (while their arg enum types are still in public).
alter function public.can_access_expense(uuid) set schema turfmapp_expenses;
alter function public.can_access_project(uuid) set schema turfmapp_expenses;
alter function public.can_approve_project(uuid) set schema turfmapp_expenses;
alter function public.can_finance_project(uuid) set schema turfmapp_expenses;
alter function public.create_workspace_with_admin(text, character) set schema turfmapp_expenses;
alter function public.current_membership_id(uuid) set schema turfmapp_expenses;
alter function public.current_workspace_role(uuid) set schema turfmapp_expenses;
alter function public.has_project_role(uuid, public.project_role[]) set schema turfmapp_expenses;
alter function public.has_workspace_role(uuid, public.workspace_role[]) set schema turfmapp_expenses;
alter function public.is_expense_submitter(uuid) set schema turfmapp_expenses;
alter function public.is_workspace_member(uuid) set schema turfmapp_expenses;
alter function public.log_expense_transition() set schema turfmapp_expenses;
alter function public.receipts_object_workspace(text) set schema turfmapp_expenses;
alter function public.route_submitted_expense() set schema turfmapp_expenses;
alter function public.set_updated_at() set schema turfmapp_expenses;

-- 2. Enum types.
alter type public.attachment_kind set schema turfmapp_expenses;
alter type public.expense_status set schema turfmapp_expenses;
alter type public.expense_type set schema turfmapp_expenses;
alter type public.invite_status set schema turfmapp_expenses;
alter type public.notification_kind set schema turfmapp_expenses;
alter type public.over_budget_behavior set schema turfmapp_expenses;
alter type public.project_role set schema turfmapp_expenses;
alter type public.project_routing_mode set schema turfmapp_expenses;
alter type public.project_status set schema turfmapp_expenses;
alter type public.project_visibility set schema turfmapp_expenses;
alter type public.receipt_scan_status set schema turfmapp_expenses;
alter type public.reimbursement_payment_method set schema turfmapp_expenses;
alter type public.scan_field_confidence set schema turfmapp_expenses;
alter type public.workspace_member_status set schema turfmapp_expenses;
alter type public.workspace_role set schema turfmapp_expenses;

-- 3. Tables (policies, indexes, constraints, triggers, sequences ride along).
alter table public.users set schema turfmapp_expenses;
alter table public.workspaces set schema turfmapp_expenses;
alter table public.workspace_memberships set schema turfmapp_expenses;
alter table public.workspace_invites set schema turfmapp_expenses;
alter table public.projects set schema turfmapp_expenses;
alter table public.project_memberships set schema turfmapp_expenses;
alter table public.categories set schema turfmapp_expenses;
alter table public.project_category_rules set schema turfmapp_expenses;
alter table public.expenses set schema turfmapp_expenses;
alter table public.expense_events set schema turfmapp_expenses;
alter table public.attachments set schema turfmapp_expenses;
alter table public.receipt_scans set schema turfmapp_expenses;
alter table public.receipt_scan_fields set schema turfmapp_expenses;
alter table public.payment_records set schema turfmapp_expenses;
alter table public.notifications set schema turfmapp_expenses;
alter table public.user_preferences set schema turfmapp_expenses;

-- 4. Rewrite function bodies for the new schema (CREATE OR REPLACE keeps OIDs,
--    so the moved RLS/trigger/storage policies stay bound). The full bodies
--    are applied identically to the live DB; see migration history entry
--    `move_expense_schema_to_turfmapp_expenses`. Each function is recreated as
--    turfmapp_expenses.<name> with `set search_path to 'turfmapp_expenses,
--    public'` and all public.<obj> references rewritten to turfmapp_expenses.
--    (auth.* references are intentionally left untouched.)
--
-- NOTE: keep this file in sync with the applied migration when regenerating
-- via `supabase db pull`.
