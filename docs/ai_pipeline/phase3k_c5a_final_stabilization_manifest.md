# MedCases NEXT — Phase3K-C5A Final Stabilization Manifest

ARCHITECTURE_STATUS=COMPLETE
CUTOVER_APPROVED=YES
FULL_TERMINAL_OWNERSHIP=YES
VISIBLE_PROGRESSIVE_STREAMING=YES
PROVISIONAL_UI_BUFFER_DIRECT_PERSISTENCE=NO
TERMINALIZATION_GAP_ANIMATED=YES
PERSISTENCE_EXACTLY_ONCE=YES
STRUCTURED_UI_ATTACHED=YES
HARD_STOP_FINAL_ONLY=YES
KILL_SWITCH_VALIDATED=YES
STUDY_ISOLATION_VALIDATED=YES
PRODUCTION_ROLLOUT_AUTHORIZED=NO
OPEN_WORKSTREAM=CLINICAL_CONTENT_VALIDATION
REMAINING_RESTRUCTURING_PERCENT=0

## Canonical repository identity

- Branch: `phase4-visible-ux-refactor`
- HEAD: `c9e21ad6afbc32bf8c28192e0b330a35b9ecda15`
- R12-V7 evidence SHA-256: `8e82fa58de5db648e734fa470230802bb6800b7c5eed92768ba77506e4fca1e8`

## Retained productive owners

- `lib/providers/app_provider.dart`
  - SHA-256: `19895eedfac57dc6e3feb014bb12d3506761f93084115f4953937a2c6c88eeed`
- `lib/screens/ai_screen.dart`
  - SHA-256: `4df108c16c2da4b257f3398020ce581acd62bbffdd8cc000d60ded62e614bbc2`
- `lib/services/ai_pipeline/plantao/plantao_buffered_cutover_controller.dart`
  - SHA-256: `e533dea08f81734b4d9df18f64b55192eb5475142621caef46c2ae6aac2702da`
- `lib/screens/ai/widgets/guardia_clinical_response_view.dart`
  - SHA-256: `33db68c6ee2ec408fe682ee6476207531630fa9a694c2dcf991d3b792c9ab1d5`
- `test/services/ai_pipeline/plantao/plantao_provisional_visible_streaming_contract_test.dart`
  - SHA-256: `db40182b23abb009bd1fd5a6f231d671ca672f72119e7821f913a083638f1c33`

## Terminal contract

1. Transport deltas may update only the provisional visual projection.
2. Provisional projection does not directly persist.
3. The terminal result remains the only canonical commit.
4. Final text reconciliation occurs after terminal validation.
5. DTO attachment occurs after `onDone`.
6. HARD STOP content remains hidden while streaming.
7. Persistence remains idempotent by request/session correlation.
8. Cancellation, stale request and busy-cutover paths fail closed.
9. Study mode remains outside the Plantão cutover.
10. The legacy kill switch remains available.

## Production soak plan

This phase does not enable a broad rollout.

Before broad release:

1. Keep the production allowlist closed by default.
2. Run a limited authenticated cohort with request-scoped telemetry.
3. Confirm one commit, one persistence and one DTO per request.
4. Confirm no partial response enters history or Firestore.
5. Confirm cancellation and background transitions preserve ownership.
6. Confirm PT and ES output independently.
7. Review clinical-content correctness separately from architecture.

## Separate clinical-content workstream

The architecture is complete, but broad production rollout is not authorized
by this manifest. Clinical answer correctness, pharmacology and protocol
alignment require their own evidence and approval. No architectural PASS may
be interpreted as clinical validation of generated content.
