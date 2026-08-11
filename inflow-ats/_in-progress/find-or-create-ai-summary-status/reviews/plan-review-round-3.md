# Plan Review Round 3 — FindOrCreateAiJobApplicationSummaryStatus

**Verdict: FAIL**

---

## Round 2 findings: verification

| ID | Severity | Was it fixed? | Notes |
|---|---|---|---|
| N1 (HIGH) | `update_columns` return value unchecked in `handle_existing` | FIXED | Both `update_columns` calls now wrapped with `unless ... context.fail!` |
| N2 (HIGH) | Spec "record does not exist" tests wrong branch; "record exists" tests error with uniqueness violation | FIXED | "record does not exist" contexts add `before { job_application.ai_job_application_summary_status&.destroy }`; "record exists" contexts use `job_application.ai_job_application_summary_status` and `update_columns` |
| N3 (MED) | Task 2 Step 1 directs inserting method after associations block (line 31) | FIXED | Step 1 now says "near `enqueue_new_job_application` (around line 150) in the private/callback methods section" |
| N4 (LOW) | Task 6 `defaults` tests call `described_class.create!` — fails after eager creation | FIXED | Task 6 now uses `job_application.ai_job_application_summary_status` to access the eagerly-created record |

---

## New findings

### R3-F1 — HIGH: Task 6 `validations` test still calls `described_class.create!` — will fail after eager creation

**Angle:** angle-3: removal-completeness; always-on checks: Test coverage

**Location:** `spec/models/ai_job_application_summary_status_spec.rb` — `describe 'validations'` block (lines 10-18 of existing file)

**The existing spec:**
```ruby
describe 'validations' do
  it 'enforces uniqueness on job_application_id' do
    described_class.create!(job_application: job_application)

    duplicate = described_class.new(job_application: job_application)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:job_application_id]).to include('has already been taken')
  end
end
```

**What the plan fixes:** Task 6 Step 1 correctly fixes the `defaults` section, using the eagerly-created record instead of `described_class.create!`.

**What the plan misses:** The `validations` block at lines 10-18 also calls `described_class.create!(job_application: job_application)` on line 12. After Task 2 adds eager status record creation in `enqueue_new_job_application`, `create_credit_test_job_application` will have already created a status record for `job_application`. The `described_class.create!` on line 12 will fail with `ActiveRecord::RecordInvalid: Validation failed: Job application has already been taken`.

The uniqueness validation test breaks because it now tries to create a FIRST record when one already exists — it should instead just test that the already-existing record blocks a second. The fix is: remove the explicit `create!` on line 12 and instead create only the `duplicate`:

```ruby
describe 'validations' do
  it 'enforces uniqueness on job_application_id' do
    duplicate = described_class.new(job_application: job_application)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:job_application_id]).to include('has already been taken')
  end
end
```

The eagerly-created record already satisfies the "a record exists" precondition for the uniqueness test.

**Impact:** The `validations` test fails with `ActiveRecord::RecordInvalid` after Task 2. The test suite will have an erroring (not just failing) spec.

---

### R3-F2 — MED: Task 2 Step 1 says "private/callback methods section" but `enqueue_new_job_application` is public — method placement description is misleading

**Angle:** always-on checks: Source accuracy; angle-4: analog-structural-matching

**Location:** Plan Task 2, Step 1

**What the plan says:**
> Add to `JobApplication` as a public instance method, near `enqueue_new_job_application` (around line 150) in the private/callback methods section.

**What the codebase shows:** `enqueue_new_job_application` is at line 151 of `job_application.rb`. The `private` keyword in this file is at line 896 (one method: `correct_document_mime_type`). `enqueue_new_job_application` is a public method — it is not in the private section.

The instruction "in the private/callback methods section" is inaccurate. The CALLBACKS section header at line 139 (`#######################` / `# CALLBACKS`) is correct, but calling it "private/callback methods section" could mislead an implementation agent to insert the method after line 896 (the actual `private` keyword), which would make `find_or_create_ai_job_application_summary_status` private — then calling it from `enqueue_new_job_application` would work (same class, private is fine), but the wrapper method is supposed to be public per the spec ("public instance method").

**Impact:** Low risk of breaking implementation — calling a private method from a method in the same class works in Ruby. But the description is factually wrong and could mislead the implementation agent about where to insert the method.

**Fix:** Change "in the private/callback methods section" to "in the CALLBACKS section (public methods, around line 150)" to match the file's actual structure.

---

### R3-F3 — LOW: Task 8 verification commands may fail because `AiJobApplicationSummaryStatus` rows already exist for JA 6797

**Angle:** always-on checks: Source accuracy

**Location:** Plan Task 8, Steps 1-3

**What the plan says:** Task 8 Step 1 checks JA 6797 for an existing status record. Step 2 calls the interactor on JA 6797 and expects `Status: regenerating`. Step 3 queries for a `JobApplication` without any `AiJobApplicationSummaryStatus` row.

