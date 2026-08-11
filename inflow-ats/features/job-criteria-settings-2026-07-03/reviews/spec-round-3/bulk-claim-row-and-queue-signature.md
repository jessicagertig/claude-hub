# Round 3 — Angle 2: Bulk claim-row fix and queue signature (flags 6/7)

SPEC.md re-read at round start. Sections 6.3/6.2.3 and related test-plan entries unchanged since Round 1 verification; fix remains minimal; flags 6/7 honored.

**Round-3 input from the orchestrator (cross-validating reviewer), independently verified:**

- F1 evidence: SPEC §2 read "1 job change (`ExtractJobCriteriaJob`)" while §13's modified-files table correctly lists BOTH `app/jobs/extract_job_criteria_job.rb` AND `app/jobs/bulk_generate_ai_summaries_job.rb` (the §6.3 claim-row fix). Verified by reading both sections — §2 was internally inconsistent with §13 (and with the blast-radius file, which was already correct). Doc-consistency defect only; no behavioral content wrong.

Also noted (relates to this angle's file): the funnel-guard race documented this round in §6.2.4 (Angle 1 F1) has a bulk expression — claim row `:done` with nothing run (bulk_generate_ai_summaries_job.rb:86) — now covered by the §6.2.4 amendment; no change to §6.3 itself (the claim-row fix stays exactly as specced).

## Findings

- F1 [LOW] SPEC §2 stack-scope line undercounted job changes ("1 job change") vs §13's two modified job classes. Fix: §2 corrected to "2 job changes" naming both.

## Amendments Applied

1. §2 corrected: "2 job changes (`ExtractJobCriteriaJob` signature + broadcasts; `BulkGenerateAiSummariesJob` claim-row fix, Section 6.3)" (F1). Patched line re-read and verified.
