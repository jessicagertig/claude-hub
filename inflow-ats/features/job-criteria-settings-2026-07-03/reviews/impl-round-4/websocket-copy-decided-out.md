# WebSocket Handler, Copy Rules, Decided-Out Absence — Round 4

Round scope: `WebsocketGlobalChannelHandler.tsx` and `aiSummaryWebsocketPayloads.ts` are NOT in the fix commit (verified via `git show --stat`) — rounds 2-3 findings stand. This angle's round-4 work: the copy-rules sweep over the strings the fix commit introduced or relocated, and re-running the decided-out absence greps over the fix commit.

## Copy sweep of fix-commit strings

New user-facing strings (fix 4): `"Could not load job criteria"`, `"Something went wrong while loading job criteria. Refresh the page to try again."` — sentence case, no em dashes, no emoji, no "read", no weight/heaviest language, static (no interpolation). PASS.

Relocated strings (fix 3, `jobCriteriaTiers.ts`): all six glossary strings + three labels byte-identical to the pre-fix JSX rendering (verified against `9ed954142^` — see frontend-display-states.md). "count most toward a candidate's score" / "count toward the score, less than core criteria" wording preserved exactly. PASS.

## Decided-out absence greps (re-run over `git show 9ed954142`)

- `guard|GuardTitle|GuardBody|GuardFoot` → 0 in the fix commit.
- `internal_job_criteria` → 0.
- `tier1|tier2|tier3` (bundle-style keys) → 0; the shared const keys are the stored `tier_1`-form.
- `TierHint` → 0.
- No test harness added; no frontend test files.

## Findings

No issues found.
