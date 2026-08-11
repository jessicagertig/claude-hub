# posthog-events-and-identity — Round 2

Round-2 focus: stress-test the round-1 §5.6 amendment against source (per the prompt's amendment-correctness escalation rule) plus fresh sweep.

New verifications this round: `posthog-js` 1.297.4 module source (`this.__loaded=!0` set synchronously at the top of instance init — the two-effect mechanism's "after init" premise holds), `react-query` 3.13.10 (disabled query = idle, not loading), `useMe.ts` `useGetMe` (passes `enabled` through — idle on unauthed routes), **`useOrganization.ts` `useOrganization` (lines 104–118): NO `enabled` option** — the query runs with `organizationId` undefined; `getOrganization` (lines 26–35) short-circuits via `if (organizationId != undefined)` and resolves `undefined` immediately, but react-query v3 still reports `isLoading: true` on the first render. `AppAuthRouter` render gate `isLoadingUser || isLoadingOrganization` therefore shows `LoadingIndicator` on the first commit of EVERY fresh page load. No `StrictMode` anywhere in `app/javascript` (no dev double-fire concern).

## Findings

- F1 [HIGH — correction of round-1 amendment rationale] Round 1 F1 claimed `Auth.tsx` mounts in the same commit as `PostHogProvider` ("the /auth route renders in the first commit because useGetMe is enabled: false"), concluding the original mount-effect placement "would silently never fire in production." **That premise was wrong**: the ungated `useOrganization(undefined)` query makes `isLoadingOrganization` true on the first render, so `AppAuthed` renders `LoadingIndicator` in commit 1, `posthog.init` runs in commit 1's effect flush, and `Auth.tsx` mounts in a later commit — a mount-effect identify would *currently* fire. The round-1 BLOCKER severity was overclaimed; the true state is: the original design works today only by grace of an incidental loading gate (`useOrganization` lacking `enabled: organizationId != undefined` — a gate its sibling `useGetMe` already has, making the cleanup plausible). The two-effect mechanism adopted in round 1 is correct and strictly more robust — it does not depend on that incidental gate (the `setEmailConfirmed` re-render always commits after the initial effect flush containing `posthog.init`, in both worlds). / Fix applied: §5.6 timing paragraph rewritten with the corrected facts; mechanism unchanged. Recorded prominently for Jessica: a round-1 amendment's rationale was corrected in round 2; the spec'd mechanism itself was never wrong in either round.

## Fresh sweep (no new findings)

- Effect-order claim in the retained mechanism re-derived: query fetches start in child effects within flush 1; their promise resolution is a microtask that cannot preempt the synchronous remainder of flush 1 (which includes `posthog.init`); commit 2+ effects therefore always run with `__loaded` true.
- `GoogleSSOButton` has exactly one consumer (`AuthForm.tsx:120`) — no other parent needs the new props.
- No `StrictMode`: the `[emailConfirmed]` effect fires the pair exactly once per landing in dev and prod.
- `Number(id)` on a hand-tampered non-numeric `id` yields distinct_id `"NaN"` — analytics pollution only, same tamper class as a forged `email` param; inherent to the D12 URL-param design (accepted, Risk 6). LOW, no amendment.

## Amendments Applied

- SPEC.md §5.6 timing-facts paragraph rewritten (corrected rationale; mechanism, guard, event names untouched).
