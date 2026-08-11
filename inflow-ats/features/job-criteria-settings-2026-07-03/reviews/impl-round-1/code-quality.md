# Code Quality (always-on) — Round 1

Naming, structure, readability, convention adherence per cursor_rules (full rules matrix in cursor-rules-compliance.md).

## Positives verified

- Record variable naming exact throughout app code (`ai_job_criteria`, `new_ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status`).
- Frontend state naming (`isPayloadStatusInFlight`, `isInFlight`, `displayState`, `aiJobCriteriaPayload`) is unambiguous; `displayState` union type makes the 8.2 table legible in code.
- Styled components labeled (`label: JobCriteriaSection_…`), one per variant, codebase `let Styled: any; Styled = {};` idiom followed.
- Sidebar register mirrors `AccountTeam.tsx` styled analog nearly token-for-token.
- Spec files reuse each target file's existing harness and local conventions.

## Findings

- F1 [LOW — NOTED, NOT COUNTED per round directive] app/jobs/extract_job_criteria_job.rb:45 / `ai_job_criteria.reload` in `broadcast_completion` conflicts with `cursor_rules/backend/_base.md` §8 (no `reload` in app/) / SPEC §7-verbatim and functionally required (ExtractCriteria writes status via `update_columns` on a different in-memory instance); plan R-1 binds this to the dedicated Phase 6.5 conventions pass, where the rule-compliant one-liner (`AiJobCriteria.find_by(id: …)` + nil guard, the analog's re-query pattern) is already recorded / No action this round; the conventions pass owns the call.
- F2 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:10-14 and components/JobCriteriaSection.tsx:17-21 / the `TIERS` constant (keys, labels, icons) is duplicated verbatim in two files / a divergence in one copy would silently desync the card rail from the slide-over grouping / Recommended: export `TIERS` from one module (e.g., the hook file next to `AiJobCriterion`, or the section) and import it in the other. Cosmetic; plan F.3.1.4 only required "the same TIERS shape".
- F3 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:42 / section-intro description link is `<a onClick={…}>` with no `href` — not keyboard-focusable/announced as a link / spec asked for an inline link navigating via `history.push`; the behavior is right, the element is an a11y nit / Recommended (optional): `href` + preventDefault, or a text-style button. Do not change navigation mechanics.
- F4 [LOW] app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:35 / file still ends without a trailing newline (pre-existing; the diff preserved it) / "respect Prettier & linter" general principle / add trailing newline whenever the file is next touched.
- F5 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx:63-70 / surfaced analog attribute deviations on the primary button vs `BulkGenerateAiSummariesConfirmModal.tsx:152-160`: `type="button"` vs `type="submit"`, missing `size="medium"`, missing `className="submit-button"` / no behavioral difference (no `<form>` present in either modal; both behavioral props `loading`/`disabled` ARE copied); surfaced per the surface-all-deviations rule / optional alignment only if Jessica wants byte-level analog parity.

No MED+ findings.
