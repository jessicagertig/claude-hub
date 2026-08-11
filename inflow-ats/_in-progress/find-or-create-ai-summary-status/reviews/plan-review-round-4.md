# Plan Review Round 4 — FindOrCreateAiJobApplicationSummaryStatus

**Verdict: PASS**

---

## Round 3 findings: verification

| ID | Severity | Was it fixed? | Notes |
|---|---|---|---|
| R3-F1 (HIGH) | Task 6 `validations` block still calls `described_class.create!` — fails after eager creation | FIXED | Updated plan now shows the `validations` block without the `described_class.create!(job_application: job_application)` line; it uses the eagerly-created record directly |
| R3-F2 (MED) | Task 2 Step 1 says "private/callback methods section" — factually wrong | FIXED | Task 2 Step 1 now says "near `enqueue_new_job_application` (around line 150)" with no mention of a private section |
| R3-F3 (LOW) | Task 8 verification commands assume dev-env state | No fix required — flagged as informational only; still informational |

---

## Fresh full pass

### angle-1: generation-flow-coverage

All three generation paths verified to converge on `generate_ai_summary_with_credit_flow`:

- Manual single: `GenerateAiJobApplicationSummaryJob#perform` (line 32) calls `textract_result.generate_ai_summary_with_credit_flow`
- Auto via Textract: `queue_ai_summary_job` → `GenerateAiJobApplicationSummaryJob` → same call
- Bulk: `BulkGenerateAiSummariesJob#each_iteration` (line 62) calls `result.textract_result.generate_ai_summary_with_credit_flow`

The plan places the new interactor call at line 69 of `textract_result.rb` (after the early return guard at line 68: `return if latest&.status_succeeded? && !latest.stale?`, before `generate_ai_summary` at line 70). This placement is correct — all three paths converge through this method, and all three will call the interactor.

Textract-pending window: after Task 4 removes `create_status_record` callback and Task 5 removes the line-54 `find_or_create_by`, the textract-pending path (`CreateAiSummaryGeneration` → `status: :textract_processing`) no longer creates a status record directly. The status record for those job applications comes from `enqueue_new_job_application` (Trigger A, fires at `after_commit :create`), which runs before any manual trigger. Window is closed.

CLEAN.

### angle-2: interactor-state-machine-correctness

Interactor code in Task 1 verified branch by branch:

- **Branch 1 (record exists, `ai_job_application_summary` nil):** `handle_existing` returns at `return unless summary`. `context.ai_job_application_summary_status = status_record` is set after the `if/else` block. No save or update. Correct.
- **Branch 2a (record exists, summary `status_succeeded?`):** `update_columns(status: 'regenerating')` — return value wrapped in `unless ... context.fail!`. `ai_job_application_summary_id` is NOT cleared. Denormalized columns not cleared. Correct. The string `'regenerating'` is valid — `update_columns` bypasses enum casting and writes the raw value, matching the established pattern in `update_summary_status_record` (which passes `status: 'current'` the same way).
- **Branch 2b (record exists, summary NOT `status_succeeded?`):** `update_columns(ai_job_application_summary_id: nil, status: 'none', score_percentage: nil, headline: nil, integrated_role_analysis: nil)` — return value wrapped in `unless ... context.fail!`. All three denormalized columns cleared. Correct.
- **Branch 3a (no record, succeeded non-stale summary exists):** `build_ai_job_application_summary_status` + sets association + populates three denormalized columns + `status: 'current'` + explicit `save`. Return value checked with `unless ... context.fail!`. Correct.
- **Branch 3b (no record, no succeeded non-stale summary):** `build_ai_job_application_summary_status` + `status: 'none'` + explicit `save`. Return value checked. Correct.
- Association check via `belongs_to` (`status_record.ai_job_application_summary`), never by ID column. Correct per spec Decision #5.

CLEAN.

### angle-3: removal-completeness

Actual codebase state verified via `git show`:

