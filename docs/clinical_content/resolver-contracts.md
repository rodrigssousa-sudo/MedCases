# Resolver and gateway contracts

`ClinicalContentGateway`: injected HTTPS endpoint and auth policy, manifest load, indexes, exact item fetch, bounded body size and timeout, redirects disabled, same-origin paths, complete response/schema/hash validation, staging and atomic activation. Failure returns ContentSyncResult with a fixed code and retains the active snapshot.

`GuideResolver`, `ProtocolResolver`, `CaseResolver`, `ReferenceResolver`: exact canonical ID only. `ClinicalDomainResolver` covers the remaining declared domains. `ClinicalContentPlatform.drugs` uses Patch 3R.3's existing canonical read-only calculator resolver and a validated snapshot bridge when that domain is active. The bridge preserves the source document and all read-only authority gates. No catalog is authored locally. No aliases, redirects, fuzzy promotion or automatic IDs are created.

`relevantItems(exactIds, limit: 8)` deduplicates requested IDs and caps retrieval to 32 at most. It returns references with operational authority false. Intent extraction and existing safety/authority gating remain the caller's responsibility; passing source text directly as instructions is not part of this contract. The whole catalog is never automatically added to a prompt.

Unknown or revoked ID returns null. Catalog lookup does not resolve infusion fallback names. The existing 16 infusion bindings remain FAIL_CLOSED_UNRESOLVED_BINDING. `insulina_regular` remains readable by canonical ID, with no infusion authorization.

Every item requires canonicalId, schemaVersion, contentVersion, contentHash, updatedAt, publicationStatus and payload. Optional evidence/review metadata is preserved when supplied, never fabricated. Technical envelope generation time is not a clinical review date.

Hashes: recursively sort JSON object keys, preserve array order, UTF-8 JSON, SHA-256. Item hash covers the envelope except its own contentHash. Domain hash covers its complete index. Root manifest hash covers domain descriptors. Use the Dart publisher as reference serialization; this is not an assertion of independent digital signature verification. Trust in publisher identity depends on the approved HTTPS/auth endpoint. Hashes detect integrity mismatch, not malicious authorized authorship.

PT/ES maps require both locales, identical section topology/list lengths and matching references/canonicalId/contentVersion when represented within the locale maps. Validation is structural, not clinical translation equivalence. A mismatch rejects the candidate; it is never repaired by LLM. Monolingual legacy fields are preserved, not translated or declared bilingual.

`ClinicalContentModels` roundtrips all current protocol/case model fields. Missing IDs cannot enter permissive legacy auto-ID paths; custom/patient cases are rejected as publication items. AppProvider registers this validator before using remote protocol/case snapshots.

Durable stores: native FileClinicalSnapshotStore (flushed immutable generations + atomic pointer rename) and PreferencesClinicalSnapshotStore (immutable generations + single pointer-key activation, including web). Scope the storage directory/key per account and entitlement epoch, and run one content synchronization owner per store. Same-isolate writes are serialized. Cross-process shared-writer storage is not supported. Disk/browser quota failures retain LKG. MemoryClinicalSnapshotStore is for tests/ephemeral hosts, not durable offline release configuration.

The snapshot contains an account-scope hash; restoration rejects another scope. Current entitlement is checked again for every lookup. A durable revocation/sequence floor prevents a recovered previous generation from showing revoked IDs. Two invalid generations fail closed. A damaged journal requires host recovery/republication; no claim of tamper-proof local storage is made.
