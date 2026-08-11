# Test Coverage (always-on) — Round 2

Also carries the always-on check **Test coverage** from REVIEW-ANGLES §4 (folded here, as in round 1).

## Suite executed against COMMITTED code (independent run — did not trust the orchestrator's claim)

Clean worktree at HEAD `68e5e6a4e`. Ran 12 files (round-1's 11 + develop's new `create_bulk_ai_summary_generation_spec.rb`):

**140 examples, 9 failures.** The 9 failures are EXACTLY the known pre-existing `on_complete` NoMethodError set in `bulk_generate_ai_summaries_job_spec.rb` — identical example lines to round 1 (:158, :195, :220, :244, :284, :308, :336, :354, :380), identical error (`undefined method 'on_complete'` for the job instance). Re-attribution at the new base: develop's diff (05c9513ef..639458b9d) did NOT touch this spec file, and the file is byte-identical to the feature parent at HEAD — so the merge neither fixed nor changed them; still pre-existing, still out of scope. Every feature example passes, as do develop's new rescore examples and all merge-reconciled examples.

## Merge-authored spec reconciliations (unreviewed until now)

1. **`bulk_ai_job_application_summaries_controller_spec.rb`** — `rescore_requested:` added to every request (the param is `require`d since PR #3054); the all_stages interactor expectation became `params: hash_including('rescore_requested' => 'true')` while KEEPING the feature's `job: kind_of(Job)`. Correct against the merged controller contract; all examples pass. Note: develop's own copy of this spec (639458b9d) posts without the required param in 4+ examples and fails UPSTREAM — the merge reconciliation is what makes them pass here (see bulk-claim-row-and-queue-signature.md note).
2. **`queue_bulk_ai_summary_jobs_spec.rb`** — the job-less zero-criteria example now passes `params: { rescore_requested: false }` (required by the interactor's success path post-#3054); the fail-fast example correctly passes NO `params` (guard fires before the params read — this doubles as proof of the guard's ordering). Both still test what they claim.
3. **`textract_result_ai_trigger_spec.rb`** — waiting-summary context gained `job_application.reload` with a reasoning comment. **Comment verified accurate:** JobApplication creation runs `enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status` → `FindOrCreateAiJobApplicationSummaryStatus`, which reads `@job_application.latest_ai_job_application_summary` (find_or_create_ai_job_application_summary_status.rb:62) — caching the has_one as nil on the spec's instance BEFORE `waiting_summary` exists. Develop's unified lookup (textract_result.rb:126) reads that association, so without the reload the manual-waiting branch would never be exercised. The examples still test what they claim: assertions remain behavioral (enqueue with `requesting_organization_user_id`; destroy + `AI_SUMMARY_FAILED` broadcast) with no stubbing of the lookup itself. Both pass.

## Ghost-test hunt (rule 26)

Round-1 audit stands for the unchanged files. The merge-added spec lines audited fresh: no reflection-only assertions, no assigned-but-unasserted variables; the reload is setup, not an assertion substitute. No ghost tests.

## Findings

- F1 [LOW — carryover from round 1, unchanged] spec/jobs/extract_job_criteria_job_spec.rb / the `retry_on` exhaustion-block broadcast site still has no direct test / matches the adjudicated SPEC §12 / plan E.2.6 test plan; residual plan gap, not an implementation omission / optional hardening unchanged from round 1.

No MED+ findings.