**The problem:** This is a developer verification task that runs against live dev-env data. After Task 2 is implemented, `enqueue_new_job_application` will have been called for new JAs going forward — but existing JAs created before this commit won't have status records (the interactor doesn't backfill). JA 6797 may or may not have a status record depending on when it was created and whether the `AiJobApplicationSummary` callback previously created one. Step 3 queries for a JA without a status record — after the feature is deployed this may return nil if all JAs have records.

**Impact:** Very low — Task 8 is a post-implementation smoke test, not automated test coverage. A nil result at Step 3 is a no-op for correctness, just means the verification command needs a different JA. Not a plan correctness issue.

**No fix required** — but the implementation agent should be aware these verification commands may need adjustment depending on dev-env state.

---

## Previously-closed findings: confirmed clean

All Round 1 and Round 2 fixes verified against the codebase:

- **F1 (BLOCKER):** `handle_existing` non-succeeded branch now includes `score_percentage: nil, headline: nil, integrated_role_analysis: nil` in `update_columns`. Confirmed clean.
- **F2 (HIGH):** Task 5 Step 2 now says "Remove lines 72-74." The actual code is at lines 72-74 of `create_ai_summary_generation.rb` (`find_or_create_by` block + `status_record.regenerating = false` + `end`). Confirmed correct.
- **F3/N1 (HIGH):** Both `update_columns` calls in `handle_existing` now use `unless ... context.fail!` pattern. Confirmed clean.
- **F4 (HIGH):** Task 6 added for `ai_job_application_summary_status_spec.rb`. `defaults` block fixed. See R3-F1 for the remaining `validations` block gap.
- **F5 (HIGH):** Task 7 added for full interactor spec with all five branches. Confirmed present.
- **N2 (HIGH):** "record does not exist" contexts add `before { job_application.ai_job_application_summary_status&.destroy }`. "record exists" contexts use the eager record + `update_columns`. Confirmed correct.
- **N3 (MED):** Task 2 Step 1 placement corrected to "around line 150." See R3-F2 for the minor residual inaccuracy ("private/callback").
- **N4 (LOW):** Task 6 `defaults` tests now use `job_application.ai_job_application_summary_status` instead of `create!`. Confirmed clean.

---

## Fresh pass — all angles

### angle-1: generation-flow-coverage

- All three generation paths (manual, auto via `TextractResult#queue_ai_summary_job`, bulk via `BulkGenerateAiSummariesJob`) converge on `textract_result.generate_ai_summary_with_credit_flow` (confirmed in `GenerateAiJobApplicationSummaryJob` line 32 and `BulkGenerateAiSummariesJob` line 62).
- The new interactor call is placed after the early return guard (line 68: `return if latest&.status_succeeded? && !latest.stale?`) and before `generate_ai_summary` (line 70). Confirmed in plan Task 3 — `generate_ai_summary` is at line 70, and the plan's code block shows the correct positioning.
- The early-return guard prevents the interactor from being called when a non-stale succeeded summary already exists — this is the correct behavior (no regeneration needed).
- The textract-pending window: after Task 4 removes `create_status_record` and Task 5 removes the `find_or_create_by` on line 54, the textract-pending path (`CreateAiSummaryGeneration` → `status: :textract_processing`) no longer creates a status record directly. Status record creation for this path depends on `enqueue_new_job_application` (Trigger A) having already run. Since `enqueue_new_job_application` runs at `after_commit :create`, the status record exists before any `CreateAiSummaryGeneration` call. The window is closed.

### angle-2: interactor-state-machine-correctness

- Branch 1 (record exists, `ai_job_application_summary` nil): `return unless summary` exits `handle_existing` with no changes. `context.ai_job_application_summary_status` is set after the `if/else`. Correct.
- Branch 2a (record exists, summary `succeeded`): `update_columns(status: 'regenerating')` checked, `context.fail!` on failure. `ai_job_application_summary_id` is NOT cleared. Correct per spec.
- Branch 2b (record exists, summary not `succeeded`): `update_columns` clears `ai_job_application_summary_id`, `status: 'none'`, and all three denormalized columns. Checked, `context.fail!` on failure. Correct.
- Branch 3a (no record, succeeded non-stale summary): `build` + explicit `save`, sets association and all three denormalized columns, `status: 'current'`. Correct.
- Branch 3b (no record, no summary): `build` + `save`, `status: 'none'`, no denormalized data. Correct.
- Association check: `status_record.ai_job_application_summary` (belongs_to, not `find_by` on ID column). Correct per spec Decision #5.
- `build` pattern: `job_application.build_ai_job_application_summary_status`. Correct per spec Decision #4.

### angle-3: removal-completeness

