create extension if not exists pgcrypto;

create type public.workspace_role as enum ('employee', 'manager', 'finance', 'admin');
create type public.workspace_member_status as enum ('active', 'suspended', 'removed');
create type public.invite_status as enum ('pending', 'accepted', 'expired', 'cancelled');
create type public.project_status as enum ('active', 'archived');
create type public.project_visibility as enum ('private', 'team', 'workspace');
create type public.project_role as enum ('viewer', 'submitter', 'approver', 'finance', 'project_admin');
create type public.project_routing_mode as enum ('manager_only', 'finance_only', 'manager_then_finance', 'auto_approve_then_finance', 'auto_reimburse');
create type public.over_budget_behavior as enum ('warn', 'escalate', 'block');
create type public.expense_type as enum ('pre_approval', 'reimbursement_claim');
create type public.expense_status as enum (
  'draft',
  'submitted',
  'scan_processing',
  'scan_failed',
  'pending_manager_approval',
  'pending_finance_review',
  'approved',
  'rejected',
  'purchase_confirmed',
  'ready_for_reimbursement',
  'reimbursed',
  'cancelled',
  'archived'
);
create type public.attachment_kind as enum ('submitted_receipt', 'purchase_receipt', 'reimbursement_proof', 'supporting_document');
create type public.receipt_scan_status as enum ('not_started', 'uploading', 'processing', 'needs_review', 'confirmed', 'failed');
create type public.scan_field_confidence as enum ('high', 'medium', 'low', 'manual');
create type public.reimbursement_payment_method as enum ('bank_transfer', 'qr_code', 'cash', 'card', 'cheque', 'other');
create type public.notification_kind as enum (
  'expense_submitted',
  'expense_approved',
  'expense_rejected',
  'purchase_confirmed',
  'reimbursement_sent',
  'workspace_invite',
  'project_budget_warning'
);

create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  email_verified_at timestamptz,
  display_name text not null,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, email_verified_at, display_name, avatar_url)
  values (
    new.id,
    lower(coalesce(new.email, '')),
    new.email_confirmed_at,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, ''), '@', 1), 'New user'),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do update set
    email = excluded.email,
    email_verified_at = excluded.email_verified_at,
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();

  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  abbr text not null,
  brand_color text not null default '878E9F',
  default_currency char(3) not null default 'USD',
  created_by_user_id uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint workspaces_brand_color_hex check (brand_color ~ '^[0-9A-Fa-f]{6}$'),
  constraint workspaces_abbr_not_empty check (length(trim(abbr)) between 1 and 8),
  constraint workspaces_currency_upper check (default_currency = upper(default_currency))
);

create table public.workspace_memberships (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role public.workspace_role not null,
  status public.workspace_member_status not null default 'active',
  joined_at timestamptz not null default now(),
  removed_at timestamptz,
  constraint workspace_memberships_removed_at check (
    (status = 'removed' and removed_at is not null) or (status <> 'removed')
  )
);

create unique index workspace_memberships_user_workspace_uidx
  on public.workspace_memberships(workspace_id, user_id);

create unique index workspace_memberships_one_active_admin_uidx
  on public.workspace_memberships(workspace_id, user_id)
  where status = 'active' and role = 'admin';

create table public.workspace_invites (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  email text not null,
  role public.workspace_role not null,
  invited_by_user_id uuid not null references public.users(id),
  status public.invite_status not null default 'pending',
  expires_at timestamptz not null,
  accepted_by_user_id uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint workspace_invites_email_lower check (email = lower(email)),
  constraint workspace_invites_expiry_future check (expires_at > created_at)
);

create unique index workspace_invites_pending_email_uidx
  on public.workspace_invites(workspace_id, email)
  where status = 'pending';

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  description text not null default '',
  owner_membership_id uuid not null references public.workspace_memberships(id),
  status public.project_status not null default 'active',
  visibility public.project_visibility not null default 'workspace',
  budget_amount_minor integer not null default 0,
  budget_currency char(3) not null default 'USD',
  budget_period text not null default 'monthly',
  approval_threshold_minor integer not null default 0,
  receipt_required_threshold_minor integer not null default 0,
  routing_mode public.project_routing_mode not null default 'manager_then_finance',
  over_budget_behavior public.over_budget_behavior not null default 'warn',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint projects_budget_nonnegative check (budget_amount_minor >= 0),
  constraint projects_thresholds_nonnegative check (approval_threshold_minor >= 0 and receipt_required_threshold_minor >= 0),
  constraint projects_currency_upper check (budget_currency = upper(budget_currency)),
  constraint projects_archived_at check ((status = 'archived' and archived_at is not null) or (status = 'active'))
);

