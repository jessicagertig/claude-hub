# analog-structural-matching (always-on check) — Round 1

Structural (not just layer-level) diff of new code against the analog's shapes, per REVIEW-ANGLES. Approved deviations (raw storage vs downcase/mapping, keyword `from_omniauth`, browser-side events, raw `utm_data` inner keys, no-default migrations) excluded per the Priority rule.

- **State-capture signature:** analog `React.useState(queryString.parse(location.search).referral)` — value computed inline, no setter used for partner. New: `React.useState(sanitizeTrackingParams(location.search))` — same eager-compute-into-initial-state shape, destructured without setter like `partner`. MATCH.
- **Payload-field shape:** analog passes bare identifiers (`referral,`/`partner,`); new passes explicit property reads (`utmSource: trackingParams.utmSource,` …) — necessary because the four live inside one state object (plan-level state-shape choice the spec explicitly delegated). Wire result identical in kind (optional scalar fields + one object field). MATCH (sanctioned shape difference).
- **Hidden-input guards:** analog `{typeof referral === "string" && referral.length > 0 ? (<input .../>) : null}` — new inputs use the identical guard text, per-key for `utm_data` with the house `!= undefined` outer absence guard. MATCH.
- **Controller parameter interface:** the new params ride the SAME permit method and the SAME `user_params` merge structure in both branches, sourced from `sign_up_params` exactly like the analog values (minus the approved no-downcase deviation). The jsonb hash-permit uses the `questions_controller.rb:50` trailing `options: {}` form. MATCH.
- **`first_or_create`-block-only assignment:** new assignments sit inside the block alongside `created_via`/`partner_source`, none outside — identical creation-time-only semantics. MATCH.
- **Copy-at-org-create:** four direct setters immediately adjacent to the analog `created_via` setter, before `is_claimed`/`authorize`. MATCH.
- **onSuccess event placement:** analog `NewJobCenterModal.tsx` fires `trackEvent` inside the component-level mutation onSuccess after the logger, before completion side effects; `CommentTemplateModal.tsx` shows the plain no-property call form. All five new events follow exactly (logger → trackEvent → onComplete). MATCH.
- **Identify shape:** `identifyUser({ id: Number(id), email })` produces distinct_id `String(user.id)` — identical to the `AppAuthRouter.tsx:168` identify's keying (verified in `posthog.ts:32`). MATCH.
- **Session-ride mechanics:** untouched analog code; only the whitelist array grew. MATCH.
- **Migration shape:** plain `add_column` per the `20260622182504` analog, minus its `default:/null:` options — the approved D6 deviation. MATCH.
- **No jobs/callbacks/retry surfaces:** the feature adds no jobs or model callbacks, so the analog retry/exhaustion and `after_commit` patterns have no application here (verified: zero job/model-callback diff).

## Findings

No issues found.
