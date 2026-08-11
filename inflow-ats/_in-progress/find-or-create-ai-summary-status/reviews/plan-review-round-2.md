# Plan Review Round 2 — FindOrCreateAiJobApplicationSummaryStatus

**Verdict: FAIL**

---

## Round 1 findings: verification

| ID | Severity | Was it fixed? | Notes |
|---|---|---|---|
| F1 (BLOCKER) | Denormalized columns not cleared in non-succeeded branch | FIXED | `update_columns` in `handle_existing` now includes `score_percentage: nil, headline: nil, integrated_role_analysis: nil` |
| F2 (HIGH) | Wrong line number for second `find_or_create_by` | FIXED | Task 5 Step 2 now says "Remove lines 72-74" |
| F3 (HIGH) | `update_columns` return value unchecked in `handle_existing` | NOT FIXED | See N1 below |
| F4 (HIGH) | No task for existing spec update | FIXED | Task 6 added |
| F5 (HIGH) | No tasks for interactor spec | FIXED | Task 7 added |
| F6 (MED) | Wrong line number for early return guard | FIXED | Task 3 now says "line 68" |
| F7 (MED) | `context.fail!(error: ...)` deviates from analog | FIXED | Changed to bare `context.fail!` |
| F8 (MED) | "Around line 31" puts method in associations block | NOT FIXED | See N3 below |

---

## New findings

### N1 — HIGH: F3 still unresolved — `update_columns` return value unchecked in `handle_existing`

**Angle:** angle-5: save-return-value-handling

**Location:** Plan Task 1, `handle_existing` method

**What the plan shows:**
```ruby
def handle_existing(status_record)
  summary = status_record.ai_job_application_summary
  return unless summary

  if summary.status_succeeded?
    status_record.update_columns(status: 'regenerating')
  else
    status_record.update_columns(
      ai_job_application_summary_id: nil,
      status: 'none',
      score_percentage: nil,
      headline: nil,
      integrated_role_analysis: nil
    )
  end
end
```

**The problem:** F3 said to wrap both `update_columns` calls with a return-value check and call `context.fail!` on false. The updated plan is identical to the original — the return values of both `update_columns` calls are still discarded. Neither branch calls `context.fail!` on failure.

`update_columns` returns `true`/`false`. If the database update fails, the interactor continues, sets `context.ai_job_application_summary_status` with an object whose in-memory state reflects the intended transition but whose persisted state does not, and returns success. Core critical rule #12 ("always check `save`/`update` return values") and the analog's `context.fail!` pattern both require this to be fixed.

**Fix:** Both `update_columns` calls must check the return value and call `context.fail!` on failure:
```ruby
context.fail! unless status_record.update_columns(status: 'regenerating')
```
and
```ruby
context.fail! unless status_record.update_columns(
  ai_job_application_summary_id: nil,
  status: 'none',
  score_percentage: nil,
  headline: nil,
  integrated_role_analysis: nil
)
```

---

### N2 — HIGH: Task 7 spec "record does not exist" and "record exists" contexts will all behave incorrectly after Task 2 is implemented

**Angle:** always-on checks: Test coverage; angle-6: trigger-a-new-application-path

**Location:** Plan Task 7 — all four contexts in the interactor spec

**What the plan does:**
- Task 2 adds `find_or_create_ai_job_application_summary_status` as the last line of `enqueue_new_job_application` in `JobApplication`
- `enqueue_new_job_application` is called by `after_commit :enqueue_new_job_application, on: [:create]`
- Task 7's spec uses `create_credit_test_job_application` to set up `job_application`

**The problem:**

The test environment uses `config.active_job.queue_adapter = :inline` (`config/environments/test.rb` line confirmed). `find_or_create_ai_job_application_summary_status` is **not a job** — it is a direct synchronous Ruby method call appended to `enqueue_new_job_application`. It runs immediately when `after_commit` fires, regardless of the ActiveJob adapter setting.

In Rails 6.1 with `use_transactional_fixtures = true`, `after_commit` callbacks fire at savepoint release — confirmed by `spec/models/ai_job_criteria_spec.rb` line: `describe '#resume_waiting_summaries (after_commit callback)'` which tests after_commit behavior using the same transactional fixture setup.

**Consequence:** When `create_credit_test_job_application` creates a `JobApplication`, `after_commit :enqueue_new_job_application` fires, which (after Task 2) calls `find_or_create_ai_job_application_summary_status`, which creates a `AiJobApplicationSummaryStatus` record with `status: :none`.

This breaks the spec as written:

**"record does not exist / no succeeded summary" context:**
- Status record is already created (`:none`) by `enqueue_new_job_application` before the spec's `it` block runs
- `described_class.call` hits Branch 1 (record exists, summary nil → no changes) instead of Branch 3
- Test checks `status 'none'` and `ai_job_application_summary_id nil` → these match Branch 1's no-change behavior, so the test **passes but tests the wrong branch**
- Branch 3's create path is never exercised by this test

**"record does not exist / succeeded non-stale summary exists" context:**
- Status record already created (`:none`, no summary linked) by `enqueue_new_job_application`
- `let!(:summary)` creates a succeeded summary, but after Task 4 removes `create_status_record`, no callback links the summary to the status record
- `described_class.call` hits Branch 1 (record exists, `ai_job_application_summary` is nil → no changes)
- Test checks: `status: 'current'`, `ai_job_application_summary_id eq summary.id`, denormalized columns set
- Branch 1 makes no changes → status is `'none'`, summary_id is nil, no denormalized data
- Test **FAILS**

