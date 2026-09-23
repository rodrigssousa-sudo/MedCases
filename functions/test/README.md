# Functions release gate

Run `npm test` from `functions/` for the complete repository release/security gate.
It uses `test/release_test_manifest.json`, checks that every Functions test is
classified exactly once, and fails on any missing or unclassified release test.

Prerequisites: Node 22, the locked dependencies, Flutter dependencies already
resolved, a local Firestore emulator at `127.0.0.1:8787`, and Chrome for browser
crypto tests. `FLUTTER_BIN`, `CHROME_EXECUTABLE` and
`MEDCASES_CALCULATOR_ROOT` can identify local tools/fixtures. No production
Firestore, provider or mail connection is part of this gate.

`npm run test:release:functions` is the Functions-only subset, not the complete
release gate. The manifest additionally runs server billing/auth/quota/provider
regressions, Firestore ownership/concurrency, Flutter session/cache/safety and
browser crypto tests.

## Historical pipeline archaeology

`npm run test:historical` explicitly runs the preserved intermediate pipeline
tests. They require authentic historical generated evidence that is absent from
the release source. Their assertions remain unchanged and failures are reported;
there are no skips or synthetic replacements. These documentary tests are not
release prerequisites. Every classification has artifact references and a
rationale in the manifest.

S1 observation was decommissioned because its Phase14 artifact has no recoverable
provenance. The compatibility adapter uses the existing disabled canary runtime:
no request inspection, Firebase read/write, provider call or visible mutation.
It does not activate Phase24 or remote clinical content. Current runtime/import,
canary rejection, provider parity and canonical contract tests remain release
critical. The four reproducible phase1/phase2 artifacts remain TEST_TEMP_ONLY.
