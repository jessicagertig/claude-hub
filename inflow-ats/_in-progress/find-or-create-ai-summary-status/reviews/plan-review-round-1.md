# Plan Review Round 1 — FindOrCreateAiJobApplicationSummaryStatus

**Verdict: FAIL**

---

## Findings

### F1 — BLOCKER: Branch 2 (non-succeeded path) does not clear denormalized columns

**Angle:** angle-2: interactor-state-machine-correctness

**Location:** Plan Task 1, `handle_existing` method, non-succeeded branch (lines 56-60 of proposed interactor)

**What the plan says:**
```ruby
status_record.update_columns(
  ai_job_application_summary_id: nil,
  status: 'none'
)
```

**What the spec says (SPEC.md):**
> **Record exists, `ai_job_application_summary` is present:** Check that summary's `status`. If `succeeded`, set the status record's `status` to `:regenerating`. If anything other than `succeeded`, set `ai_job_application_summary` to nil and set `status` to `:none`.

**Review angles say (angle-2):**
> **Branch 2 (record exists, association present, summary NOT `status_succeeded?`):** Sets `ai_job_application_summary` to nil and `status` to `:none`. Confirm: (a) both attributes are set before `save`, (b) save return value is checked, (c) denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`) are also cleared — they refer to the old summary that is being disassociated.

**What the codebase shows:** The `ai_job_application_summary_statuses` table has `score_percentage`, `headline`, and `integrated_role_analysis` columns (confirmed in `db/schema.rb`). These denormalized columns point to the associated summary. When the association is being cleared (the summary is not succeeded, so we nil out `ai_job_application_summary_id`), those columns still hold the old summary's data. The plan does not clear them.

**Impact:** Status record ends up with `ai_job_application_summary_id: nil` but with stale `score_percentage`, `headline`, and `integrated_role_analysis` from the disassociated summary. Downstream consumers reading these columns get stale, misleading data even though the status is `none`.

**Fix:** The `update_columns` call must also set `score_percentage: nil, headline: nil, integrated_role_analysis: nil`.

---

### F2 — HIGH: Task 5 cites wrong line number for the second `find_or_create_by` call

**Angle:** angle-3: removal-completeness

**Location:** Plan Task 5, Step 1

**What the plan says:**
> Remove line 54 (textract pending path): `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)`
> Remove line 74 (textract ready path): `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)`

**What the codebase shows** (`app/interactors/create_ai_summary_generation.rb`):
- Line 54: `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` — correct
- Line 72: `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application) do |status_record|`
- Line 73: `status_record.regenerating = false`
- Line 74: `end`

The second `find_or_create_by` is on line 72, not line 74. Line 74 is the `end` keyword that closes the block.

**Impact:** An implementation agent following the plan literally — "remove line 74" — removes only the `end` keyword of the block, leaving the `find_or_create_by` call, the block variable binding, and the `status_record.regenerating = false` line. This produces a syntax error at runtime.

**Additional note:** The `status_record.regenerating = false` line at line 73 must also be removed as part of this block deletion. The plan does not mention it.

**Fix:** Task 5 Step 1 must specify removing lines 72-74 as a block (the `find_or_create_by` call, the block parameter, and the `end`), not just "line 74."

---

### F3 — HIGH: `update_columns` return value not checked in Branch 2 (existed path)

**Angle:** angle-5: save-return-value-handling, angle-2: interactor-state-machine-correctness

**Location:** Plan Task 1, `handle_existing` method (both sub-branches)

**What the plan says:**
```ruby
def handle_existing(status_record)
  summary = status_record.ai_job_application_summary
  return unless summary
  if summary.status_succeeded?
    status_record.update_columns(status: 'regenerating')
  else
    status_record.update_columns(
      ai_job_application_summary_id: nil,
      status: 'none'
    )
  end
