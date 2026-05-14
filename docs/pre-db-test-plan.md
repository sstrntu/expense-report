# Pre-Database Test Plan

Use this matrix when adding the database adapter behind the repository protocols.

## Workflow Transitions

- Draft pre-approval submits to manager approval when over threshold.
- Draft pre-approval auto-approves when under threshold and routing allows it.
- Draft reimbursement routes to finance or manager based on project policy.
- Rejected expenses can be resubmitted and return to the correct route.
- Submitted, pending, and approved expenses can be cancelled by the submitter.
- Purchase confirmation is only valid for approved pre-approvals.
- Reimbursement is only valid from finance-ready statuses.

## Permission Matrix

- Employee can create drafts, submit expenses, confirm approved purchases, cancel own pending expenses, and resubmit rejected expenses.
- Manager/admin can approve or reject manager queue items.
- Finance/admin can reimburse finance queue items.
- Viewer project role cannot submit expenses.
- Last workspace admin cannot be demoted or removed.

## Project Policy

- Archived projects are hidden from selectable project lists.
- Existing expenses retain their project id after project archival.
- Disallowed categories are blocked at draft creation and submission.
- Over-budget behavior warns, escalates, or blocks based on policy.
- Budget period, receipt threshold, routing mode, and approval threshold persist as project fields.

## Receipt Scanning

- Uploaded receipt attachment is created before scan result.
- Uploading, processing, needs-review, confirmed, and failed scan states render.
- Manual edits mark fields as user-confirmed/manual confidence.
- Duplicate receipt warnings appear before submission.
- Purchase receipts and reimbursement proofs are stored as separate attachment kinds.

## Workspace Scope

- Workspace switch reloads projects, members, invites, expenses, and events for that workspace.
- Cross-workspace project selection is rejected.
- Invites expire after `expiresAt` and cancelled invites no longer appear as pending.

## Reports And Notifications

- Report filters apply workspace, project, member, status, category, and date range.
- Export permission requires manager, finance, or admin workspace roles.
- Notification deep links resolve to expense, project, or invite routes.
- Mark-read and notification preference changes persist per membership.