**"record exists" contexts (all three sub-contexts):**
- `let!(:status_record) { AiJobApplicationSummaryStatus.create!(job_application: job_application, status: 'none') }` runs AFTER `create_credit_test_job_application` already created a status record
- `AiJobApplicationSummaryStatus.create!` raises `ActiveRecord::RecordInvalid: Validation failed: Job application has already been taken` (unique index on `job_application_id`)
- All three "record exists" contexts **ERROR OUT** before even running their `it` blocks

**Fix:** The spec must account for the status record that `enqueue_new_job_application` creates eagerly. Two approaches:

1. **"record does not exist" contexts:** Add a `before` block that destroys the eagerly-created status record before calling the interactor:
   ```ruby
   before { job_application.ai_job_application_summary_status&.destroy }
   ```

2. **"record exists" contexts:** Instead of `AiJobApplicationSummaryStatus.create!`, access the already-existing record created by `enqueue_new_job_application`:
   ```ruby
   let!(:status_record) { job_application.ai_job_application_summary_status }
   ```
   (This requires the `let!` to trigger `job_application` evaluation, which fires `enqueue_new_job_application` via `after_commit`, which creates the record.) Contexts that need specific attributes (`:current` status, specific denormalized columns) should call `status_record.update_columns(...)` in a `before` block rather than `create!`.

---

### N3 — MED: F8 partially unresolved — Task 2 Step 1 still directs adding method at line 31 (associations block)

**Angle:** always-on checks: Source accuracy

**Location:** Plan Task 2, Step 1

**What the plan says:**
> Add to `JobApplication` as a public instance method, after the existing AI-related associations (after line 31 `has_one :ai_job_application_summary_status`):

**What the codebase shows:** Line 31 is:
```ruby
has_one :ai_job_application_summary_status
```
Line 32 is:
```ruby
has_one_attached :resume # Keep resume optional
```

"After line 31" inserts the method between the `has_one :ai_job_application_summary_status` declaration and the `has_one_attached :resume` declaration — inside the associations block at the top of the class, before the validations, callbacks, enums, and scopes sections. It would not be syntactically invalid, but it violates the model's structure, where all public instance methods begin around line 142.

The fix from Round 1 changed "around line 31" to "after line 31" — it changed the qualifier but not the line. The method belongs in the public methods section near `enqueue_new_job_application` (around line 151), not in the associations block.

**Impact:** An implementation agent could insert the method at line 32, between `has_one :ai_job_application_summary_status` and `has_one_attached :resume`. The method works anywhere in the class body, but code review would flag the placement.

**Fix:** Change Task 2 Step 1's instruction to place the method in the public methods section, after `enqueue_new_job_application` (around line 157, after the `end` that closes `enqueue_new_job_application`).

---

### N4 — LOW: Task 6 spec "defaults status to none" test will also fail due to eager status record creation

**Angle:** always-on checks: Test coverage

**Location:** Plan Task 6, Step 1

**What the plan shows:**
```ruby
describe 'defaults' do
  it 'defaults status to none' do
    status_record = described_class.create!(job_application: job_application)
    expect(status_record.status).to eq('none')
  end
  ...
end
```

**The problem:** After Task 2, `create_credit_test_job_application` creates an `AiJobApplicationSummaryStatus` record (via `enqueue_new_job_application → find_or_create_ai_job_application_summary_status`). The `described_class.create!` then fails with uniqueness violation — the same issue as N2, but in `ai_job_application_summary_status_spec.rb` rather than the interactor spec.

The "allows `ai_job_application_summary_id` to be nil" test has the same problem.

**Impact:** Raising severity is borderline; this is the same root cause as N2 which is already HIGH. Flagged separately as LOW because it's in a different file and the fix is parallel.

**Fix:** Same approach as N2 — either use the eagerly-created record (`let(:status_record) { job_application.ai_job_application_summary_status }`) or add a `before { job_application.ai_job_application_summary_status&.destroy }` to ensure a clean state before the `create!`.

---

## Summary table

| ID | Severity | Task | Description |
|---|---|---|---|
| N1 | HIGH | Task 1 | F3 not fixed: `update_columns` return value still unchecked in `handle_existing`; no `context.fail!` on failure |
| N2 | HIGH | Task 7 | Spec "record does not exist" contexts test wrong branch; "record exists" contexts error with uniqueness violation — caused by Task 2's eager status record creation via `enqueue_new_job_application` after_commit |
| N3 | MED | Task 2 | F8 partially unresolved: "after line 31" still places method in associations block; should be in public methods section near `enqueue_new_job_application` |
| N4 | LOW | Task 6 | Same eager-creation issue as N2 — `described_class.create!` in "defaults" tests fails after Task 2 |

---

## Required fixes before implementation

1. **N1 (HIGH):** In `handle_existing`, check the return value of both `update_columns` calls and call `context.fail!` if either returns false.

2. **N2 (HIGH):** Rewrite the Task 7 spec to account for the eager status record created by `enqueue_new_job_application`:
   - "record does not exist" contexts: add `before { job_application.ai_job_application_summary_status&.destroy }` to clean the eager record before calling the interactor.
   - "record exists" contexts: use `let!(:status_record) { job_application.ai_job_application_summary_status }` instead of `AiJobApplicationSummaryStatus.create!`, and set the desired attributes via `update_columns` in a `before` block.

3. **N3 (MED):** Correct Task 2 Step 1 to direct placing the method in the public methods section (after `enqueue_new_job_application` at line 157), not after the `has_one :ai_job_application_summary_status` association at line 31.

4. **N4 (LOW):** Apply the same fix to Task 6's "defaults" tests — use the eagerly-created record or destroy it before the `create!` call.
