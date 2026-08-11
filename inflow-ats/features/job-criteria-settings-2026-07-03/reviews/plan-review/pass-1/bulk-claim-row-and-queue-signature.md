# Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature extension (flags 6/7) — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| E.4.6: `return unless result.success?` at bulk_generate_ai_summaries_job.rb:60 | grep -n | ✓ exact; `result = ValidateAiSummaryGeneration.call(...)` sits at :59 |
| Sibling row-writes `update_columns` at :54, :66, :86 (P20) | grep -n | ✓ all three, all `job_application_bulk_job_status.update_columns(status: ...)` |
| Not inside a transaction (pipeline rule 25) | Read `each_iteration` :31-90 | ✓ no transaction block anywhere in the method |
| `on_complete` counting `failed = size - done - deferred` at :111 | grep -n | ✓ :111; rows set `:failed` count identically to rows left `:processing` |
| All-failed batch still fires `notify_failure` (`succeeded.zero? && failed.positive?`, :117-119) | grep -n | ✓ :117 |
| `update_remaining_statuses_to_failed` fires only on discard_on/retry_on exhaustion (:12-21) | Read file head | ✓ :12-21 |
| Fix is MINIMAL — no new statuses, no enum change, no notify_* rewrites | E.4.6 text ("nothing else in this file changes") | ✓ matches flag 6 ruling |
| E.4.3: `job` input optional via `context.job&.` safe-nav | E.4.3 snippet | ✓ matches flag 7 ruling; existing callers without `job:` unaffected |
| E.4.4: `@job` exists at bulk controller :9 (create) and :33 (all_stages); `.call` sites :13-17 and :37-43 | Read controller | ✓ all four citations exact |
| E.4.7.4: `hash_including` interactor expectation at spec :72-77 | Read spec :50-90 | ✓ the `expect(QueueBulkAiSummaryJobs).to receive(:call).with(hash_including(...)).and_call_original` block sits at :71-78; adding `job: kind_of(Job)` is well-formed there. Only `all_stages` has this expectation today; plan correctly says "add the equivalent assertion for `create`" |
| Spec harness P17 (:5-49) | Read spec | ✓ credit-test helpers, Flipper enable, auth stubbing, ActiveJob test adapter around block all present :5-49 |

## Completeness (vs SPEC §6.3, §6.2.3, §12)

- SPEC 6.3 claim-row fix → E.4.6 ✓ (snippet identical to SPEC's)
- SPEC 6.2.3 `job` input + fail after credits fail → E.4.3 ✓ (message byte-identical to site 1)
- SPEC: bulk controller passes `job: @job` in BOTH actions → E.4.4 ✓
- SPEC 12: queue_bulk spec zero-criteria context + job-less-call assertion → E.4.7.3 ✓
- SPEC 12: bulk controller spec hash_including update + 422 per action → E.4.7.4 ✓
- SPEC 12: bulk job spec validation-failure row `:failed` + completion notification still fires → E.4.7.6 ✓

## Findings

- F1 [HIGH] **E.4.6 replace-instruction produces a duplicated `ValidateAiSummaryGeneration.call` under a literal reading.** Where: plan.md E.4.6. What: the instruction says "replace `return unless result.success?` (:60) with:" and then gives a 5-line snippet whose FIRST line is `result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)` — but that line already exists in the file at :59 and is not part of what the instruction says to replace. A literal implementer replaces only :60 and ends up with the validator called TWICE per iteration. `ValidateAiSummaryGeneration` has side effects: it enqueues `SubmitResumeToTextractJob.perform_later` on the no-textract and failed-once paths (validate_ai_summary_generation.rb:39, :55) — a duplicate call double-enqueues Textract submissions and doubles the `ap` log spam for every bulk iteration. Evidence: bulk_generate_ai_summaries_job.rb:59-60 vs the E.4.6 snippet. Fix: reword E.4.6 to state that lines :59-60 together are replaced by the snippet (the snippet is the FINAL state of that region, matching SPEC 6.3's framing), so exactly one `ValidateAiSummaryGeneration.call` remains.

## Amendments Applied

- plan.md E.4.6: replaced "claim-row fix (flag 6, APPROVED as reviewed scope; MINIMAL — nothing else in this file changes): replace `return unless result.success?` (:60) with:" with wording that makes the snippet the final state of lines :59-60 and adds an explicit "exactly ONE `ValidateAiSummaryGeneration.call` must remain" guard sentence.
