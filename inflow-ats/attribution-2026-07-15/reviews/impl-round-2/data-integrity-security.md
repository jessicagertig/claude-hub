# data-integrity-security — Round 2 (always-on impl angle)

- **Mass assignment:** the four params enter only through `sign_up_params` permit on the unauthenticated signup paths where they are user-supplied by design; `organizations#create` never reads them from the request (`organization_params` unmodified; tamper case pinned by spec). No other write path exists.
- **Authorization:** no endpoint/policy changes; `authorize @organization` unchanged and still runs after the resource is fully built; confirmations stay token-authenticated via `User.confirm_by_token`.
- **Injection/XSS:** values are assigned via ActiveRecord parameter binding (no SQL string building); never rendered in any view or serializer (zero serializer diffs; `git grep` confirms no exposure) — stored-raw XSS risk is inert until some future surface renders them, at which point standard escaping applies.
- **Data consistency:** nil-for-absent enforced end-to-end (no jsonb defaults; undefined keys drop from JSON; `sign_up_params[<key>]` nil); creation-time-only assignment means no update path can corrupt existing attribution; org copy is a same-transaction attribute set before `save`.
- **Unbounded input:** direct API callers bypass the client-side 255-char/10-key caps and can store arbitrarily large `utm_data` — accepted property of the approved no-server-sanitization design (spec Risks 2/4; REVIEW-ANGLES forbids re-litigating). Not flagged.
- **PII:** the confirmed email now appears in the redirect URL query string (browser history, request logs) — D12-specified, spec Risk 6. Not flagged.

## Findings

- F1 [LOW — recorded in Round 1, decision-bound, no fix required] `/auth?email_confirmed=true&id=<n>&email=<x>` is an unauthenticated public URL: anyone can craft it with an arbitrary id/email pair and, in their own browser, fire `identifyUser` + `email_verified` — polluting PostHog identity graphs and inflating the funnel step (including the `ph.identify("NaN")` variant for non-numeric ids). Inherent to the D12 browser-side mechanism the spec mandates; PostHog data is analytics, not authorization — no privilege impact. Concurs with Round 1's recorded finding.

No BLOCKER/HIGH/MED findings.
