# Impl round 1 — operational-concerns

- **Deploy/rollback:** both migrations are reversible bare `add_column` changes (`change` method auto-reverses). Nullable, no defaults — zero table-rewrite risk, safe on a large `users` table under PG. Code deployed before migration would only matter for the new permits/assignments hitting missing columns; standard migrate-then-release ordering applies as with the analog. No data migration needed (no backfill by spec).
- **Runtime dependencies:** `document.cookie` and `Date.now()` confined to `sanitizeTrackingParams`, which runs only in the browser on the auth/signup pages (both consumers verified). No SSR/node execution path exists for it.
- **Failure modes:** absent cookies/params degrade to nil columns silently (by design). The `_fbc`-async-pixel timing miss and constructed-fbc timestamp are accepted §14.3/§14.4 properties. The session-cookie overflow (§14.1) remains the accepted risk — degenerate cookie state can 500 that one SSO request; unchanged in kind from the prior feature.
- **Observability:** the SSO `[SSO][request_phase] tracking=` log line now shows the new keys — useful for verifying capture in production. No new logging added or needed (matches analog).
- **Performance:** one `document.cookie` read + small array scans per auth-page render; negligible. No new queries; org `#create` gains 8 in-memory assignments on the same INSERT.
- **Ops of the branch:** single clean commit; only unstaged `db/schema.rb` drift remains in the tree (deliberate). Nothing else operational (no env vars, no cron, no queue changes).

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
