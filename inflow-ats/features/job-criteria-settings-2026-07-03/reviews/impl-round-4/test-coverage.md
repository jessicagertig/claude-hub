# Test Coverage (incl. always-on Test Coverage check) — Round 4

## Rule 15

Worktree clean, HEAD 9ed954142 verified before review start and re-verified after all runs. Committed code reviewed.

## Suite runs (all 11 REVIEW-ANGLES spec files, RAILS_ENV=test)

Five full-set executions performed this round:

| Run | Seed | Result |
|---|---|---|
| 1 | 11333 (random) | 135 examples, 13 failures — 9 pre-existing on_complete + 4 bulk controller #all_stages |
| 2 | 11333 (explicit, same order) | 135 examples, 16 failures — 9 pre-existing + 4 job_criteria_lifecycle + 3 ai_job_criteria_controller |
| 3 | 11333 | 135 examples, 9 failures — pre-existing set ONLY |
| 4 | 11333 | 135 examples, 9 failures — pre-existing set ONLY |
| 5 | 11333 | 135 examples, 9 failures — pre-existing set ONLY |

The 9 stable failures are line-identical to rounds 1-3 (:158, :195, :220, :244, :284, :308, :336, :354, :380, all `NoMethodError: undefined method 'on_complete'` in bulk_generate_ai_summaries_job_spec.rb) — the documented pre-existing out-of-scope set, unchanged by the fix commit.

## Adjudication of the run-1/run-2 instability

Investigated before concluding, since a new failure set on a fix-review round is exactly what this round exists to catch:
- Identical seed produced three DIFFERENT outcomes across runs 1-3 → not order-dependence; state external to the example ordering.
- Every intermittently-failing example passes in isolation (bulk controller spec alone: 8/8 green; lifecycle + criteria controller together: 3 consecutive runs 36/36 green).
- No concurrent Rails/puma/sidekiq/spring process was running (ps + lsof verified) — no live test server writing to the DB.
- The failures washed out monotonically (13 → 16 → 9 → 9 → 9) and never returned: consistent with stale test-database residue from a prior aborted/partial execution draining, not with a code defect.
- Mechanism attribution to commit 9ed954142 ruled out: the commit's runtime surface is one `Rails.logger.error` line (executes only in the bulk validation-failure branch) and a `find_by` replacing `reload` (executes only in `broadcast_completion`) — neither is reachable from the intermittently-failing examples (`#all_stages` controller actions, `extract_job_criteria_immediately` model examples, `#show` controller examples), and neither writes anything a transaction rollback would miss.

Recorded as F1 (LOW) below for visibility, not as a defect of this branch.

## Fix-commit test changes

- `bulk_generate_ai_summaries_job_spec.rb:74`: the single failing-validation double gains `error: 'validation failed'` — minimal, correct, and the only double that needed it (grep-verified). The example passes.
- `extract_job_criteria_job_spec.rb`: correctly NOT modified — the report's conditional ("update the broadcast test if it stubs/depends on reload") is a verified no-op: no reload stubbing exists; all broadcast assertions are behavioral (`GlobalChannel.broadcast_to`) and pass against the fresh-read implementation.
- No ghost-test patterns introduced (rule 26): the fix commit adds no new examples.

## Example-count note

Rounds 2-3 reported 140 examples; this round's identical 11-file list yields 135. The fix commit adds/removes zero examples (diff shows one stub-list line changed), so the prior rounds' runs must have included examples outside these 11 files (their verdicts do not record the exact command). All 11 REVIEW-ANGLES §1 spec files (3 new + 8 modified) are covered here; every feature example is green in the stable runs.

## Findings

- F1 [LOW] Test-suite runs 1-2 this round showed transient, non-deterministic failures (13 then 16, distinct example sets, same seed) that washed out to a stable 9-pre-existing baseline by run 3 and stayed stable through runs 4-5. Isolation runs green, no concurrent processes, no mechanism reachable from the fix commit. Evidence: scratchpad full-run-3/4/5 outputs. Environmental (stale test-DB residue); flagged for awareness because first-run-after-idle CI or pre-commit runs may show the same transient set.
