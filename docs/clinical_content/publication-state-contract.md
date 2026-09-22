# Publication states and safety

- DRAFT: local preparation. Default for release builder. Never visible to general users.
- REVIEWED: reviewed metadata is recorded only if it exists; not general-user visibility.
- CANARY: requires explicit host cohort opt-in and eligible domain/item state. The remote state alone cannot enroll a client.
- PRODUCTION: visible only after full snapshot validation and current entitlement/session checks.
- REVOKED: explicit hashed tombstone. Never resolved as active; retained for audit and anti-resurrection.

STAGED/VALIDATED/ACTIVE are local snapshot lifecycle states, distinct from publication state. ACTIVE does not mean clinicalAuthority or doseAuthority. `catalogVisible` is independent of every effective operational capability, which remains false in the foundation wrapper.

Remote domain `enabled=false` hides content only after a valid sync. No remote flag is read by the mandatory safety engine, and neither source calculation metadata nor a remote safetyDisabled field can enable calculation, infusion or treatment authority.

Each successful publication advances `sequence`. Reusing a sequence with different manifest data or replaying an older sequence is rejected. A deliberate content rollback is a new higher-sequence release referencing the prior approved item versions. Revoked IDs cannot be resurrected by rollback. Removal without a tombstone and disappearance of an established domain both fail closed.

Publishing tooling only writes local derived files. It does not upload, commit, push or deploy. The builder does not review medicine, infer identities or invent reviewers/dates. A caller supplying PRODUCTION is responsible for an external reviewed publication workflow; the app still checks publication state, complete hashes, identity and schema.
