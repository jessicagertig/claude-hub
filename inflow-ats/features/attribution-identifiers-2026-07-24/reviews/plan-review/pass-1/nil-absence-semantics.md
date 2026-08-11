# Plan review pass 1 — nil-absence-semantics

Reviewed: plan.md T4k, §7 first bullet, the T4 snippet's guard structure against SPEC §5.1/§8.1/§8.6 and core rules 9/10.

## Fact checks performed

- Every T4 field block is guarded (`!== undefined` on cookie lookups, `typeof x === "string" && x.length > 0` on the conditional URL-first rules, `length > 0` on the `_ga_*` filter) and only assigns `trackingParams.<field>` inside the guard — no `|| ""`, `|| null`, `|| {}` anywhere in the snippet. `getCookieValue` returns `undefined` (not null) for a missing cookie; empty-value cookies are dropped in `getCookieEntries`.
- `fbc` never-fabricate (§8.6): construction branch requires `_fbc` absent AND a genuinely non-empty first-occurrence fbclid string — verified against installed query-string v6.1.0 behavior (`?fbclid`→null, `?fbclid=`→"" — neither passes the guard).
- Backend nil chain verified in live code: absent JSON field → `sign_up_params[<key>]` nil (permit at :312); unrendered hidden input → key absent from `tracking_params` (omniauth.rb:17-20 only adds non-empty values) → `merged_tracking['<key>']` nil → nil-defaulted keyword (user.rb:379 pattern) → nil column; org copy of nil user column → nil org column (organizations_controller.rb:32-36 pattern). Plan §7 states this chain correctly.
- One nuance checked and cleared: a valueless `?fbclid` produces `trackingParams.fbclid = null` (through `sanitizeTrackingValue`'s non-string passthrough) — identical to the analog's existing `adct` behavior at utils.js:68-70, and SPEC §4 mandates "the same handling `adct` gets." JSON null → nil column. Not a fabrication; not a deviation.
- The existing-fields guard structure (utils.js:59-70) is untouched by the T4 insertion point.

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