- `ai_job_application_summary.rb` line 27: `after_commit :create_status_record, on: :create` — PRESENT. Plan Task 4 Step 1 removes it. Correct.
- `ai_job_application_summary.rb` line 45: `def create_status_record` — PRESENT (at lines 45-47). Plan Task 4 Step 2 removes it. Correct.
- `create_ai_summary_generation.rb` line 54: single `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` — PRESENT. Plan Task 5 Step 1 removes it. Correct.
- `create_ai_summary_generation.rb` lines 72-74: block `find_or_create_by` + `status_record.regenerating = false` + `end` — PRESENT. Plan Task 5 Step 2 removes all three lines. Correct.
- Task 5 Step 3 grep covers `create_status_record`, `find_or_create_by.*AiJobApplicationSummaryStatus`, and `.regenerating` — adequate verification.
- `ai_job_application_summary_spec.rb`: zero references to `create_status_record`, `find_or_create_by`, or `AiJobApplicationSummaryStatus` — no test update needed for that file.

CLEAN.

### angle-4: analog-structural-matching

Analog `FindOrCreateOrgInterviewerInvite` verified:

- Context input: single named input (`context.job_application`). Correct.
- Context output: `context.ai_job_application_summary_status` set in all non-error paths (Branch 1: after `handle_existing`; Branch 2: after `handle_existing` or `context.fail!` raised; Branch 3: `status_record` returned from `create_new` and assigned). Correct.
- Build pattern: `job_application.build_ai_job_application_summary_status` — matches analog's `organization.invites.build(...)`.
- `context.fail!` on save/update failure: bare `context.fail!` (no keyword args). Matches analog pattern (analog also uses bare `context.fail!` on `@invite.save` failure).
- No `find_or_create_by`, `create`, or `create!` in the new interactor. Correct.
- Wrapper method in `JobApplication` is a one-liner calling `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`. Correct per spec Decision #6.

CLEAN.

### angle-5: save-return-value-handling

- `handle_existing` Branch 2a: `unless status_record.update_columns(status: 'regenerating')` → `context.fail!`. Checked.
- `handle_existing` Branch 2b: `unless status_record.update_columns(...)` → `context.fail!`. Checked.
- `create_new`: `unless status_record.save` → `context.fail!`. Checked.
- No `save!`, `update!`, or `create!` anywhere in the new interactor. Correct.
- `context.fail!` raises `Interactor::Failure`. Call sites (`enqueue_new_job_application` and `generate_ai_summary_with_credit_flow`) do not rescue it — propagates up per spec Decision #8. Intentional, consistent.

CLEAN.

### angle-6: trigger-a-new-application-path

Verified from actual `job_application.rb` (lines 151-159): `enqueue_new_job_application` currently ends with the Flipper-gated `SubmitResumeToTextractJob.perform_later(id)` block. Plan Task 2 Step 2's code block places `find_or_create_ai_job_application_summary_status` as the last line after the Flipper block, not inside it. Correct per spec Decision #7 — status record is created regardless of whether Textract processing is enabled.

Timing: `enqueue_new_job_application` runs in `after_commit :enqueue_new_job_application, on: [:create]` — outside any transaction. Status record save is safe.

CLEAN.

### angle-7: update_summary_status_record-interaction

`update_summary_status_record` is at lines 59-73 of `ai_job_application_summary.rb` and is `after_commit :update_summary_status_record, on: :update`. Plan Task 4 only deletes `after_commit :create_status_record, on: :create` (line 27) and `def create_status_record` (lines 45-47). `update_summary_status_record` is untouched. Correct.

Lifecycle sequence confirmed: (1) `enqueue_new_job_application` → interactor creates status with `status: :none`. (2) Generation starts → `generate_ai_summary_with_credit_flow` → interactor (Branch 1: no summary yet, no changes). (3) Generation completes → summary transitions to `succeeded` → `update_summary_status_record` fires → sets `status: 'current'` and denormalized columns. Sequencing is correct.

CLEAN.

### always-on: source accuracy

