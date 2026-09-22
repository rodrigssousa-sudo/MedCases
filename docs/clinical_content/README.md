# Local release preparation

This foundation is an opt-in host integration, not a deployed remote service.

1. Export reviewed canonical items from the domain owner without editing their clinical payloads. Preserve IDs. Attach the versioned item envelope and its content hash. Do not copy user/patient cases.
2. Provide `domains`, `sequence`, `contentVersion`, `generatedAt`, optional `minimumAppSchema` and `publicationStatus` in a reviewed input JSON. DRAFT is the default. Review metadata is never invented.
3. Run `dart run tool/build_remote_clinical_content.dart reviewed-input.json empty-output-directory`.
4. Review manifests, integrity, locale parity, entitlements, tombstones and the source diff. The tool only writes local files.
5. In a separately authorized publication cycle, host the immutable files and atomically publish manifest.json behind the approved authenticated gateway.
6. Configure the host gateway/store/session policy, then invoke AppProvider's sync. Existing data remains in use until a valid snapshot is activated.

Future compatible IDs require a new content publication, not an app schema/code migration. New schema features or changed native safety/engines still require an app build. None of these steps grants Clinical Authority or unblocks Patch 3S.