create index projects_workspace_status_idx on public.projects(workspace_id, status);
create index projects_owner_membership_idx on public.projects(owner_membership_id);

create table public.project_memberships (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  workspace_membership_id uuid not null references public.workspace_memberships(id) on delete cascade,
  role public.project_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index project_memberships_project_member_uidx
  on public.project_memberships(project_id, workspace_membership_id);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null,
  icon text not null default 'tag',
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create unique index categories_workspace_name_uidx
  on public.categories(workspace_id, lower(name));

create table public.project_category_rules (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  is_allowed boolean not null default true,
  requires_receipt boolean not null default true,
  approval_threshold_minor integer,
  constraint project_category_rules_threshold_nonnegative check (approval_threshold_minor is null or approval_threshold_minor >= 0)
);

create unique index project_category_rules_project_category_uidx
  on public.project_category_rules(project_id, category_id);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  project_id uuid not null references public.projects(id),
  submitted_by_membership_id uuid not null references public.workspace_memberships(id),
  type public.expense_type not null,
  status public.expense_status not null default 'draft',
  merchant text not null,
  amount_minor integer not null,
  currency char(3) not null default 'USD',
  tax_amount_minor integer,
  category_id uuid not null references public.categories(id),
  business_purpose text not null,
  purchase_date date,
  needed_by_date date,
  approved_amount_minor integer,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  submitted_at timestamptz,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint expenses_amount_nonnegative check (amount_minor >= 0),
  constraint expenses_optional_amounts_nonnegative check (
    (tax_amount_minor is null or tax_amount_minor >= 0)
    and (approved_amount_minor is null or approved_amount_minor >= 0)
  ),
  constraint expenses_currency_upper check (currency = upper(currency)),
  constraint reimbursement_claim_purchase_date check (type <> 'reimbursement_claim' or purchase_date is not null),
  constraint expenses_archived_status_sync check ((status = 'archived') = is_archived)
);

create index expenses_workspace_status_idx on public.expenses(workspace_id, status, created_at desc);
create index expenses_project_idx on public.expenses(project_id, created_at desc);
create index expenses_submitter_idx on public.expenses(submitted_by_membership_id, created_at desc);
create index expenses_category_idx on public.expenses(category_id);

create table public.expense_events (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  actor_membership_id uuid not null references public.workspace_memberships(id),
  event_type text not null,
  from_status public.expense_status,
  to_status public.expense_status,
  note text,
  created_at timestamptz not null default now()
);

create index expense_events_expense_created_idx on public.expense_events(expense_id, created_at desc);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  uploaded_by_membership_id uuid not null references public.workspace_memberships(id),
  kind public.attachment_kind not null,
  file_name text not null,
  content_type text not null,
  file_size_bytes integer not null,
  storage_key text not null unique,
  public_url text,
  sha256 text,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint attachments_file_size_positive check (file_size_bytes > 0),
  constraint attachments_sha256_hex check (sha256 is null or sha256 ~ '^[0-9A-Fa-f]{64}$')
);

create index attachments_expense_idx on public.attachments(expense_id, created_at desc);
create index attachments_workspace_idx on public.attachments(workspace_id, created_at desc);

