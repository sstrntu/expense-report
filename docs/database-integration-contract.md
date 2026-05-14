# Database Integration Contract

This document defines the data contract the app should target before a database is introduced. It is intentionally backend-agnostic.

## Domain Entities

### users

Represents a person who can sign in.

Fields:

- `id`
- `email`
- `email_verified_at`
- `display_name`
- `avatar_url`
- `created_at`
- `updated_at`

Notes:

- App-level role does not belong on the user. Roles are workspace/project scoped.

### workspaces

Represents a company/organization.

Fields:

- `id`
- `name`
- `slug`
- `abbr`
- `brand_color`
- `default_currency`
- `created_by_user_id`
- `created_at`
- `updated_at`
- `archived_at`

### workspace_memberships

Connects users to workspaces.

Fields:

- `id`
- `workspace_id`
- `user_id`
- `role`: employee, manager, finance, admin
- `status`: active, suspended, removed
- `joined_at`
- `removed_at`

Rules:

- A user can have different roles in different workspaces.
- At least one active admin must remain per workspace.

### workspace_invites

Tracks pending invites.

Fields:

- `id`
- `workspace_id`
- `email`
- `role`
- `invited_by_user_id`
- `status`: pending, accepted, expired, cancelled
- `expires_at`
- `accepted_by_user_id`
- `created_at`
- `updated_at`

### projects

Controls project budget, policy, routing, and access.

Fields:

- `id`
- `workspace_id`
- `name`
- `description`
- `owner_membership_id`
- `status`: active, archived
- `visibility`: private, team, workspace
- `budget_amount_minor`
- `budget_currency`
- `budget_period`
- `approval_threshold_minor`
- `receipt_required_threshold_minor`
- `routing_mode`
- `over_budget_behavior`
- `created_at`
- `updated_at`
- `archived_at`

### project_memberships

Controls access within a project.

Fields:

- `id`
- `project_id`
- `workspace_membership_id`
- `role`: viewer, submitter, approver, finance, project_admin
- `created_at`
- `updated_at`

### categories

Defines allowed expense categories per workspace, optionally overridden per project.

Fields:

- `id`
- `workspace_id`
- `name`
- `icon`
- `is_active`
- `created_at`

### project_category_rules

Controls category availability and category-specific policy.

Fields:

- `id`
- `project_id`
- `category_id`
- `is_allowed`
- `requires_receipt`
- `approval_threshold_minor`

### expenses

Represents both pre-approval requests and reimbursement claims.

Fields:

- `id`
- `workspace_id`
- `project_id`
- `submitted_by_membership_id`
- `type`: pre_approval, reimbursement_claim
- `status`
- `merchant`
- `amount_minor`
- `currency`
- `tax_amount_minor`
- `category_id`
- `business_purpose`
- `purchase_date`
- `needed_by_date`
- `approved_amount_minor`
- `is_archived`
- `created_at`
- `submitted_at`
- `updated_at`
- `deleted_at`

Rules:

- Pre-approval requests can have estimated amount before purchase and final amount after purchase.
- Reimbursement claims require purchase date and final amount.
- Soft delete is preferred for auditability.

### expense_events

Append-only audit trail for expense status and collaboration.

Fields:

- `id`
- `expense_id`
- `actor_membership_id`
- `event_type`
- `from_status`
- `to_status`
- `note`
- `created_at`

Event types:

- `created`
- `submitted`
- `scan_started`
- `scan_completed`
- `scan_failed`
- `approved`
- `rejected`
- `resubmitted`
- `purchase_confirmed`
- `finance_reviewed`
- `reimbursement_sent`
- `archived`
- `unarchived`
- `deleted`
- `commented`

### attachments

Stores receipt and proof metadata. File storage itself can be S3, Supabase Storage, Cloudflare R2, or another storage service.

Fields:

