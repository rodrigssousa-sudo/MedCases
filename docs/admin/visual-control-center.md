# Admin visual control center

Default route is Dashboard. Operational views use paginated metadata, human-readable dates, status badges, and collapsed technical details. User search accepts exact email, name or displayName; UID is an advanced option. Granting time uses the selected user's internal ID and the existing idempotent, atomic credit API. VIP and subscription mutation remain unavailable because no approved entitlement write contract exists.

## Metric provenance

- User totals and declared plans: aggregate users. VIP is a separate internal flag, not a mutually exclusive plan count or billing entitlement.
- Activity today: lastSeenAt Timestamp only; absent source is unavailable. Daily historical active users are not inferred from a current last-seen field.
- Growth: createdAt Timestamp. AI daily requests/modes/error counts/latency: admin_ai_usage_events.
- Transcription consumption: completed usageReservations containing transcription; grouped by reservation creation date, not inferred completion date. In-flight reservations are excluded.
- Extra time granted: adminManualCredits amountSeconds by grantedAt, not available balance.
- Costs: verified fresh admin_ai_metrics/realtime rolling 24 hours only. No invented calendar-day, 7-day, 30-day or transcription costs. Observed provider/model events are historical, not configuration.
- Unsupported historical series show “Sem dados disponíveis”.

All metrics authorize each call, including cache hits. Cache lifetime is 60 seconds; date window is 7 or 30 days. No raw clinical content is read. The aggregate query indexes in validation/admin_visual_indexes.json are additive; deploy individual missing indexes, never replace or delete existing indexes.

Campaign destination/audience/schedule are draft metadata only. Existing dispatch-disabled, locale, opt-out, quiet-hour and weekly-limit contracts remain intact. No campaign is sent by saving a draft.

## Validation

Run test/admin and test/guides, Functions release tests, validation/admin_visual_metrics.cjs and existing notification/RBAC/guide tests in Firestore emulator. server/test/manual_time_firestore_test.js covers real transactional contention without production grants. Analyzer must have zero errors/warnings. Deployment scope: adminOperations and medcases-pro-admin Hosting only; no mobile or quota changes.