create table public.receipt_scans (
  id uuid primary key default gen_random_uuid(),
  attachment_id uuid not null references public.attachments(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  status public.receipt_scan_status not null default 'not_started',
  provider text not null default 'openai',
  raw_result_json jsonb,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index receipt_scans_expense_idx on public.receipt_scans(expense_id, created_at desc);
create index receipt_scans_attachment_idx on public.receipt_scans(attachment_id);

create table public.receipt_scan_fields (
  id uuid primary key default gen_random_uuid(),
  receipt_scan_id uuid not null references public.receipt_scans(id) on delete cascade,
  field_name text not null,
  extracted_value text not null,
  normalized_value text,
  confidence public.scan_field_confidence not null default 'low',
  confirmed_by_user boolean not null default false,
  updated_at timestamptz not null default now()
);

create unique index receipt_scan_fields_scan_field_uidx
  on public.receipt_scan_fields(receipt_scan_id, field_name);

create table public.payment_records (
  id uuid primary key default gen_random_uuid(),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  paid_by_membership_id uuid not null references public.workspace_memberships(id),
  payment_method public.reimbursement_payment_method not null,
  amount_minor integer not null,
  currency char(3) not null default 'USD',
  paid_at timestamptz not null,
  reference text,
  proof_attachment_id uuid references public.attachments(id),
  created_at timestamptz not null default now(),
  constraint payment_records_amount_positive check (amount_minor > 0),
  constraint payment_records_currency_upper check (currency = upper(currency))
);

create index payment_records_expense_idx on public.payment_records(expense_id, created_at desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  recipient_membership_id uuid not null references public.workspace_memberships(id) on delete cascade,
  actor_membership_id uuid references public.workspace_memberships(id),
  expense_id uuid references public.expenses(id) on delete cascade,
  project_id uuid references public.projects(id) on delete cascade,
  kind public.notification_kind not null,
  title text not null,
  body text not null,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_recipient_created_idx on public.notifications(recipient_membership_id, created_at desc);
create index notifications_workspace_created_idx on public.notifications(workspace_id, created_at desc);

create table public.user_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  last_workspace_id uuid references public.workspaces(id),
  default_currency char(3) not null default 'USD',
  compact_lists boolean not null default false,
  notification_settings_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_preferences_currency_upper check (default_currency = upper(default_currency))
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_users_updated_at before update on public.users
for each row execute function public.set_updated_at();

create trigger set_workspaces_updated_at before update on public.workspaces
for each row execute function public.set_updated_at();

create trigger set_workspace_invites_updated_at before update on public.workspace_invites
for each row execute function public.set_updated_at();

create trigger set_projects_updated_at before update on public.projects
for each row execute function public.set_updated_at();

create trigger set_project_memberships_updated_at before update on public.project_memberships
for each row execute function public.set_updated_at();

create trigger set_expenses_updated_at before update on public.expenses
for each row execute function public.set_updated_at();

create trigger set_receipt_scans_updated_at before update on public.receipt_scans
for each row execute function public.set_updated_at();

create trigger set_receipt_scan_fields_updated_at before update on public.receipt_scan_fields
for each row execute function public.set_updated_at();

create trigger set_user_preferences_updated_at before update on public.user_preferences
for each row execute function public.set_updated_at();

create or replace function public.current_membership_id(workspace_id uuid)
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select wm.id
  from public.workspace_memberships wm
  where wm.workspace_id = current_membership_id.workspace_id
    and wm.user_id = auth.uid()
    and wm.status = 'active'
  limit 1;
$$;

create or replace function public.current_workspace_role(workspace_id uuid)
returns public.workspace_role
language sql
security definer
set search_path = public
stable
as $$
  select wm.role
  from public.workspace_memberships wm
  where wm.workspace_id = current_workspace_role.workspace_id
    and wm.user_id = auth.uid()
    and wm.status = 'active'
  limit 1;
$$;

create or replace function public.is_workspace_member(workspace_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.workspace_memberships wm
    where wm.workspace_id = is_workspace_member.workspace_id
      and wm.user_id = auth.uid()
      and wm.status = 'active'
  );
$$;

create or replace function public.has_workspace_role(workspace_id uuid, allowed_roles public.workspace_role[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(public.current_workspace_role(workspace_id) = any(allowed_roles), false);
$$;

create or replace function public.can_access_project(project_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.projects p
    where p.id = can_access_project.project_id
      and public.is_workspace_member(p.workspace_id)
      and (
        p.visibility = 'workspace'
        or public.has_workspace_role(p.workspace_id, array['admin'::public.workspace_role])
        or exists (
          select 1
          from public.project_memberships pm
          where pm.project_id = p.id
            and pm.workspace_membership_id = public.current_membership_id(p.workspace_id)
        )
      )
  );
$$;

create or replace function public.can_approve_project(project_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.projects p
    left join public.project_memberships pm
      on pm.project_id = p.id
      and pm.workspace_membership_id = public.current_membership_id(p.workspace_id)
    where p.id = can_approve_project.project_id
      and (
        public.has_workspace_role(p.workspace_id, array['manager'::public.workspace_role, 'admin'::public.workspace_role])
        or pm.role in ('approver', 'project_admin')
      )
  );
$$;

create or replace function public.has_project_role(project_id uuid, allowed_roles public.project_role[])
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.projects p
    join public.project_memberships pm on pm.project_id = p.id
    where p.id = has_project_role.project_id
      and pm.workspace_membership_id = public.current_membership_id(p.workspace_id)
      and pm.role = any(allowed_roles)
  );
$$;

create or replace function public.can_finance_project(project_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.projects p
    left join public.project_memberships pm
      on pm.project_id = p.id
      and pm.workspace_membership_id = public.current_membership_id(p.workspace_id)
    where p.id = can_finance_project.project_id
      and (
        public.has_workspace_role(p.workspace_id, array['finance'::public.workspace_role, 'admin'::public.workspace_role])
        or pm.role in ('finance', 'project_admin')
      )
  );
$$;

create or replace function public.is_expense_submitter(expense_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.expenses e
    join public.workspace_memberships wm on wm.id = e.submitted_by_membership_id
    where e.id = is_expense_submitter.expense_id
      and wm.user_id = auth.uid()
      and wm.status = 'active'
  );
$$;

create or replace function public.can_access_expense(expense_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.expenses e
    where e.id = can_access_expense.expense_id
      and e.deleted_at is null
      and (
        public.is_expense_submitter(e.id)
        or public.can_access_project(e.project_id)
        or public.has_workspace_role(e.workspace_id, array['manager'::public.workspace_role, 'finance'::public.workspace_role, 'admin'::public.workspace_role])
      )
  );
$$;

alter table public.users enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_memberships enable row level security;
alter table public.workspace_invites enable row level security;
alter table public.projects enable row level security;
alter table public.project_memberships enable row level security;
alter table public.categories enable row level security;
alter table public.project_category_rules enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_events enable row level security;
alter table public.attachments enable row level security;
alter table public.receipt_scans enable row level security;
alter table public.receipt_scan_fields enable row level security;
alter table public.payment_records enable row level security;
alter table public.notifications enable row level security;
alter table public.user_preferences enable row level security;

create policy "users can read own profile" on public.users
for select using (id = auth.uid());

create policy "users can update own profile" on public.users
for update using (id = auth.uid()) with check (id = auth.uid());

create policy "users can insert own profile" on public.users
for insert with check (id = auth.uid());

create policy "members can read workspaces" on public.workspaces
for select using (public.is_workspace_member(id));

create policy "authenticated users can create workspaces" on public.workspaces
for insert with check (created_by_user_id = auth.uid());

create policy "admins can update workspaces" on public.workspaces
for update using (public.has_workspace_role(id, array['admin'::public.workspace_role]))
with check (public.has_workspace_role(id, array['admin'::public.workspace_role]));

create policy "members can read memberships" on public.workspace_memberships
for select using (public.is_workspace_member(workspace_id));

create policy "admins can manage memberships" on public.workspace_memberships
for all using (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]))
with check (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]));