- `id`
- `workspace_id`
- `expense_id`
- `uploaded_by_membership_id`
- `kind`: submitted_receipt, purchase_receipt, reimbursement_proof, supporting_document
- `file_name`
- `content_type`
- `file_size_bytes`
- `storage_key`
- `public_url`
- `sha256`
- `created_at`
- `deleted_at`

### receipt_scans

Tracks AI processing of receipt attachments.

Fields:

- `id`
- `attachment_id`
- `expense_id`
- `status`: not_started, uploading, processing, needs_review, confirmed, failed
- `provider`
- `raw_result_json`
- `error_message`
- `created_at`
- `updated_at`

### receipt_scan_fields

Stores extracted fields and confidence.

Fields:

- `id`
- `receipt_scan_id`
- `field_name`
- `extracted_value`
- `normalized_value`
- `confidence`: high, medium, low, manual
- `confirmed_by_user`
- `updated_at`

### payment_records

Tracks reimbursement action.

Fields:

- `id`
- `expense_id`
- `paid_by_membership_id`
- `payment_method`: bank_transfer, qr_code, cash, card, cheque, other
- `amount_minor`
- `currency`
- `paid_at`
- `reference`
- `proof_attachment_id`
- `created_at`

### notifications

In-app notifications. Email/push delivery can use the same event source later.

Fields:

- `id`
- `workspace_id`
- `recipient_membership_id`
- `actor_membership_id`
- `expense_id`
- `project_id`
- `kind`
- `title`
- `body`
- `read_at`
- `created_at`

### user_preferences

Local preferences can start on-device, but server-backed preferences are useful for multi-device behavior.

Fields:

- `id`
- `user_id`
- `last_workspace_id`
- `default_currency`
- `compact_lists`
- `notification_settings_json`
- `created_at`
- `updated_at`

## API/Repository Boundaries

Before database integration, the SwiftUI app should call repositories instead of mutating arrays directly.

Recommended interfaces:

- `AuthRepository`
- `WorkspaceRepository`
- `ProjectRepository`
- `ExpenseRepository`
- `AttachmentRepository`
- `ReceiptScanRepository`
- `NotificationRepository`
- `ReportRepository`

Each repository should expose async operations and return domain models independent of SwiftUI presentation.

Examples:

```swift
protocol ExpenseRepository {
    func listExpenses(workspaceId: String, filters: ExpenseFilters) async throws -> [ExpenseRecord]
    func createDraft(_ input: ExpenseDraftInput) async throws -> ExpenseRecord
    func submitExpense(_ id: String) async throws -> ExpenseRecord
    func approveExpense(_ id: String, note: String?) async throws -> ExpenseRecord
    func rejectExpense(_ id: String, reason: String) async throws -> ExpenseRecord
    func confirmPurchase(_ id: String, input: PurchaseConfirmationInput) async throws -> ExpenseRecord
    func markReimbursed(_ id: String, input: ReimbursementInput) async throws -> ExpenseRecord
}
```

## Client Model Cleanup Before DB

The current UI models should be adapted before real persistence:

- Use IDs for relationships, not display names.
- Store money as integer minor units, not `Double`.
- Store dates as `Date` or ISO strings, not display text.
- Keep SwiftUI `Color` out of persisted models.
- Store attachments as attachment records, not file name strings.
- Separate user role from workspace/project role.
- Separate server status from UI label.

## Initial Query Needs

The first database/API integration should support:

- Workspaces for current user.
- Current workspace membership and role.
- Projects visible to current member.
- Project policy and project members.
- Expense list by workspace/status/project/date.
- Manager review queue.
- Finance review queue.
- Expense detail with events, comments, attachments, scan results, and payment records.
- Notification list and mark-read.
- Reports by workspace/project/date/status/member.

## Security Rules To Preserve

- Every query must be workspace-scoped.
- Project private visibility requires project membership.
- Employee can only view own expenses unless project/workspace policy grants broader access.
- Approver cannot approve without project or workspace permission.
- Finance cannot mark reimbursed without finance permission.
- Last workspace admin cannot be removed or downgraded.
- Attachments must only be readable by authorized workspace/project members.
