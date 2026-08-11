# analog-structural-matching — Round 2 (always-on check)

Structural (not just layer-level) diff of the new code against the analog's shapes, with the five approved deviations from REVIEW-ANGLES.md's Priority rule excluded:

- **Capture shape:** `React.useState(sanitizeTrackingParams(location.search))` vs analog `React.useState(queryString.parse(location.search).referral)` — same eager-initializer, same component position, setter omitted exactly like the adjacent `const [partner]`. The sanitize-wrapper is the D4-mandated difference. MATCH.
- **Payload shape:** four top-level camelCase fields beside `referral`/`partner` in the same variables objects. MATCH.
- **Hidden-input guards:** `typeof x === "string" && x.length > 0` — byte-identical to the `referral`/`partner` guards; `utm_data` per-key inputs apply the same guard per key (spec-specified extension for the map case). MATCH.
- **Setup lambda:** single-array-membership change; loop, session write, logging untouched — the analog's own mechanism reused, not reimplemented. MATCH.
- **Callback recovery:** string-key reads from the same `merged_tracking` hash the analog reads `partner`/`referral` from. MATCH.
- **Creation-time-only assignment:** inside the same `first_or_create` block as `created_via`/`partner_source`; raw assignment is approved deviation 1 (D3). MATCH (keyword signature = approved deviation 2/D9).
- **Org copy:** `@organization.<col> = current_user.<col>` — identical statement shape, same position (pre-`authorize`), as the `created_via` analog. MATCH.
- **jsonb permit:** trailing `utm_data: {}` — the `questions_controller.rb` `options: {}` form, trailing argument. MATCH.
- **Migration shape:** analog file's structure minus defaults (approved deviation 5/D6). MATCH.
- **onSuccess event placement:** plain `trackEvent` before `onComplete` inside the existing component-level callback — the `NewJobCenterModal.tsx:47`/`CommentTemplateModal.tsx:100` shape (browser-side is approved deviation 3). MATCH.
- **Identify shape:** `identifyUser({ id, email })` → `ph.identify(String(user.id), ...)` — same helper, same distinct_id derivation as `AppAuthRouter.tsx:168`. MATCH.
- **No retry/exhaustion/callback patterns in scope:** no jobs or model callbacks added — nothing to compare.

## Findings

No issues found. No structural mismatch outside the five spec-mandated deviations.
