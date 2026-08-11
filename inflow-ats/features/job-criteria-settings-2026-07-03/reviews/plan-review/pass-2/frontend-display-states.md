# Frontend display-state derivation, loading states, payload contract — Pass 2

## Pass 1 corrections in this angle's scope
None were required.

## Fresh scrutiny
- Re-read F.1.1, F.2.1, F.2.2 and D-1..D-5/D-7 in the amended plan: unchanged; no new inconsistencies.
- **Orchestrator-mandated re-verification:** F.2.1.3's table gives failed states (priorities 2/3) precedence over the criteria-present card (priority 4) — a failed latest row renders the failure/zero-found empty state even when an older succeeded row exists. Searched the amended plan again for any "show latest successful when latest is failed" display behavior: the only "older succeeded" mentions are (a) the serializer payload contract rows (correct — the `criteria` FIELD carries the older succeeded row's content while the DISPLAY shows the empty state) and (b) the flag-5 "implement, don't improve" warning. Clean.
- Fresh check: `Button` component accepts `loading`, `disabled`, `styleType` (components/shared/Button/index.js:17-19) — every button prop the plan prescribes exists.
- Fresh check: `LoadingIndicator` exists at `components/shared/LoadingIndicator` (imported exactly so by the P12 analog).
- Fresh check: D-7's "Criteria tiers" sidebar title verified in the decided design (bundle-1 README.md:54, JobSetupPlatoAI.jsx:230) — DECISIONS' "copy per decisions.html wording" satisfied; bold leads remain DECISIONS-verbatim where the two sources differ, per the DECISIONS-wins rule.
- Fresh check: state-1's underlying-content rule ("state-4 card if criteria present, else state-5 EmptyState") cannot render states 2/3 underneath — with an in-flight latest row, `status` is not "failed" and `zeroCriteriaFailure` is false (predicate reads the latest row) — matches SPEC 8.2 row 1's parenthetical exactly.
- Fresh check: F.2.1.2's counts computed only inside the state-4 card where `criteria` is known present — no `|| []` anywhere; core 10 / pipeline 13 hold.

## Completeness re-sweep (SPEC §8.1-8.3, §12-13)
All present: hook verbatim; six states + copy verbatim; action-row placement (D-2); loading mandates (initial LoadingIndicator + backend-status-driven button loading, D-5); card visual specs; TIERS constant; sidebar glossary + layout-change verification step; extraction decision (D-1); no frontend tests documented. Nothing dropped.

## Findings
No new issues found.

## Amendments Applied
None.
