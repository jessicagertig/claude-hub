# Bulk claim-row lifecycle fix and QueueBulkAiSummaryJobs signature extension — Pass 2

## Pass 1 correction verified
**F1 (HIGH) amendment applied correctly.** Re-read plan.md:268-276: E.4.6 now (a) names BOTH lines :59-60 as the replacement target, quoting each; (b) states the snippet is the FINAL state of the region; (c) adds "exactly ONE `ValidateAiSummaryGeneration.call` must remain in `each_iteration`" with the side-effect rationale citing validate_ai_summary_generation.rb:39/:55 (both verified to be the `SubmitResumeToTextractJob.perform_later` enqueues). No literal reading now produces a duplicated validator call. The snippet itself is unchanged and remains byte-identical to SPEC 6.3's.

## Correction introduced no new inconsistencies
- `grep "return unless result.success?" plan.md` → only the amended E.4.6 wording (describing the replaced line) — no stale copies elsewhere.
- `ValidateAiSummaryGeneration.call` appears 3× in the plan, all within E.4.6 (prose, snippet, guard sentence) — consistent.
- E.4.7.6 (spec: validation-failure iteration → row `:failed`, completion notification fires) and §H's load-bearing-case list still describe the amended behavior exactly.
- Flag 6 framing ("MINIMAL — nothing else in this file changes") preserved; the amendment tightened, not widened, the change surface.

## Fresh scrutiny
- Re-read E.4.3/E.4.4/E.4.7.3/E.4.7.4: `job` input optional via `context.job&.` ✓ flag 7; both controller call sites verified again (:13-17, :37-43 with `@job` at :9/:33); the `hash_including` expectation exists today only for `all_stages` (:71-78) and the plan correctly says "add the equivalent assertion for `create`" rather than "update" a nonexistent one.
- Fresh check on the fix's failure-mode coverage: rows set `:failed` by E.4.6 are excluded from `QueueBulkAiSummaryJobs`' `:processing` claim filter (:45-49), so previously-poisoned candidates become re-queueable on the next run — the flag-6 rationale holds in code.
- Fresh check: `on_complete` reads statuses fresh from the DB (`BulkAiSummaryJobApplication.where(bulk_job_id: ...)`), so `:failed` rows count via `size - done - deferred` (:111) with no other change needed.

## Completeness re-sweep (SPEC §6.2.3/§6.3/§12)
All present: fix, signature extension, controller pass-through, three spec files' new contexts (including the job-less-call optionality assertion). Nothing dropped.

## Findings
No new issues found.

## Amendments Applied
None (Pass 1 amendment stands verified).
