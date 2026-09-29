# Admin Phase 2 source contracts

The Admin is a metadata reader, never the clinical source of truth. Manual credit
owners remain unchanged at b80abe3a7404fdaa3696695468c7d2fa85cfc762.

## Inventory handoff
A future trusted repository agent validates records with `admin_inventory_contract.js`
and writes metadata only to `adminContentInventoryPathologies/{canonicalId}` or
`adminContentInventoryDrugs/{canonicalId}`. The source repository HTTPS URL and
immutable revision are mandatory. Preserve the previous source revision in the
agent's append-only run report. Use additive/upsert batches, never delete absent
clinical records. An incomplete batch must retain its previous published index;
only mark the sync complete after readback. No browser upload or clinical publish
endpoint is provided. Missing clinical approval, Gold33, language or calculation
metadata remains UNKNOWN, never inferred from presence in the index.

## Operational sources
- Users: paginated `users`; notification device count from `notificationDevices`.
- Usage: existing `monthlyUsage` and manual credit records, read only. Base
  allowance is not recomputed by Admin; the gateway remains authoritative.
- Transcription: `_study_background_transcription_jobs`, metadata only. A retry
  may only requeue an existing AssemblyAI execution with matching owner/reservation,
  existing provider job, retryable state and no active worker lease. It cannot
  create a provider request, settle quota, delete audio or cancel a recording.
- Other job types: `adminOperationalJobs` read model. Unsupported executors have
  no retry/cancel control. Their absence is not interpreted as successful work.
- AI: `admin_ai_usage_events`, preserving existing mode/provider/duration/success.
- Notifications: `notificationDeliveries` and aggregate device counts. Opened and
  deep-link success remain UNKNOWN until an authoritative event source exists.
- Campaigns: bilingual drafts only in `adminEngagementDrafts`. Dispatch disabled;
  PT/ES, cap 3/week/device, opt-out, quiet hours and locale are mandatory. A future
  dispatcher must atomically enforce these per device; a draft is not a send.
- Health: `adminServiceHealth`, valid only for verified observations <=15 minutes
  old. Missing/stale/future observations return UNKNOWN.
- Releases/deploys: `adminReleaseInventory` / `adminDeploymentInventory`. No store
  integration is implied by an empty collection.

## Writes and audit
`adminOperations` authenticates the current Firestore role on every read and again
inside write transactions. Supervisor cannot write. Role changes require Master;
self/Master/claim-managed targets are protected. Billing/RevenueCat writes are not
provided. Guide save/publication retains the bilingual review contract, uses a
stable content request, preserves history and records reviewer/date/version.
New operations atomically write `adminControlAudit` and an idempotency receipt.
No clinical prose, token, credential or audio is copied into the audit. Older
`admin_audit_logs` remain available separately; their incomplete metadata is not
backfilled with invented reasons.

## Validation
Run Functions release suite, Flutter Admin/guides suite and the Firestore emulator
suite `validation/admin_phase2_firestore.cjs`, plus the unchanged manual ledger
concurrency suite. No real credits, clinical publications or campaigns are needed.