- `create_ai_summary_generation.rb` line 54: single `find_or_create_by` — confirmed PRESENT at line 54.
- `create_ai_summary_generation.rb` lines 72-74: block `find_or_create_by` + `status_record.regenerating = false` + `end` — confirmed PRESENT at lines 72-74.
- `generate_ai_summary_with_credit_flow` early return guard: at line 68 of `textract_result.rb` (not line 67 as the spec says, but the plan's Task 3 code block correctly shows line 68 context). The plan's Task 3 Step 1 description also correctly references "line 68." No issue.
- `AiJobApplicationSummaryStatus` model: `status` integer enum with `_prefix: true` (`none: 0, current: 1, regenerating: 2`). No boolean `regenerating` column. Confirmed from actual model file.
- `AiJobApplicationSummaryStatus` schema: columns `status` (integer, default 0), `ai_job_application_summary_id`, `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text). All match the plan's denormalized column references.
- `update_summary_status_record` preserved at lines 59-73: confirmed.
- `ai_job_application_summary.rb` line 27 (callback) and lines 45-47 (method): confirmed both present.
- `spec/models/ai_job_application_summary_spec.rb`: no `create_status_record` references — no update required for that file.

CLEAN.

### always-on: test coverage

Task 6 (`ai_job_application_summary_status_spec.rb`) updated rewrite:
- `validations` block: removes `described_class.create!` call — eagerly-created record is the precondition for the uniqueness test. Correct.
- `defaults` block: two tests using `job_application.ai_job_application_summary_status` instead of `described_class.create!`. Correct. The existing `defaults regenerating to false` test (broken because no `regenerating` boolean column exists) is replaced by `defaults status to none` test. The broken test is gone.

Task 7 (`spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb`):
- Covers all five branches: Branch 1 (no changes), Branch 2a (succeeded → regenerating), Branch 2b (not succeeded → nil + none), Branch 3a (create with current + denormalized), Branch 3b (create with none).
- `before { job_application.ai_job_application_summary_status&.destroy }` in "record does not exist" contexts handles the eagerly-created record correctly.
- `spec/interactors/` directory exists on the branch — no directory-creation step needed.
- Branch 2b test creates a `failed` summary without `stale:` attribute — `stale` column has a db-level default (not shown in model). This is fine; the test does not reach the succeeded-non-stale check.
- Branch 3a succeeded summary created without `stale: false` explicit set. The `create_new` method queries `.where(stale: false, status: :succeeded)`. If the `stale` column defaults to something other than `false`, this test's summary may not be found. Let me verify.

CLEAN (with one item to verify — see below).

---

## One item requiring codebase verification

The Task 7 `create_new` tests create `AiJobApplicationSummary` records for the "succeeded non-stale summary exists" context:

```ruby
let!(:summary) do
  job_application.ai_job_application_summaries.create!(
    status: :succeeded,
    stale: false,
    ...
  )
end
```

This test explicitly passes `stale: false`, which is correct. The interactor queries `.where(stale: false, status: :succeeded)`. No issue.

However, the "ai_job_application_summary is present and succeeded" context in the "record exists" section (Task 7, lines 333-358) creates a summary without `stale:` set:

```ruby
let!(:summary) do
  job_application.ai_job_application_summaries.create!(
    status: :succeeded,
    score_percentage: 75.0,
    headline: 'Decent candidate',
    integrated_role_analysis: 'Reasonable fit'
  )
end
```

This is in the `handle_existing` branch — the interactor reaches `handle_existing` because the status record already has `ai_job_application_summary_id` set. The `create_new` method's `stale: false` query is only in the `create_new` branch. In `handle_existing`, the interactor checks `summary.status_succeeded?`, not `stale`. So missing `stale:` in this context's summary creation is not a problem — the branch logic does not use it. CLEAN.

---

## Summary table

No findings this round.

| ID | Severity | Task | Description |
|---|---|---|---|
| — | — | — | No issues found |

---

## Verdict: PASS

All round 3 fixes are correctly applied. No new issues found. All seven review angles and always-on checks are clean. This is the first clean pass; one more clean pass achieves the required consecutive two.
