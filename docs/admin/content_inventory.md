# Canonical metadata inventory

Clinical authority remains in the source repositories. This module cannot edit clinical content, publish it, approve it, or grant calculation permissions. The Admin callable offers authenticated reads only to active Master, Admin and Supervisor accounts.

## Provenance

- Drugs: `rodrigssousa-sudo/medcases-calculadora`, `main`, `data/drugs/*.json`, cross-checked against `data/drugs_index.json`. The public Free60 directory and AI bundles are not the complete inventory.
- Pathologies: `rodrigssousa-sudo/MedCases`, `main`, `assets/clinical/clinical_registry_phase24_authoritative270.json`. Identity is `canonicalKey`; locale availability comes from content locale records. Display labels and management metadata come from the same identity's management rule. These labels may describe a management variant rather than a unique diagnosis. Matching labels are review candidates, never an automatic identity merge.
- Every sync resolves a commit once and reads all files at that immutable commit. Source branch state is not proof of production publication.
- The pathology registry explicitly contains local drafts. Neither its filename nor enabled flags imply clinical approval or publication.
- A drug's Gold33 homologation, publication authorization, package publication state and calculation authorization are displayed independently. Missing reviewer/date/approval remains unknown. Review date without named reviewer is incomplete review metadata.
- No verified expansion candidate list was found in these two canonical inventory contracts. NEW remains empty; a future candidate source requires its own verified provenance adapter.

## Storage and synchronization

`adminContentInventoryV2/{drugs|pathologies}` holds a generation pointer and aggregate counts. Immutable `generations/{generation}/items/{recordId}` contain metadata and search indexes. A transaction and lease serialize syncs; only a fully written generation can become visible. Network failures preserve the active generation. Missing source records remain in the next generation with `MISSING_IN_SOURCE`; nothing auto-merges or deletes.

`runs/{syncId}` records metadata-only audit results and pre-sync comparison counts. History is not a copy of clinical source content. Source cache reuse is keyed by Git blob hash. GitHub reads are allowlisted, bounded, and retried at most twice for transient errors. The scheduled function runs daily. It accepts no user-supplied clinical payload or source URL.

Search is accent/case/hyphen-normalized prefix search over PT name, ES name and canonical ID, combined with one filter. It uses a single Firestore array membership index and document ID pagination. A cursor remains bound to its immutable generation. The browser never downloads the full inventory.

`inventory` action `queue` returns metadata plus `workItems`. Stable queue IDs derive from kind, record identity and reason. Queues are recalculated from source metadata, not independently editable or clinical sources of truth. The read model supports the future events CONTENT_CREATED, CONTENT_UPDATED, PENDING_REVIEW, APPROVED, PUBLISHED and SYNC_FAILED through subsequent repository synchronization; no event endpoint can approve or publish content.

## Security and deployment

No additional client Firestore access is required: reads go through the existing authorized Admin callable; client writes to the new collection remain denied by the rules' default deny. No new composite index is needed for the single array filter ordered by document ID. Deploy only `adminOperations`, `syncAdminContentInventory`, and the existing Admin Hosting site. Capture current Hosting/backend/rules/index state and verify runtime configuration before promotion. Do not promote pending Push V2 commits as part of this change.

Tests: `node --test functions/test/content_inventory.test.js`; Firestore integration additionally requires `FIRESTORE_EMULATOR_HOST`, always with project `demo-content-inventory`; UI tests are in `test/admin/content_inventory_section_test.dart`.
