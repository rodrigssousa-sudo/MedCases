# MedCases public landing and real testimonials

The web pre-login now embeds a responsive PT/ES landing. Login, registration,
password recovery, consent and professional declaration continue through the
existing screens. Native pre-login is retained. Header Entrar and PT/ES are grouped
on the right; the consent overlay now exposes a return button without requiring
acceptance. No fictitious testimonials are bundled.

## Authentication and testimonials

A versioned JSON bridge accepts only the same origin and exact iframe window.
Native JavaScript window identity is compared because dart:html MessageEvent.source
returns null for a cross-frame WindowBase. Only an action and language cross inward;
only approved public testimonial fields cross outward. Tokens never enter the iframe.

The testimonial CTA saves a one-hour navigation intent, opens the existing login,
and opens the editor only inside the approved-user/professional declaration gates.
Back cancels the intent. Web menu > Depoimentos reopens the editor and, for existing
admin/master roles, the moderation queue. Role presentation is not authorization:
Firestore rules enforce permissions on every request.

- Private collection: testimonial_submissions/{uid}, one submission per account.
- Public collection: testimonial_public/{uid}, approved display fields only.
- Author supplies public name, profession, 10–1000 character text and explicit
  publication consent. A resized local profile photo is optional and opt-in.
- Submission/edits become pending and atomically remove the public snapshot.
- Admin/master can approve, feature, reject or delete; author can withdraw/delete.
- Moderators cannot rewrite author content. Public snapshots must exactly match
  the consented submission. Update-time preconditions prevent stale moderation.
- REST uses the existing end-user Firebase ID token (despite the legacy method
  name getAdminToken); no service account or privileged key is exposed.
- Queue queries are bounded to 100 records per status; landing shows up to 12.

## Preserved production rules

The live Firestore release read before deployment was
projects/medcases-pro/rulesets/0b4f065d-4af5-448d-a5bd-5c4f69635c60
(updated 2026-09-15). It differs from GitHub main: production has commerce /
RevenueCat protections; main has R20/R22 role and session isolation protections.
This change retains main's protections and merges the live commerce guards,
including permitted missing FREE/TRIAL default repairs. Testimonials require
these role protections to prevent ordinary clients from promoting themselves.
The previous live source and release identity were backed up outside the repo.

## Validation

- 18 tests passed against the real local Firestore emulator: anonymous/private
  reads, owner isolation, role escalation, admin restrictions, consent/schema,
  approval, atomic withdrawal/edit/delete, normal registration/profile updates,
  free/trial repair and RevenueCat field protection.
- 8 Flutter tests passed: bridge intents, navigation intent, consent gating,
  ordinary-user editor, submission transport, failure handling, stale writes and
  actual hit-testing of the return button on login and registration.
- 42 existing authentication/registration/consent regression tests passed.
- Analyzer: final run reports `dart:js_util` as an unavailable URI in the web-only
  bridge, although the SDK contains it and the release compiler succeeds. This
  legacy web interop diagnostic remains; browser window/origin validation passes.
- Browser: native-window bridge opens the existing login/consent screen.
  No legal agreement was accepted and no real testimonial/account was fabricated.
- Local responsive view: 390px width, no horizontal overflow, 44px header controls,
  compact 68–82px bibliography rows, PT/ES official store badges.
- Final release build and production checks recorded in task delivery evidence.

Reproduce rules tests (Java 21+, installed Firebase CLI):
```
cd test/testimonials_rules
npm ci
firebase emulators:exec --only firestore --project demo-medcases-testimonials --config firebase.json 'npm test'
```

## Deployment

GitHub rodrigssousa-sudo/MedCases, branch main. DigitalOcean app
c081f195-18aa-4e3e-b1f7-2a643b9a9f6b (medcases), domain medcasespro.com;
medcases and ai-gateway components auto-deploy on push. Firestore rules deploy
separately with `firebase deploy --only firestore:rules --project medcases-pro`.
The authorized full ruleset was deployed and read back with an identical SHA-256:
`b79c0f4a42130f5aadce4e2c080a654de0032d65a28abb4356901ade51b4c339`.
Active ruleset: `231a218c-e2a9-4cb1-b6d8-3329c4f42333`.
No DNS, separate calculator app, Functions or Firestore indexes are changed.

## Assets and remaining limitations

- App Store URL id6771750300 preserved and verified. Android official PT/ES badge
  is visible but disabled without a link, explicitly requested by the owner.
- The supplied guide contains 150 unique numbered topics across 32 pages.
  Bibliography links GINA 2026, GOLD 2026, KDIGO 2024, WHO 2025,
  AHA/ACC/HFSA 2022 and the previously verified Humulin N / DailyMed reference.
- Eleven supplied screenshots and supplied logo are retained.
- Hero uses the owner-supplied Canva MP4 export: real footage of doctors with
  a tablet, VITALY GARIEV / Artlist asset VAGtSU1u3ZI, design DAHVySs8m7s.
  User approved real footage over the original walking sequence and rejected
  the AI candidate. Web asset: 854×480 H.264, 14.4 seconds, silent, ~1 MB.
  No MedCases interface is depicted in the stock footage; original app
  screenshots remain in their separate showcase. Canva credits are bilingual.