- `AiJobApplicationSummary#create_status_record` callback and method: plan Task 4 removes both. The current code at lines 27 and 45-47 of `ai_job_application_summary.rb` confirms both are present on the branch. Removal is correctly scoped.
- `CreateAiSummaryGeneration` line 54 (single `find_or_create_by`): confirmed at line 54. Task 5 Step 1 removes it.
- `CreateAiSummaryGeneration` lines 72-74 (block `find_or_create_by` + `status_record.regenerating = false` + `end`): confirmed at lines 72-74. Task 5 Step 2 removes all three lines together.
- Task 5 Step 3 grep: `grep -rn "create_status_record\|find_or_create_by.*AiJobApplicationSummaryStatus\|\.regenerating" app/ --include="*.rb"` — the `.regenerating` grep would catch any stale boolean assignments. Adequate.
- `ai_job_application_summary_spec.rb`: no tests depend on `create_status_record` side effects. Confirmed by reading the file — only `#destroy_previous_textract_results` and status enum are tested. No `create_status_record` reference. Clean.

### angle-4: analog-structural-matching

- Context input: `context.job_application`. Single input, matches spec.
- Context output: `context.ai_job_application_summary_status` set in all non-error paths (Branch 1: set after `handle_existing` returns; Branch 2: set after `handle_existing` returns or `context.fail!` raised; Branch 3: set after `create_new` returns). Correct.
- `build` + explicit `save`: Branch 3 uses `job_application.build_ai_job_application_summary_status` followed by explicit `.save`. Matches analog pattern.
- `context.fail!` on save failure: bare `context.fail!` (no keyword args). Matches analog.
- No `find_or_create_by`, `create`, or `create!` in the new interactor. Correct.

### angle-5: save-return-value-handling

- `handle_existing` Branch 2a: `unless status_record.update_columns(status: 'regenerating')` → `context.fail!`. Checked.
- `handle_existing` Branch 2b: `unless status_record.update_columns(...)` → `context.fail!`. Checked.
- `create_new`: `unless status_record.save` → `context.fail!`. Checked.
- No `save!`, `update!`, or `create!` in the new interactor. Correct.
- `context.fail!` raises `Interactor::Failure`. Since the call sites in `enqueue_new_job_application` and `generate_ai_summary_with_credit_flow` do not rescue it, failures propagate up. Per spec Decision #8, failure handling is "deferred" — this is intentional and consistent.

### angle-6: trigger-a-new-application-path

- `find_or_create_ai_job_application_summary_status` call is the LAST line of `enqueue_new_job_application` — after the Flipper-gated block, not inside it. Correct per spec Decision #7.
- Confirmed by plan Task 2 Step 2's code block.
- No job enqueued by the interactor. Status record created synchronously in `after_commit` context. Safe.

### angle-7: update_summary_status_record-interaction

- `update_summary_status_record` (the `after_commit :update_summary_status_record, on: :update` callback) is NOT deleted by this plan. Plan Task 4 only deletes `create_status_record` and its `after_commit :create_status_record, on: :create`. Confirmed: `update_summary_status_record` at lines 59-72 of `ai_job_application_summary.rb` is preserved.
- Lifecycle: interactor creates status with `status: :none` (Trigger A) → generation starts → interactor sets `status: :regenerating` if prior summary existed (Trigger B via `generate_ai_summary_with_credit_flow`) → generation completes → `update_summary_status_record` fires → sets `status: 'current'` and denormalized columns. Sequencing is correct.

### always-on: source accuracy

- `create_ai_summary_generation.rb` line numbers 54 and 72-74: verified against actual file. Line 54 is the textract-pending `find_or_create_by`; lines 72-74 are the block. Correct.
- `generate_ai_summary_with_credit_flow` early return guard: confirmed at line 68 (not 67). Task 3 correctly says "line 68."
- `AiJobApplicationSummaryStatus` schema: `status` integer (default 0 = none), no boolean `regenerating` column. Confirmed.
- Denormalized columns: `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text). All match schema.
- `update_summary_status_record` preserved: confirmed.

---

## Summary table

| ID | Severity | Task | Description |
|---|---|---|---|
| R3-F1 | HIGH | Task 6 | `validations` describe block still calls `described_class.create!` — will fail with `RecordInvalid` after Task 2 adds eager creation. Only the `defaults` block was fixed; the `validations` block at line 12 was missed. |
| R3-F2 | MED | Task 2 | "private/callback methods section" is factually wrong — `enqueue_new_job_application` is public (private keyword is at line 896). Misleading description; could cause method to be inserted in wrong section. |
| R3-F3 | LOW | Task 8 | Verification commands use hardcoded JA 6797 and assume dev-env state; Step 3 may return nil if all JAs already have status records. Not a correctness issue — smoke-test guidance only. |

---

## Required fixes before implementation

1. **R3-F1 (HIGH):** In Task 6, also update the `validations` describe block. Remove `described_class.create!(job_application: job_application)` from the uniqueness test (line 12 of existing spec). The eagerly-created record already satisfies the "first record exists" precondition. The test becomes:
   ```ruby
   describe 'validations' do
     it 'enforces uniqueness on job_application_id' do
       duplicate = described_class.new(job_application: job_application)
       expect(duplicate).not_to be_valid
       expect(duplicate.errors[:job_application_id]).to include('has already been taken')
     end
   end
   ```

2. **R3-F2 (MED):** Correct Task 2 Step 1's description from "in the private/callback methods section" to "in the CALLBACKS section (all methods here are public, around line 150-157)".
