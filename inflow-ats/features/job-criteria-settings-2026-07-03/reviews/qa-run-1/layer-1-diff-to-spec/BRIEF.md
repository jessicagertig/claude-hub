# Layer 1 Diff-to-Spec — Shared Agent Brief (qa-run-1)

## Repo and diff

- Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings-qa`, HEAD `9ed954142`)
- The implementation diff: `cd /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings && git diff develop...HEAD`
- 33 changed files (+1679/−21). Scope your reads to your assigned area but you may read anything.

## Authority chain (highest wins)

1. `DECISIONS.md` (working dir: `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/`) — wins over every design file.
2. `SPEC.md` (same dir) — §7 was amended post-conventions-pass: the fresh-read form of `broadcast_completion` (`AiJobCriteria.find_by(id: ...)` instead of `reload`) IS the spec as written today. Read the spec as it stands on disk.
3. `reviews/plan-review.md` (Reviewed Plan section) and `plan.md`.
4. ORCHESTRATION-LOG.md proxy rulings and conventions-pass rulings (below) — implementations must MATCH these rulings. Do NOT re-adjudicate them.
5. `reviews/REVIEW-ANGLES.md` — background on review angles.

## Adjudicated rulings — matching implementations are NOT findings

Flags 1-7 (approved by the human-gate proxy, recorded in ORCHESTRATION-LOG.md):
1. `requesting_organization_user_id:` kwarg on `Job#extract_job_criteria_immediately` (SPEC §4.1).
2. Third zero-criteria message `'Criteria array is empty'` in `ZERO_CRITERIA_ERROR_MESSAGES` (SPEC §4.2).
3. Completion broadcast fires on failure too, not only success (SPEC §7).
4. `ExtractJobCriteriaJob` optional POSITIONAL second arg (NOT kwargs like the analog) — resolved: positional stands; kwargs cutover would break in-flight Sidekiq payloads.
5. Display precedence: failed latest row renders the failure/zero-found empty state over an older succeeded card (SPEC §8.2 rows 2/3 beat row 4).
6. `BulkGenerateAiSummariesJob#each_iteration` claim-row fix: validation failure → row `:failed` (SPEC §6.3) — in-spec reviewed scope.
7. Optional `job` context input on `QueueBulkAiSummaryJobs` (SPEC §6.2.3).

Develop-merge repair (documented in ORCHESTRATION-LOG.md "develop merge" rows — do not flag): test-only edits in `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb` adding `rescore_requested` to pre-existing examples and reshaping `params:` expectations. Develop's PR #3054 made `rescore_requested` required but left its own examples stale (red upstream); this branch repaired them during the merge. Already flagged to Jessica in the orchestration log. Adjudicated by the QA orchestrator: traceable, not a finding (ruling on round-1 agent-4 finding).

Conventions-pass no-fix rulings (do not flag):
- `ai_job_criteria_controller.rb#create` renders the current payload with no interactor/result branch — adjudicated idempotent design per SPEC §5.2.
- `RegenerateJobCriteriaConfirmModal` owns its own mutation (not `ConfirmationModal`, not parent-owned) — adjudicated rule-22 analog pattern.

Conventions-pass fix batch (commit `9ed954142`; full text in `reviews/conventions-pass/CONVENTIONS-FAILURE-REPORT.md`) — these 8 changes trace to that adjudicated report and are IN-SPEC (they are spec extension, not untraceable diff):
1. Fresh-read lookup in `broadcast_completion` (also now in SPEC §7 itself).
2. `Rails.logger.error` line in `bulk_generate_ai_summaries_job.rb` validation-failure branch.
3. Shared tier metadata constant file `app/javascript/ats/src/views/jobApplications/jobSetup/jobCriteriaTiers.ts`, consumed by both `JobSetupAiSettings.tsx` (sidebar) and `JobCriteriaSection.tsx` (replacing local `TIERS`).
4. Query error state in `JobCriteriaSection.tsx`: on `isError`, failure-style EmptyState, title "Could not load job criteria", message "Something went wrong while loading job criteria. Refresh the page to try again.", NO action buttons; priority after `isLoading`, before payload states.
5. `border-radius` raw values → `${t.rounded.sm}` / `${t.rounded.md}` tokens.
6. Raw font-sizes → standalone `${t.text.sm}` / `${t.text.xs}` / `${t.text.base}` utilities.
7. `font-weight: 450` → `${t.text.medium}`.
8. Focus rings on `JobCriteriaViewModal` CloseButton and `JobCriteriaSection` SectionIntro `a`.

## Layer 1 rules

- **Every finding is HIGH.** No MED, no LOW, no "close enough", no "functionally equivalent".
- **Spec-to-diff:** every assigned spec requirement must have corresponding code in the diff. Missing = finding.
- **Diff-to-spec:** every change in your assigned area must trace to SPEC / DECISIONS / Reviewed Plan / an adjudicated ruling above. Untraceable = finding; report the FULL scope (every method/path, not one line).
- **Behavioral correctness:** for each mapped pair, read the code and confirm it does what the spec says. Don't just check the file was touched.
- **Constraints/edge cases:** verify the spec's edge cases for your area.
- **Ambiguity:** genuinely ambiguous spec → finding with a note.
- Read code in the worktree at the paths in the diff. Do NOT modify anything anywhere — you are read-only except for your one output file.

## Output

Write EXACTLY one file: `/Users/jessica/claude-hub/inflow-ats/features/job-criteria-settings-2026-07-03/reviews/qa-run-1/layer-1-diff-to-spec/round-{N}/agent-{M}.json` (N and M given in your dispatch prompt).

```json
{
  "layer": "diff-to-spec",
  "round": 1,
  "agent_index": 1,
  "focus_area": "...",
  "findings": [
    {
      "id": "l1-a{M}-001",
      "type": "VIOLATION",
      "title": "...",
      "spec_requirement": "SPEC §x.y: ...",
      "evidence": "file:line — what the code actually does",
      "recommendation": "..."
    }
  ],
  "spec_coverage": {
    "requirements_checked": ["SPEC §4.1", "..."],
    "implemented": 0,
    "missing": 0,
    "notes": "..."
  }
}
```

Empty findings array if your area fully matches. Your final chat message: one-paragraph summary + finding count.
