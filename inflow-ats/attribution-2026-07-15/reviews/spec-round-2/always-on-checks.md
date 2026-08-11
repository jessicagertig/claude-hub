# always-on checks — Round 2

## Source accuracy

Round-1 amendment claims were themselves audited this round (the round's principal work). One factual error found and corrected (§5.6 timing rationale — see posthog-events-and-identity F1). All other round-1 amendment facts re-verified against source: query-string 6.1.0 parse sort + extract export + array-order behavior; actionpack 6.1.7.7 `as_json` delegation; `registrations_controller.rb:81/88–97` login_intent default and nil-`organization.id` branch; `bulk_ai_job_application_summaries_controller_spec.rb:7` include precedent; `posthog-js` 1.297.4 synchronous `__loaded`. New source facts pinned: `useOrganization` (no `enabled`; `getOrganization` guard), `useGetMe` (`enabled` passthrough), react-query 3.13.10, routes `/auth`→`Auth`, `/register`→`handleRegisterRoute`→`Signup` (renderProps spread carries `location`), no `StrictMode` in `app/javascript`.

## Test coverage

Two MED gaps found and amended (unconfirmed-branch not-modified test; preamble/per-file-include coherence). Ghost-test audit unchanged from round 1; the new bullet is falsifiable (fails if a branch-specific write appears).

## Backward compatibility

No new consumers discovered: `GoogleSSOButton` single render site; `email_confirmed` readers unchanged; `useOrganization`'s missing `enabled` gate documented in §5.6 as the incidental property the mechanism must not depend on (and now doesn't).

## Full-stack analog completeness

Unchanged from round 1 — all ten layers spec'd; no layer lost in the round-1/round-2 amendments.

## Analog structural matching

Unchanged from round 1 — per-key input guard now analog-identical; no structural deviations beyond the five approved ones.