create policy "admins can manage invites" on public.workspace_invites
for all using (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]))
with check (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]));

create policy "members can read accessible projects" on public.projects
for select using (public.can_access_project(id));

create policy "admins can manage projects" on public.projects
for all using (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]))
with check (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]));

create policy "project admins can update projects" on public.projects
for update using (
  public.has_project_role(projects.id, array['project_admin'::public.project_role])
) with check (
  public.has_project_role(projects.id, array['project_admin'::public.project_role])
);

create policy "members can read project memberships" on public.project_memberships
for select using (public.can_access_project(project_id));

create policy "project admins can manage project memberships" on public.project_memberships
for all using (
  exists (
    select 1
    from public.projects p
    where p.id = project_memberships.project_id
      and (
        public.has_workspace_role(p.workspace_id, array['admin'::public.workspace_role])
        or public.has_project_role(p.id, array['project_admin'::public.project_role])
      )
  )
) with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_memberships.project_id
      and (
        public.has_workspace_role(p.workspace_id, array['admin'::public.workspace_role])
        or public.has_project_role(p.id, array['project_admin'::public.project_role])
      )
  )
);

create policy "members can read categories" on public.categories
for select using (public.is_workspace_member(workspace_id));

create policy "admins can manage categories" on public.categories
for all using (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]))
with check (public.has_workspace_role(workspace_id, array['admin'::public.workspace_role]));

create policy "members can read project category rules" on public.project_category_rules
for select using (public.can_access_project(project_id));

