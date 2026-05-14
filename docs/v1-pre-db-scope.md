# V1 Pre-Database Product Scope

This document defines the feature behavior that should be settled before connecting a database. It keeps the current SwiftUI prototype aligned with the real app scope.

## Product Position

Turfmapp Expenses is a multi-workspace expense operations app. V1 supports:

- Pre-approval requests before employees make a purchase.
- After-the-fact reimbursement claims for purchases already made.
- Manager and finance review/reimbursement paths.
- Projects as permission, budget, policy, and access-control containers.
- AI receipt scanning as a required v1 feature.
- Users who can belong to multiple workspaces with different roles per workspace.

## 1. Expense Types

The submit flow must start by choosing an expense type.

### Pre-Approval Request

Use when the employee needs approval before buying.

Required fields:

- Workspace
- Project
- Merchant or planned vendor
- Estimated amount
- Currency
- Category
- Business purpose
- Needed by date, optional for v1
- Optional supporting attachment

Expected lifecycle:

1. Draft
2. Submitted
3. Pending manager approval, unless project policy auto-approves
4. Approved or rejected
5. Purchase confirmed by employee
6. Pending finance review or ready for reimbursement
7. Reimbursed

Rules:

- Employee should not see purchase confirmation until the request is approved or auto-approved.
- Rejected requests can be revised and resubmitted unless the project policy disables resubmission.
- If the approved amount differs from final purchase amount, the app must flag the variance for manager or finance review.

### Reimbursement Claim

Use when the employee already purchased something.

Required fields:

- Workspace
- Project
- Merchant
- Final amount
- Currency
- Purchase date
- Category
- Business purpose
- Receipt attachment, unless project policy allows missing receipts under threshold

Expected lifecycle:

1. Draft
2. Submitted
3. AI scan processing, if receipt uploaded
4. Pending manager approval, pending finance review, or both depending on project policy
5. Approved or rejected
6. Ready for reimbursement
7. Reimbursed

Rules:

- Claims can skip purchase confirmation because the purchase already happened.
- Missing receipt handling must be explicit: block, warn, or allow with reason.
- Duplicate receipt detection should be a v1 warning if AI scan is enabled.

## 2. Manager And Finance Responsibilities

Manager and finance roles can both participate in approval and reimbursement. The project policy decides the route.

### Manager Responsibilities

- Review business purpose.
- Approve or reject expenses.
- Add rejection reason.
- Approve over-budget requests if policy allows.
- Reimburse directly only when the project or workspace policy grants that permission.

### Finance Responsibilities

- Review receipt completeness.
- Verify payment details.
- Mark reimbursement as sent.
- Upload reimbursement proof.
- Reject or return to employee for missing documentation.

### Routing Modes

Each project should support one of these routing modes:

- `manager_only`: manager approves and can reimburse.
- `finance_only`: finance reviews and reimburses.
- `manager_then_finance`: manager approves, finance reimburses.
- `auto_approve_then_finance`: expenses under threshold skip manager and go to finance.
- `auto_reimburse`: allowed only for low-risk project/category combinations.

### Expense Statuses

Use backend-facing statuses rather than UI labels:

- `draft`
- `submitted`
- `scan_processing`
- `scan_failed`
- `pending_manager_approval`
- `pending_finance_review`
- `approved`
- `rejected`
- `purchase_confirmed`
- `ready_for_reimbursement`
- `reimbursed`
- `cancelled`
- `archived`

UI labels can map from these statuses:

- `pending_manager_approval` -> Awaiting approval
- `pending_finance_review` -> Finance review
- `purchase_confirmed` -> Awaiting reimbursement
- `ready_for_reimbursement` -> Ready to pay

## 3. Project Control Rules

Projects are not labels. A project controls access, budget, policy, and routing.

### Project Fields

Each project needs:

- Workspace ID
- Name
- Description
- Budget amount
- Budget currency
- Budget period: monthly, quarterly, annual, custom, or lifetime
- Spent amount, derived from approved/purchased/reimbursed expenses
- Owner member ID
- Status: active, archived
- Visibility: private, team, workspace
- Approval threshold
- Receipt required threshold
- Allowed categories
- Routing mode
- Default manager approver IDs
- Default finance reviewer IDs
- Over-budget behavior

### Project Membership

Project membership should be separate from workspace membership.

Project-level roles:

- `viewer`: can view project expenses if visibility allows.
- `submitter`: can submit expenses to the project.
- `approver`: can approve project expenses.
- `finance`: can review payment details and reimburse.
- `project_admin`: can manage project members and policies.

Workspace admins can manage all projects unless explicitly restricted in a future enterprise policy.

### Budget Behavior

When an expense affects budget:

- Draft expenses do not count against budget.
- Pending requests count as forecasted spend.
- Approved, purchased, and reimbursed expenses count as committed spend.
- Rejected, cancelled, archived expenses do not count in active budget totals, but remain reportable.

Over-budget behavior must be one of:

- `warn`: allow submission with warning.
- `escalate`: require higher approver.
- `block`: prevent submission.

## 4. AI Receipt Scanning

AI receipt scanning is part of v1. It should be implemented as a reviewable extraction flow, not as silent auto-fill.

### Supported Inputs

- Camera photo
- Photo library image
- PDF receipt, optional for v1 if upload support is ready

### Extracted Fields

The AI scan should attempt to extract:

- Merchant
- Amount
- Currency
- Purchase date
- Tax
- Category
- Last four digits or payment hint when visible
- Line items, optional for v1

### Scan States

Receipt scan status:

- `not_started`
- `uploading`
- `processing`
- `needs_review`
- `confirmed`
- `failed`

Field-level confidence:

- `high`
- `medium`
- `low`
- `manual`

Rules:

- User must review extracted fields before submission.
- Low-confidence fields should be visually flagged.
- Scan failure should leave the user in manual entry mode with the receipt still attached if upload succeeded.
- Duplicate detection should warn if merchant, amount, date, and receipt fingerprint are similar.

## 5. Multi-Workspace Support

Multi-company/workspace support is part of v1.

### Workspace Rules

- A user can belong to multiple workspaces.
- Role is scoped per workspace.
- Project access is scoped within a workspace.
- Expenses cannot move across workspaces in v1.
- Workspace switching reloads scoped projects, policies, members, notifications, and expenses.
- The current workspace should be persisted locally as a preference.

### Workspace Onboarding

Supported entry paths:

- Create a new workspace.
- Accept an invite to an existing workspace.
- Sign in and select from existing workspaces.

Invite behavior:

- Invite has email, workspace, role, expiration, inviter, and status.
- Invite statuses: pending, accepted, expired, cancelled.
- A user can accept an invite only with the invited email or after email verification.
- The last admin cannot be removed or downgraded.

## Required Screens Before Database Integration

The prototype should be adjusted or scoped to include:

- Expense type selector in submit flow.
- Project policy editor.
- Project member assignment.
- Manager review queue.
- Finance review/reimbursement queue.
- Receipt AI review state.
- Rejection reason and resubmission flow.
- Workspace invite acceptance flow.
- Workspace switcher with role indication.
- Empty/loading/error/offline states for all data-backed surfaces.

## Non-Goals For Initial Database Integration

These can wait until after the first real persistence layer:

- Advanced report builder.
- Payroll/accounting integrations.
- Multi-currency conversion rates.
- Corporate card reconciliation.
- Fine-grained enterprise policy engine.
- Full line-item accounting.
