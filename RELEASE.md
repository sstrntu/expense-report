# Production release runbook

The iOS app is wired entirely to Supabase — no mock or hardcoded data in a
release build.

## Deployment status (project `pwxhgvuyaxgavommtqpr` / "turfmapp-ai-agent")

Done via the Supabase MCP on 2026-05-16:

- ✅ `receipt_storage` migration applied — private `receipts` bucket + RLS.
- ✅ `expense_workflow` migration applied — routing + audit + notification
  triggers (`expenses_route_submitted`, `expenses_log_transition`).
- ✅ `scan-receipt` Edge Function deployed (ACTIVE, `verify_jwt = true`).
- ✅ `revoke_anon_expense_access` migration applied — closed the legacy
  `grant_anon_access` hole (anon could `TRUNCATE` expense tables).
- ✅ Base expense schema was already present (RLS on all 16 tables).
- ✅ **Expense schema moved out of shared `public` into its own
  `turfmapp_expenses` schema** (`move_expense_schema...` migration) — 16
  tables, 15 enums, 15 functions, 40 RLS policies, 4 storage policies, 2
  triggers; data preserved; anon stays revoked. Other apps untouched.
- ✅ iOS client sends `Accept/Content-Profile: turfmapp_expenses`; edge
  function uses `db.schema = turfmapp_expenses` (redeployed, v3).
- ✅ `Info.plist` uses the project's modern publishable key; `config.toml`
  `project_id` corrected to `pwxhgvuyaxgavommtqpr`.

### Pending migrations (2026-06-12 permission hardening — not yet applied)

Apply in order via the Supabase MCP or `supabase db push`:

- `20260612090000_protect_last_admin.sql` — trigger refusing to demote,
  suspend, remove, or delete a workspace's last active admin (prevents
  permanent admin lockout; the Permissions UI locks the row too).
- `20260612090100_submitters_can_cancel_pending.sql` — widens the submitter
  UPDATE policy's USING set so "Cancel submission" works on in-flight
  expenses (target statuses unchanged — still no path into approval states).
- `20260612090200_reviewer_project_visibility.sql` — `can_access_project`
  now includes workspace manager/finance, so reviewers can see the name and
  budget of private/team projects whose expenses they could already act on.
- `20260612090300_clear_project_roles_on_reinvite.sql` — accept-invite RPC
  clears previous-tenure `project_memberships` when reactivating a removed
  member, so old project roles don't silently come back.
- `20260612090400_mark_reimbursed_records_payment.sql` — `mark_expense_reimbursed`
  RPC writes the `payment_records` audit row (method, amount, proof, paid_at)
  and flips status to `reimbursed` in one transaction. Pairs with the iOS
  client change routing reimbursement through the RPC instead of a bare
  status PATCH.

The iOS gating changes that pair with these ship in the same commit; the app
fails safe against an un-migrated DB (actions are hidden or rejected by the
old policies), with two exceptions that need their migration applied to work
at all: "Cancel submission" on pending expenses (`…090100`), and "Mark
reimbursed" (`…090400`) — the latter calls an RPC that doesn't exist until
the migration runs, so reimbursement will error until then.

### TWO things still required from you (dashboard — no API/MCP for these)

1. **Expose the new schema to the Data API** (the app/edge cannot reach
   `turfmapp_expenses` until this is done):
   Dashboard → Project → **Settings → API → Exposed schemas** → add
   `turfmapp_expenses` (keep `public` and `graphql_public` selected too) →
   Save. PostgREST reloads automatically.

2. **Set the OpenAI key as an Edge Function secret** (until then receipt
   scans return a clean "not configured" message):
   Dashboard → Edge Functions → Manage secrets → add `OPENAI_API_KEY = sk-…`
   (optionally `OPENAI_MODEL`, default `gpt-4o-mini`), or
   `supabase secrets set OPENAI_API_KEY=sk-… --project-ref pwxhgvuyaxgavommtqpr`.

