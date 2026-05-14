# Pre-Database Implementation Checklist

Use this checklist to prep the app before wiring a database.

## 1. Expense Types

- [x] Add expense type selector to submit flow: pre-approval request or reimbursement claim.
- [x] Add different labels/routing copy by expense type.
- [x] Add full required-field validation by expense type.
- [x] Add purchase date for reimbursement claims.
- [x] Add needed-by date for pre-approval requests, optional in v1.
- [x] Add final amount handling for approved pre-approval requests.
- [x] Add resubmission flow for rejected expenses.
- [x] Rename UI labels so "New Request" does not imply only pre-approval.

## 2. Workflow And Statuses

- [x] Add backend-facing workflow status enum.
- [x] Add a status-to-UI-label mapper.
- [x] Add manager review queue.
- [x] Add finance review/reimbursement queue.
- [x] Migrate review queue reads to repository-backed state.
- [x] Migrate activity list reads to repository-backed state.
- [x] Migrate home/dashboard/report summary reads to repository-backed state.
- [x] Add domain-native detail route for repository-backed screens.
- [x] Replace domain list row adapters with `DomainExpenseRow`.
- [x] Add purchase confirmation only for pre-approval expenses.
- [x] Add rejection reason as required input.
- [x] Add comments/activity timeline as real expense events.
- [x] Add archive/unarchive behavior separate from delete.
- [x] Add cancelled state for user-abandoned submitted requests.

## 3. Manager And Finance

- [x] Add finance as a workspace role.
- [x] Add project finance role domain type.
- [x] Define manager-only reimbursement permission.
- [x] Add finance proof upload when marking reimbursed.
- [x] Add route badges in lists so users know who owns the next action.
- [x] Prevent unauthorized approval/reimbursement actions in UI state.

## 4. Project Controls

- [x] Add project detail edit mode.
- [x] Add project member assignment.
- [x] Add project roles: viewer, submitter, approver, finance, project admin.
- [x] Migrate project list reads to repository-backed project models.
- [x] Add project policy editor.
- [x] Add allowed categories per project.
- [x] Add budget period.
- [x] Add over-budget behavior: warn, escalate, block.
- [x] Add archive project flow.
- [x] Define behavior for expenses attached to archived projects.

## 5. AI Receipt Scanning

- [x] Keep uploaded receipt attachment before extraction.
- [x] Add upload state.
- [x] Add processing state.
- [x] Add scan failed state with manual fallback.
- [x] Add extracted-field review UI.
- [x] Add receipt scan status and field confidence domain types.
- [x] Add duplicate receipt warning.
- [x] Add manual correction tracking.
- [x] Add support for purchase receipt and reimbursement proof attachments.

## 6. Multi-Workspace

- [x] Replace demo company picker with current-user workspace list.
- [x] Show role per workspace in switcher.
- [x] Persist last selected workspace locally.
- [x] Scope repository-backed tabs by selected workspace.
- [x] Add workspace create flow.
- [x] Add invite acceptance flow.
- [x] Add invite expiration/cancel behavior.
- [x] Add last-admin protection.
- [x] Prevent cross-workspace project/expense selection.

## 7. Notifications

- [x] Define notification triggers.
- [x] Add notification deep links to expense, project, or invite.
- [x] Add unread/read behavior.
- [x] Add notification preferences.
- [x] Decide v1 channels: in-app only, email, push.

## 8. Reports And Analytics

- [x] Replace synthetic monthly chart values with date-based aggregation.
- [x] Add date range filters.
- [x] Add project/member/status/category filters.
- [x] Define report export permissions.
- [x] Decide v1 exports: CSV, PDF, receipt bundle.

## 9. App State Architecture

- [x] Add repository protocols and mock implementations.
- [x] Add repository-backed app state facade alongside prototype `AppState`.
- [x] Add async loading/error states to repository-backed app state.
- [x] Add repository-level permission errors for blocked workflow actions.
- [x] Add empty states for each major screen.
- [x] Add offline state for drafts and uploads.
- [x] Introduce domain models independent of SwiftUI.
- [x] Keep mock repository implementation until DB/API is ready.

## 11. Membership And Permissions

- [x] Add workspace member domain model.
- [x] Add member/invite repository operations.
- [x] Back members and invites with mock repositories.
- [x] Migrate permissions member/invite reads to repository-backed state.
- [x] Wire role changes, invite cancellation, invites, and member removal through repositories.
- [x] Add invite role selection.
- [x] Add last-admin protection behavior.
- [x] Add invite acceptance UI.

## 10. Testing Prep

- [x] Add workflow transition tests.
- [x] Add permission matrix tests.
- [x] Add project policy routing tests.
- [x] Add receipt scan state tests.
- [x] Add workspace scoping tests.
- [x] Add last-admin protection tests.

## Suggested Implementation Order

1. Add domain enums and state machine. Done.
2. Add repository protocols plus mock implementations. Done.
3. Update submit flow for expense type and AI review state. Started: expense type is in place; AI review UI remains.
4. Split manager and finance queues.
5. Expand project policy/member screens.
6. Add workspace invite and membership behavior.
7. Replace current mock arrays with mock repositories.
8. Integrate database/API behind repositories.