end
```

**What cursor_rules require (core critical rule #12):** Always check `save`/`update` return values.

**What the review angles require (angle-5):**
> Branch 2 (record exists, update needed): `status_record.save` or `status_record.update(...)` — return value must be checked. A failing update must call `context.fail!` or equivalent.

**What the codebase shows:** `update_columns` returns `true`/`false`. The plan never checks the return value or calls `context.fail!` if `update_columns` returns false. The analog `FindOrCreateOrgInterviewerInvite` calls `context.fail!` on save failure.

**Impact:** If the database update fails (e.g., connection issue, constraint violation), the interactor silently continues and sets `context.ai_job_application_summary_status` with a record whose in-memory state reflects the intended update but whose persisted state does not. Downstream callers see the updated record but the database has old values.

**Fix:** Capture the return value and call `context.fail!` on false: `context.fail! unless status_record.update_columns(...)`.

---

### F4 — HIGH: Plan has no task to update `spec/models/ai_job_application_summary_status_spec.rb`

**Angle:** angle-3: removal-completeness (always-on checks: Test coverage)

**Location:** Plan — no Task exists for spec file updates

**What the review angles say:**
> `spec/models/ai_job_application_summary_status_spec.rb` — existing spec has `expect(status_record.regenerating).to eq(false)` which calls `.regenerating` as an attribute; the model has no boolean `regenerating` column (only `status` enum with `:regenerating` value). After removal of the old `create_status_record` and `find_or_create_by` code, this spec either needs to be updated or confirmed that it was already broken/testing the wrong thing.

**What the codebase confirms:**
- `AiJobApplicationSummaryStatus` has `enum status: { none: 0, current: 1, regenerating: 2 }, _prefix: true`
- There is no boolean `regenerating` column in the schema
- `spec/models/ai_job_application_summary_status_spec.rb` line 23: `expect(status_record.regenerating).to eq(false)` — calls `.regenerating` as an attribute reader, but with `_prefix: true` the method is `status_regenerating?`, not `regenerating`
- This test is currently broken (`.regenerating` is an undefined method on the status model)

**Impact:** After Task 4 removes the `after_commit :create_status_record, on: :create` callback, the test suite may behave differently. Regardless, this test is testing a nonexistent attribute. The plan leaves it in place, meaning the implementation agent commits with a broken spec.

**Fix:** Add a task to update `spec/models/ai_job_application_summary_status_spec.rb`: remove or rewrite the `defaults regenerating to false` test. The new test should verify `status` defaults to `none` (or 0).

---

### F5 — HIGH: Plan has no tasks for new interactor spec or updated `generate_ai_summary_with_credit_flow` tests

**Angle:** always-on checks: Test coverage

**Location:** Plan — no Task exists for interactor spec creation

**What the review angles require:**
> Required new test coverage (spec should state these):
> - `FindOrCreateAiJobApplicationSummaryStatus` interactor spec: Branch 1 (no changes); Branch 2a (succeeded → regenerating); Branch 2b (not succeeded → nil + none); Branch 3a (create with current + denormalized); Branch 3b (create with none)
> - `JobApplication` model spec or integration test: `enqueue_new_job_application` creates a status record with `status: :none`
> - `TextractResult` model spec: `generate_ai_summary_with_credit_flow` calls the interactor before `generate_ai_summary`; does NOT call it when the early-return guard fires

**What the plan has:** No test tasks. The plan's Task 6 runs live `rails runner` commands against specific JA IDs (6797 and a dynamic lookup). This is manual verification, not test coverage.

**Impact:** The interactor's state machine (5 branches) and the new call sites are unverified by automated tests. The plan's commit in Task 7 stages only `app/` files — no spec files.

**Fix:** Add a task to create `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` covering all five branches. Add updates for `spec/models/ai_job_application_summary_status_spec.rb`.

---

### F6 — MED: Task 3 line number description is off by one

**Angle:** always-on checks: Source accuracy

**Location:** Plan Task 3, Step 1

**What the plan says:**
> In `generate_ai_summary_with_credit_flow`, after the early return guard (line 67: `return if latest&.status_succeeded? && !latest.stale?`), add...

**What the codebase shows:**
- Line 67: `latest = job_application.latest_ai_job_application_summary`
- Line 68: `return if latest&.status_succeeded? && !latest.stale?`

The early return guard is at line 68, not line 67. Line 67 is the assignment to `latest`.

**Impact:** Low — the code block shown in the plan (lines 157-171) correctly places the interactor call after the return guard, so the implementation behavior is correct. The wrong line number is only a navigation/documentation error. However, it signals the plan was not verified against the actual file.

**Fix:** Correct the description to "line 68."

---

### F7 — MED: `context.fail!` key deviates from analog pattern

**Angle:** angle-4: analog-structural-matching

**Location:** Plan Task 1, `create_new` method

**What the plan says:**
```ruby
unless status_record.save
  context.fail!(error: status_record.errors.full_messages.join(', '))