Then build/run the app in Xcode and walk the smoke test below. Note: until
step 1 is done the app will show a Supabase error on load (schema not
exposed) — that is expected and resolves the moment you save the setting.

### Shared-project note

This project also hosts unrelated apps (`turfmapp_content_planner`,
`mz-27SS-upload-qc`, `turfmapp_agent`). Advisors flag 17 RLS-disabled tables
and project-wide auth settings **in those apps** — out of scope here, but
their owners should address them. The expense schema itself is RLS-clean.

---

## (Reference) the migrations / function, if you ever redeploy from scratch

## 1. Database migrations

Apply the new migrations (in order) to the production project:

```
supabase db push
```

New migrations added in this change:

- `20260516090000_receipt_storage.sql` — creates the private `receipts`
  Storage bucket and its RLS policies.
- `20260516093000_expense_workflow.sql` — server-side workflow:
  - routes `submitted` expenses to the correct next status from the
    project's `routing_mode` / `approval_threshold` (without this, submitted
    expenses never reach the review queue);
  - appends `expense_events` audit rows on every status change;
  - creates `notifications` for submitters and queue owners.

Pre-existing schema (`20260515170000`, `20260515173000`) must already be
applied — `create_workspace_with_admin` seeds the 5 default categories per
workspace, which the app now requires for expense submission.

## 2. Edge Function: `scan-receipt`

The fake scan was replaced with a real OpenAI-vision implementation that
downloads the receipt from Storage and writes `receipt_scans` /
`receipt_scan_fields`.

```
supabase functions deploy scan-receipt
supabase secrets set OPENAI_API_KEY=sk-...        # required
supabase secrets set OPENAI_MODEL=gpt-4o-mini     # optional (default)
supabase secrets set SUPABASE_STORAGE_RECEIPT_BUCKET=receipts  # optional (default)
```

`config.toml` keeps `verify_jwt = true`; the function runs every DB/Storage
call under the caller's RLS via their forwarded JWT. Without `OPENAI_API_KEY`
a scan returns a clean "not configured" failure (no crash, no fake data).

## 3. iOS build

Open `ios/TurfmappExpenseReport.xcodeproj` in Xcode 26 and build/archive.
`Info.plist` already contains the production `SUPABASE_URL` /
`SUPABASE_PUBLISHABLE_KEY`. In a release build, if those are ever missing the
app fails loudly (`NotConfiguredRepository`) instead of serving mock data.

Verified locally: `xcodebuild ... build` succeeds and all 9 unit tests pass.

## What changed in the app (summary)

- Removed the MockData-backed Demo login mode; auth is Supabase only.
- `AppState` reduced to session/identity; `RepositoryAppState` is the single
  source of truth. All "dual-write to mock store" paths removed.
- Overview / Home / Dashboard KPIs are computed from real expenses
  (the fixed `$18.4k`, `+12% vs LM`, `2 over 24h`, `+8.2%`, `$22.18`,
  hardcoded sparkline and the fake "AI Insight" card are gone).
- Submit flow uses real workspace projects + categories; the receipt scan
  uploads the actual photo, runs the AI Edge Function, and prefills fields.
- Projects/permissions/notifications/account screens read & write Supabase;
  fabricated copy ("updated 24 days ago", `$100/$75` policy, etc.) removed.

## Known follow-ups (not blocking, not fabricated data)

- `ios/.../Screens/DetailView.swift` is now dead code (the legacy `.detail`
  route was removed). It still compiles. Remove it and re-run
  `xcodegen generate` when convenient — left in to avoid `project.pbxproj`
  churn in this change.
- Legacy model types (`Expense`, `Project`, `Member`, `ExpenseDraft`,
  `MockData`) remain only for the mock repositories used by unit tests /
  DEBUG; they are never exercised in a release build.
- `AppPreferences` "Compact lists" is a device-local toggle only (no
  server preference store yet).
- Account email changes are intentionally not supported in-app (Supabase
  Auth email-change flow not implemented); name persists to `users`.
