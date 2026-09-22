# Source fixture — Patch 3S

Test-only extraction of the 16 existing INFUSION_FALLBACK_DB rows and their BIC_PRESETS from the canonical calculator. Source commit and SHA256 are stored in presets.json. Source values are preserved, including null prescribed dose. This fixture is neither a runtime drug catalog nor a canonical binding table. Preparation IDs are not drug IDs.

The fixture also preserves the 12 complete canonical reference documents reached by the repository's existing deterministic normalizer. All 12 explicitly have calculationAuthorized=false. Their presence proves reference identity only; it does not bind an infusion preparation. The other four normalizer outputs do not exist in the canonical index. The nitroglycerin interaction alias is a class grouping, not approved formulation identity. No data is included in app assets or imported by production code.

Regenerate only from the reviewed source, never by name inference. Run `node test/services/infusion/canonical_infusion_source_test.cjs /path/to/medcases-calculadora` to verify the source hash and exact fixture parity and exercise the original InfusionMath implementation. The clinical review of the adult calculator does not supply canonical IDs or authorize Flutter/AI infusion operations.