end
```

**What the analog does (`FindOrCreateOrgInterviewerInvite` line 47):**
```ruby
context.fail!
```

The analog calls bare `context.fail!` on save failure (no keyword arguments). The plan uses `context.fail!(error: ...)` with a named `:error` key and a pre-joined string. The analogy also sets `context.invite = invite` before calling `context.fail!` so callers can read the record's errors directly; the plan's approach embeds the errors into the context as a string instead.

**Impact:** Convention mismatch. Other interactors in this codebase that check `result.error` may be getting a string from this interactor when they expect no key (or `result.message` as used in the feature gate failure). Not a crash, but deviates from the structural analog the spec explicitly mandates.

**Fix:** Change to bare `context.fail!`. The status record is already set on `context.ai_job_application_summary_status` before save in the create path, so callers can read `context.ai_job_application_summary_status.errors` if needed.

---

### F8 — MED: Task 2 description says "around line 31" but AI associations are actually lines 29-31

**Angle:** always-on checks: Source accuracy

**Location:** Plan Task 2, Step 1

**What the plan says:**
> Add to the public methods section of `JobApplication` (near the other AI-related associations around line 31)

**What the codebase shows:** The AI-related associations are at lines 29-31:
- Line 29: `has_many :ai_job_application_summaries`
- Line 30: `has_one :latest_ai_job_application_summary`
- Line 31: `has_one :ai_job_application_summary_status`

The plan's instruction to add a public instance method "near line 31" is vague — line 31 is in the associations block, not a public methods section. The method should go in the public methods section lower in the file, not adjacent to line 31. This could cause the implementation agent to insert the method inside the associations block.

**Fix:** Clarify that the method belongs in the public methods section of the file (after the callbacks section, not inline with the associations).

---

## Summary Table

| ID | Severity | Task | Description |
|---|---|---|---|
| F1 | BLOCKER | Task 1 | Branch 2 non-succeeded path does not clear denormalized columns |
| F2 | HIGH | Task 5 | Second `find_or_create_by` cited at wrong line (74 vs 72); block lines 72-74 must be removed together |
| F3 | HIGH | Task 1 | `update_columns` return value unchecked in `handle_existing`; no `context.fail!` on failure |
| F4 | HIGH | (missing) | No task to fix the broken `defaults regenerating to false` spec test |
| F5 | HIGH | (missing) | No tasks for new interactor spec or `generate_ai_summary_with_credit_flow` test coverage |
| F6 | MED | Task 3 | Early return guard described as "line 67" but is actually line 68 |
| F7 | MED | Task 1 | `context.fail!(error: ...)` deviates from analog's bare `context.fail!` pattern |
| F8 | MED | Task 2 | "around line 31" is the associations block, not the public methods section |

---

## Required fixes before implementation

1. **F1 (BLOCKER):** Add `score_percentage: nil, headline: nil, integrated_role_analysis: nil` to the non-succeeded `update_columns` call.
2. **F2 (HIGH):** Change "Remove line 74" to "Remove lines 72-74" (the entire `find_or_create_by ... end` block including `status_record.regenerating = false`).
3. **F3 (HIGH):** Wrap both `update_columns` calls in `handle_existing` with return-value checks and `context.fail!`.
4. **F4 (HIGH):** Add a task to delete or rewrite the `defaults regenerating to false` test in `spec/models/ai_job_application_summary_status_spec.rb`.
5. **F5 (HIGH):** Add a task to create `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` covering all five branches.