create policy "project admins can manage category rules" on public.project_category_rules
for all using (
  exists (
    select 1
    from public.projects p
    where p.id = project_category_rules.project_id
      and public.has_workspace_role(p.workspace_id, array['admin'::public.workspace_role])
  )
) with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_category_rules.project_id
      and public.has_workspace_role(p.workspace_id, array['admin'::public.workspace_role])
  )
);

create policy "members can read accessible expenses" on public.expenses
for select using (public.can_access_expense(id));

create policy "members can create own expenses" on public.expenses
for insert with check (
  public.current_membership_id(workspace_id) = submitted_by_membership_id
  and public.can_access_project(project_id)
);

create policy "submitters can update own draft expenses" on public.expenses
for update using (
  public.is_expense_submitter(id)
  and status in ('draft', 'rejected', 'approved')
) with check (
  public.is_expense_submitter(id)
);

create policy "approvers can update manager queue expenses" on public.expenses
for update using (
  status = 'pending_manager_approval'
  and public.can_approve_project(project_id)
) with check (public.can_approve_project(project_id));

create policy "finance can update finance queue expenses" on public.expenses
for update using (
  status in ('pending_finance_review', 'ready_for_reimbursement')
  and public.can_finance_project(project_id)
) with check (public.can_finance_project(project_id));

create policy "authorized users can read expense events" on public.expense_events
for select using (public.can_access_expense(expense_id));

create policy "authorized users can append expense events" on public.expense_events
for insert with check (
  public.can_access_expense(expense_id)
  and actor_membership_id = public.current_membership_id(
    (select e.workspace_id from public.expenses e where e.id = expense_events.expense_id)
  )
);

create policy "authorized users can read attachments" on public.attachments
for select using (public.can_access_expense(expense_id));

create policy "authorized users can upload attachments" on public.attachments
for insert with check (
  public.can_access_expense(expense_id)
  and uploaded_by_membership_id = public.current_membership_id(workspace_id)
);

create policy "uploaders and admins can soft delete attachments" on public.attachments
for update using (
  uploaded_by_membership_id = public.current_membership_id(workspace_id)
  or public.has_workspace_role(workspace_id, array['admin'::public.workspace_role])
) with check (
  uploaded_by_membership_id = public.current_membership_id(workspace_id)
  or public.has_workspace_role(workspace_id, array['admin'::public.workspace_role])
);

create policy "authorized users can read receipt scans" on public.receipt_scans
for select using (public.can_access_expense(expense_id));

create policy "authorized users can create receipt scans" on public.receipt_scans
for insert with check (public.can_access_expense(expense_id));

create policy "authorized users can update receipt scans" on public.receipt_scans
for update using (public.can_access_expense(expense_id))
with check (public.can_access_expense(expense_id));

create policy "authorized users can read receipt scan fields" on public.receipt_scan_fields
for select using (
  exists (
    select 1 from public.receipt_scans rs
    where rs.id = receipt_scan_fields.receipt_scan_id
      and public.can_access_expense(rs.expense_id)
  )
);

create policy "authorized users can manage receipt scan fields" on public.receipt_scan_fields
for all using (
  exists (
    select 1 from public.receipt_scans rs
    where rs.id = receipt_scan_fields.receipt_scan_id
      and public.can_access_expense(rs.expense_id)
  )
) with check (
  exists (
    select 1 from public.receipt_scans rs
    where rs.id = receipt_scan_fields.receipt_scan_id
      and public.can_access_expense(rs.expense_id)
  )
);

create policy "authorized users can read payment records" on public.payment_records
for select using (public.can_access_expense(expense_id));

create policy "finance can create payment records" on public.payment_records
for insert with check (
  public.can_finance_project((select e.project_id from public.expenses e where e.id = payment_records.expense_id))
  and paid_by_membership_id = public.current_membership_id(
    (select e.workspace_id from public.expenses e where e.id = payment_records.expense_id)
  )
);

create policy "members can read own notifications" on public.notifications
for select using (recipient_membership_id = public.current_membership_id(workspace_id));

create policy "members can mark own notifications read" on public.notifications
for update using (recipient_membership_id = public.current_membership_id(workspace_id))
with check (recipient_membership_id = public.current_membership_id(workspace_id));

create policy "members can create workspace notifications" on public.notifications
for insert with check (public.is_workspace_member(workspace_id));

create policy "users can read own preferences" on public.user_preferences
for select using (user_id = auth.uid());

create policy "users can manage own preferences" on public.user_preferences
for all using (user_id = auth.uid()) with check (user_id = auth.uid());
