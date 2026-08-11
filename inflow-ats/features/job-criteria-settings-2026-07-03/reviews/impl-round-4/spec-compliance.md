# Spec Compliance (incl. Source Accuracy check) — Round 4

## SPEC §7 amendment verification (the round's one spec-side change)

The failure report's rider required the `broadcast_completion` sketch's `reload` line to become the fresh-read form with a one-line note, plus a stale-reference sweep of §7.

Verified in SPEC.md:
- The sketch now reads `# (amended post-conventions-pass per backend/_base.md §8; plan R-1)` followed by `ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)` / `return unless ai_job_criteria` — matches the shipped code in extract_job_criteria_job.rb:46-47 line for line (guard order, placement before the terminal-status check).
- Stale-reference sweep: grep of SPEC.md for `reload` finds only (a) the §7 exhaustion-block note, which was ALSO updated to describe the fresh-read form ("its fresh read `AiJobCriteria.find_by(id: ai_job_criteria.id)` would raise NoMethodError on a nil row" — consistent with the shipped `if ai_job_criteria` guard at the exhaustion site), and (b) two "survives reload" usages (§1, §8.2) that mean PAGE reload — not stale. Zero stale `ai_job_criteria.reload` references remain.

## Fixes-vs-spec cross-check

None of the 8 fixes contradicts a SPEC requirement: copy strings unchanged (SPEC 10 verbatim strings intact — verified byte-identical through the tiers-constant relocation); six-state table intact with the error state slotting above it (the report's ruling is an addition the SPEC's state table does not forbid — it governs payload-derived states, and `isError` means no payload); broadcast behavior identical in all reachable cases.

## Source accuracy (folded, per rounds 2-3 structure)

All file:line citations leaned on this round were re-verified at HEAD 9ed954142: extract_job_criteria_job.rb:46-47 (fresh read), bulk_generate_ai_summaries_job.rb:63 (log), :31 (`each_iteration(job_application_id, payload)`), job.rb:688-698 (latest readers unchanged), theme.ts:91-99/254-262/302-310 (token values), JobCriteriaSection.tsx:51-61 (error state), ui_styling.md rule 6, backend/_base.md §8.

## Findings

No issues found.
