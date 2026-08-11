# Review Angles — FindOrCreateAiJobApplicationSummaryStatus

Generated from: /Users/jessica/claude-hub/inflow-ats/_in-progress/find-or-create-ai-summary-status/SPEC.md
Date: 2026-06-15

---

## Subsystems touched

- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — new interactor (created)
- `app/models/job_application.rb` — adds `find_or_create_ai_job_application_summary_status` instance method; calls it as last line of `enqueue_new_job_application`
- `app/models/textract_result.rb` — calls `job_application.find_or_create_ai_job_application_summary_status` in `generate_ai_summary_with_credit_flow`, after early return guard at line 67, before `generate_ai_summary`
- `app/models/ai_job_application_summary.rb` — deletes `after_commit :create_status_record, on: :create` callback and `create_status_record` method
- `app/interactors/create_ai_summary_generation.rb` — deletes both `AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)` calls (lines 54 and 74)
- `app/models/ai_job_application_summary_status.rb` — existing model; referenced throughout (unchanged)
- `db/schema.rb` — `ai_job_application_summary_statuses` table (unchanged; reference for columns)

---

## Closest analog

`FindOrCreateOrgInterviewerInvite` at `app/interactors/find_or_create_org_interviewer_invite.rb`

Layer-by-layer trace:

- **Entry:** Receives named context input (`context.organization_user`, `context.email`)
- **Guard:** Returns early if prerequisite record not found (`Organization.find_by_id`); calls `context.fail!` for authorization failure
- **Find branch:** `organization.invites.find_by_email(context.email)` → assigns to `@invite` and `context.invite` directly, no changes made
- **Build branch:** `organization.invites.build(invite_params)` → populates attributes → authorizes → `@invite.save` → sets `context.invite` on success, `context.fail!` on failure
- **Output:** `context.invite` set in all non-error paths
- **Pattern:** `build` + explicit `save` (not `find_or_create_by`); `context.fail!` on hard errors; bare `return` guard style

**Priority rule:** The analog uses `find_by` (not `find_by!`) and bare `return` (not `context.fail!`) for the organization-not-found case — that is the correct pattern for a soft miss, distinct from a hard authorization failure. The new interactor should follow the same distinction.

---

## Angles

### angle-1: generation-flow-coverage

**What this covers:** Verifies that every path that triggers AI summary generation — manual single, auto via `TextractResult` callback, and bulk via `BulkGenerateAiSummariesJob` — routes through `generate_ai_summary_with_credit_flow` and therefore through the new interactor call at the correct point.

**Files across all layers:**
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` (new call site), `queue_ai_summary_job` (auto-trigger via `after_commit`), `generate_ai_summary` (downstream)
- `app/jobs/generate_ai_job_application_summary_job.rb` — calls `textract_result.generate_ai_summary_with_credit_flow` for both manual and auto paths
- `app/jobs/bulk_generate_ai_summaries_job.rb` — calls `result.textract_result.generate_ai_summary_with_credit_flow` in `each_iteration`
- `app/interactors/create_ai_summary_generation.rb` — manual trigger interactor; deletes two `find_or_create_by` calls; still enqueues `GenerateAiJobApplicationSummaryJob`
- `app/interactors/validate_ai_summary_generation.rb` — referenced by queue and bulk paths (referenced, not modified)
- `app/models/ai_job_application_summary.rb` — `after_commit :queue_ai_summary_job` triggers auto-path via `TextractResult`

**Analog files for comparison:** N/A — this angle has no direct analog; the three-path convergence is unique to this domain.

**Convention context:**
- Pipeline CLAUDE.md known failure pattern #16 (companion records: all paths must create the record) — this feature directly resolves that pattern; verify it fully closes it.
- Pipeline CLAUDE.md known failure pattern #2 (trace every pipeline end-to-end before implementing).

**What to check specifically:**
- The `generate_ai_summary_with_credit_flow` early-return guard (line 67) — `return if latest&.status_succeeded? && !latest.stale?` — fires BEFORE the interactor call. Verify the spec places the interactor call AFTER this guard, matching the approved decision. Verify the guard cannot prematurely skip the interactor call in the create-status-when-record-does-not-exist branch (Decision #4 creates with `status: :current` when a non-stale succeeded summary already exists — but the early return prevents reaching the interactor entirely if that condition is true).
- The `textract_processing` path: when a `JobApplication` is submitted with a resume in Textract, `CreateAiSummaryGeneration` creates a `textract_processing` status summary and the status record via one of the two deleted `find_or_create_by` calls (line 54). After deletion, that path gets its status record from `generate_ai_summary_with_credit_flow` (via `queue_ai_summary_job` → `GenerateAiJobApplicationSummaryJob`). Confirm there is no window where `status: :textract_processing` summaries exist with no status record.
- The `queue_ai_summary_job` auto-path (no `ai_summary_waiting_on_textract`) enqueues `GenerateAiJobApplicationSummaryJob` with no `requesting_organization_user_id` — the job calls `generate_ai_summary_with_credit_flow` → interactor. Confirm this path still creates the status record.
- `BulkGenerateAiSummariesJob#each_iteration` calls `generate_ai_summary_with_credit_flow` directly on `result.textract_result` — confirm this triggers the interactor.

---

### angle-2: interactor-state-machine-correctness

**What this covers:** Verifies that the three-branch state machine in the new interactor (record-exists-nil, record-exists-with-summary, record-does-not-exist) produces the correct state transitions across all input conditions, including edge cases at branch boundaries.

**Files across all layers:**
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — the new interactor (all branches)
- `app/models/ai_job_application_summary_status.rb` — `status` enum (`none: 0`, `current: 1`, `regenerating: 2`), `validates :job_application_id, uniqueness: true`
- `app/models/ai_job_application_summary.rb` — `status` enum, `stale` column (used in "non-stale succeeded" check in Decision #4)
- `db/schema.rb` — `ai_job_application_summary_statuses` columns: `status` (integer, default 0), `ai_job_application_summary_id`, `score_percentage`, `headline`, `integrated_role_analysis`

**Analog files for comparison:**
- `app/interactors/find_or_create_org_interviewer_invite.rb` — find-branch makes no changes; build-branch uses `build` + explicit `save`; `context.fail!` on hard error

**Convention context:**
- Core critical rules #8 — guard clauses use bare `return`, no truthy/falsy return values
- Core critical rules #11 — no bang methods; Decision #4 creates via `build` + explicit `save`, not `create!`
- Core critical rules #12 — always check `save`/`update` return values

**What to check specifically:**
- **Branch 1 (record exists, `ai_job_application_summary` is nil):** Spec says "make no changes." Confirm the implementation does not call `save` or `update` on the status record. The interactor must still set `context.ai_job_application_summary_status`.
- **Branch 2 (record exists, association present, summary `status_succeeded?`):** Sets status to `:regenerating`. Confirm: (a) the `save` return value is checked per rule #12, (b) `ai_job_application_summary_id` is NOT cleared on the status record (only `status` changes), (c) denormalized columns are NOT cleared.
- **Branch 2 (record exists, association present, summary NOT `status_succeeded?`):** Sets `ai_job_application_summary` to nil and `status` to `:none`. Confirm: (a) both attributes are set before `save`, (b) save return value is checked, (c) denormalized columns (`score_percentage`, `headline`, `integrated_role_analysis`) are also cleared — they refer to the old summary that is being disassociated.
- **Branch 3 (record does not exist, succeeded non-stale summary exists):** Creates with `status: :current` and populates `ai_job_application_summary_id` and all three denormalized columns. Confirm the "succeeded, non-stale" check uses the same logic as `generate_ai_summary_with_credit_flow`'s guard (`latest&.status_succeeded? && !latest.stale?`).
- **Branch 3 (record does not exist, no succeeded non-stale summary):** Creates with `status: :none`, `ai_job_application_summary_id` nil. Confirm denormalized columns are also nil/absent.
- The spec's Decision #5: association check via `belongs_to` (`job_application_summary.ai_job_application_summary`) not by column ID. Verify the interactor never queries `where(ai_job_application_summary_id: ...)` or reads the `_id` column directly.
- **Race condition at uniqueness constraint:** The `AiJobApplicationSummaryStatus` table has a DB-level unique index on `job_application_id`. If two concurrent calls both hit Branch 3 simultaneously, the second `save` will fail. Verify the spec addresses or explicitly defers this. (If not addressed, the reviewer should flag it.)

---

### angle-3: removal-completeness

**What this covers:** Verifies that every existing creation path for `AiJobApplicationSummaryStatus` is removed and replaced, with no orphaned calls, no stale references in specs, and no silent double-creation.

**Files across all layers:**
- `app/models/ai_job_application_summary.rb` — `after_commit :create_status_record, on: :create` and `create_status_record` method (to be deleted)
- `app/interactors/create_ai_summary_generation.rb` — two `AiJobApplicationSummaryStatus.find_or_create_by(...)` calls at lines 54 and 74 (to be deleted); line 74 also sets `status_record.regenerating = false` — a write to a nonexistent boolean column (stale bug to also be removed)
- `app/models/job_application.rb` — `enqueue_new_job_application` (new call to `find_or_create_ai_job_application_summary_status` added as last line)
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` (new call added)
- `spec/models/ai_job_application_summary_status_spec.rb` — existing spec has `expect(status_record.regenerating).to eq(false)` which calls `.regenerating` as an attribute; the model has no boolean `regenerating` column (only `status` enum with `:regenerating` value). After removal of the old `create_status_record` and `find_or_create_by` code, this spec either needs to be updated or confirmed that it was already broken/testing the wrong thing.
- `spec/models/ai_job_application_summary_spec.rb` — tests `create_status_record` behavior indirectly via `AiJobApplicationSummary` callbacks; may need updating when callback is removed.

**Analog files for comparison:** N/A

**Convention context:**
- Pipeline CLAUDE.md known failure pattern #6 (rename cascades — grep for ALL references including spec files)
- Approved decision #9 explicitly scopes codebase-wide grep to `create_status_record` and `find_or_create_by` involving `AiJobApplicationSummaryStatus`

**What to check specifically:**
- Grep result for `create_status_record` across `app/`, `spec/`, `lib/`, `db/` — confirm zero remaining references after deletion.
- Grep result for `AiJobApplicationSummaryStatus.find_or_create_by` and `find_or_create_by.*job_application.*AiJobApplicationSummaryStatus` — confirm zero remaining.
- Line 73 of `create_ai_summary_generation.rb`: `status_record.regenerating = false` — this is a write to a nonexistent boolean column. The spec removes the surrounding `find_or_create_by` block; confirm the `status_record.regenerating = false` line is also gone.
- The existing `ai_job_application_summary_status_spec.rb` `defaults regenerating to false` test: after the spec change, this test references `status_record.regenerating` as a plain attribute. `AiJobApplicationSummaryStatus` has `enum status: {..., regenerating: 2}` with `_prefix: true`, meaning the attribute is `status_regenerating?` not `regenerating`. This test was likely passing because of a now-deleted `regenerating` boolean column. Verify the spec deletes or rewrites this test.
- Confirm that after the `after_commit :create_status_record, on: :create` callback is removed from `AiJobApplicationSummary`, the `ai_job_application_summary_spec.rb` tests that relied on `create_status_record` side effects are updated.

---

### angle-4: analog-structural-matching

**What this covers:** Verifies the new interactor matches `FindOrCreateOrgInterviewerInvite`'s structural patterns — context input/output convention, `build` + explicit `save` (not `find_or_create_by`), guard clause style, `context.fail!` usage, and return value handling.

**Files across all layers:**
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — new interactor
- `app/models/job_application.rb` — `find_or_create_ai_job_application_summary_status` wrapper method (Decision #6: one-liner calling interactor)

**Analog files for comparison:**
- `app/interactors/find_or_create_org_interviewer_invite.rb` — the direct structural analog

**Convention context:**
- Core critical rules #8 — bare `return` guard clauses (no truthy/falsy return values)
- Core critical rules #11 — no bang methods (no `save!`, `create!`, `update!`)
- Core critical rules #12 — always check `save`/`update` return values
- Pipeline CLAUDE.md known failure pattern #14 — analog structural matching at signature level, not just layer completeness

**What to check specifically:**
- Context input is `context.job_application` (Decision #1). Verify no other inputs are required that the spec omits.
- Context output is `context.ai_job_application_summary_status` set in all non-error code paths (find path, create path, and branch-2 update path). Verify it is set even when no changes are made (Branch 1).
- The `build` + explicit `save` pattern: Branch 3 (create path) must use `job_application.build_ai_job_application_summary_status(...)` or `AiJobApplicationSummaryStatus.new(job_application: job_application, ...)` followed by explicit `.save`. NOT `find_or_create_by`, NOT `create`, NOT `create!`.
- `context.fail!` usage: the analog calls `context.fail!` for hard failures (authorization error, save failure). Verify the new interactor does the same on save failure. Failure handling is "deferred" per Decision #6 for the wrapper method — but the interactor itself must still propagate save failures via `context.fail!`.
- The wrapper method `JobApplication#find_or_create_ai_job_application_summary_status` is a one-liner (Decision #6). Verify it does not add error handling, logging, or branching beyond `FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)`.

---

### angle-5: save-return-value-handling

**What this covers:** Verifies that every `save` and `update` call in the new interactor and the modified `generate_ai_summary_with_credit_flow` checks the return value, per core critical rule #12, and that no bang methods are introduced, per core critical rule #11.

**Files across all layers:**
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — new interactor (all `save`/`update` calls)
- `app/models/ai_job_application_summary.rb` — `update_summary_status_record` uses `update_columns` (unchecked); existing pattern — not in scope but worth confirming no new unchecked calls are introduced
- `app/models/textract_result.rb` — `generate_ai_summary_with_credit_flow` (interactor call replaces nothing; no new save calls)

**Analog files for comparison:**
- `app/interactors/find_or_create_org_interviewer_invite.rb` — `@invite.save` with `if/else` branch, `context.fail!` in else

**Convention context:**
- Core critical rules #11 — no bang methods in non-test code
- Core critical rules #12 — always check `save`/`update` return values

**What to check specifically:**
- Branch 2 (record exists, update needed): `status_record.save` or `status_record.update(...)` — return value must be checked. A failing update must call `context.fail!` or equivalent.
- Branch 3 (record does not exist, save): return value checked; `context.fail!` on failure.
- No `save!`, `update!`, or `create!` in the new interactor.
- The interactor result is not checked at the call site in `generate_ai_summary_with_credit_flow` (Decision #8 — "failure handling deferred"). The spec should note this explicitly. The reviewer must confirm the call site does not silently swallow a `context.fail!` in a way that would break `generate_ai_summary_with_credit_flow`'s subsequent logic. Interactor gem: a `context.fail!` raises `Interactor::Failure` — if the call site does not rescue it, it will propagate up through `generate_ai_summary_with_credit_flow` to the job. Verify whether the spec intends for interactor failures to propagate or be swallowed.

---

### angle-6: trigger-a-new-application-path

**What this covers:** Verifies the Trigger A path — `JobApplication#enqueue_new_job_application` → `find_or_create_ai_job_application_summary_status` — specifically the timing, ordering, and interaction with existing work enqueued in that method.

**Files across all layers:**
- `app/models/job_application.rb` — `after_commit :enqueue_new_job_application, on: [:create]`, `enqueue_new_job_application` method, new `find_or_create_ai_job_application_summary_status` call at end
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — called from `enqueue_new_job_application`
- `app/jobs/submit_resume_to_textract_job.rb` — enqueued by `enqueue_new_job_application` before the interactor call (conditional on Flipper flag)

**Analog files for comparison:** N/A

**Convention context:**
- Approved decision #7 — `enqueue_new_job_application` calls `find_or_create_ai_job_application_summary_status` as the LAST line of the method

**What to check specifically:**
- `enqueue_new_job_application` currently ends with `SubmitResumeToTextractJob.perform_later(id)` inside a Flipper-gated block. The spec says `find_or_create_ai_job_application_summary_status` is the "last line of the method." Verify the implementation places it after the Flipper block, not inside it. If placed inside the Flipper block, the status record would not be created when Textract processing is disabled.
- When `enqueue_new_job_application` fires (after commit on create), the `JobApplication` may not yet have an `AiJobApplicationSummary`. The interactor will take Branch 3 (no existing status record) and check whether a non-stale succeeded summary exists — it won't. The interactor should create with `status: :none`. Confirm this is the expected outcome and matches approved decision #4's "no" branch.
- The `after_commit` context means the `JobApplication` record is already persisted. Confirm the interactor does not need a reload to access associations (`ai_job_application_summary_status`, `ai_job_application_summaries`).
- No job is enqueued or background work triggered by the interactor itself in Trigger A. The status record is created synchronously in `enqueue_new_job_application`. Confirm this is safe given `enqueue_new_job_application` runs in an `after_commit` callback (no active transaction risk for the status record save).

---

### angle-7: update_summary_status_record-interaction

**What this covers:** Verifies that `AiJobApplicationSummary#update_summary_status_record` (the `after_commit` on `:update` that sets `status: 'current'` and populates denormalized columns when the summary succeeds) still functions correctly after this feature's changes, and does not conflict with or duplicate what the new interactor does.

**Files across all layers:**
- `app/models/ai_job_application_summary.rb` — `after_commit :update_summary_status_record, on: :update` (unchanged); `update_summary_status_record` private method using `update_columns`
- `app/models/ai_job_application_summary_status.rb` — the status record being written by `update_summary_status_record`
- `app/interactors/find_or_create_ai_job_application_summary_status.rb` — new interactor (pre-generation call); sets initial state on status record

**Analog files for comparison:** N/A

**Convention context:** N/A

**What to check specifically:**
- The lifecycle sequence for a new application (no prior summary, auto-generate enabled): (1) `enqueue_new_job_application` → interactor creates status with `status: :none`. (2) Textract completes → `queue_ai_summary_job` → `GenerateAiJobApplicationSummaryJob` → `generate_ai_summary_with_credit_flow` → interactor called again (Branch 1 or Branch 2: record exists). (3) Generation completes → `AiJobApplicationSummary` transitions to `:succeeded` → `update_summary_status_record` fires → sets `status: 'current'` and populates denormalized columns. Confirm steps 2 and 3 are compatible: the interactor in step 2 should not set the denormalized columns (that's `update_summary_status_record`'s job on success), and `update_summary_status_record` must still run as before.
- The interactor's Branch 2 "record exists, summary not succeeded → set `ai_job_application_summary` to nil, `status` to `:none`": after this interactor call, `update_summary_status_record` might fire during the same request if the generation completes inline. Confirm the ordering: `generate_ai_summary` runs after the interactor call; if it succeeds, `update_summary_status_record` fires via `after_commit` on the summary — this would set the status record to `:current`. Confirm this sequencing is correct and that the interactor's `:none` setting is not the final state when generation succeeds in the same synchronous call.
- `update_summary_status_record` uses `update_columns` (skips callbacks and validations). Confirm it does not bypass any invariant the new interactor establishes.

---

## Always-on checks

### Source accuracy

Verify every file path, class name, method name, line number reference, and column name in the spec against the branch source (`feature-ai-summaries-integrating-scoring-v4`):

- `create_ai_summary_generation.rb` lines 54 and 74 — verify these are the actual lines containing `AiJobApplicationSummaryStatus.find_or_create_by` on the branch. The file has 85 lines; lines 54 and 74 are in the `textract_pending` and normal-save branches respectively. Confirm positions match.
- `generate_ai_summary_with_credit_flow` "line 67" (spec) — the early return guard `return if latest&.status_succeeded? && !latest.stale?` — verify this is still at line 67 on the current branch commit (the method was modified in commit `c800c21e9`).
- `AiJobApplicationSummaryStatus` model: confirm the schema has `status` as an integer enum column (default 0 = `:none`), NOT a `regenerating` boolean column. The existing spec's `expect(status_record.regenerating).to eq(false)` calls `.regenerating` as an attribute reader — with `enum status: {..., regenerating: 2}, _prefix: true`, there is no bare `.regenerating` method; the predicate would be `.status_regenerating?`. This is a pre-existing spec bug, not introduced by this feature, but the implementation review should confirm the spec update addresses it.
- `AiJobApplicationSummary#update_summary_status_record` — exists on the branch as an `after_commit` on `:update` (unchanged). Verify the spec does not accidentally specify deleting this callback (it only specifies deleting the `after_commit :create_status_record, on: :create` callback).
- Denormalized columns in `AiJobApplicationSummaryStatus`: `score_percentage` (decimal), `headline` (string), `integrated_role_analysis` (text) — confirm these column names match the migration and schema exactly.

### Test coverage

Existing tests that cover affected code:

- `spec/models/ai_job_application_summary_status_spec.rb` — validates uniqueness and two defaults (one referencing nonexistent `regenerating` attribute). After this feature: the `defaults regenerating to false` test is invalid and must be updated or deleted. A new test for the interactor's three branches is needed.
- `spec/models/ai_job_application_summary_spec.rb` — tests `destroy_previous_textract_results` and status enum. No direct test of `create_status_record`. After deletion of `create_status_record`, confirm no test implicitly depends on it (e.g., a test that calls `AiJobApplicationSummary.create!` and then checks whether a status record was created).
- `spec/models/textract_result_ai_trigger_spec.rb` — tests `queue_ai_summary_job`. Does not test `generate_ai_summary_with_credit_flow` directly. After the new interactor call is added to `generate_ai_summary_with_credit_flow`, confirm whether tests for that method exist or need to be added.
- `spec/interactors/` — no existing spec for `FindOrCreateOrgInterviewerInvite` found on the branch. A new spec at `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb` should be required, covering all three main branches and their sub-cases.

**Required new test coverage (spec should state these):**
- `FindOrCreateAiJobApplicationSummaryStatus` interactor spec: Branch 1 (no changes); Branch 2a (succeeded → regenerating); Branch 2b (not succeeded → nil + none); Branch 3a (create with current + denormalized); Branch 3b (create with none)
- `JobApplication` model spec or integration test: `enqueue_new_job_application` creates a status record with `status: :none`
- `TextractResult` model spec: `generate_ai_summary_with_credit_flow` calls the interactor before `generate_ai_summary`; does NOT call it when the early-return guard fires

### Reinventing the wheel / pattern compliance

The spec explicitly adopts `FindOrCreateOrgInterviewerInvite`'s `build` + explicit `save` pattern. Verify the implementation follows this rather than introducing `find_or_create_by` (which the approved decisions explicitly reject) or `first_or_initialize`. Verify `context.ai_job_application_summary_status` is set in every branch, mirroring how the analog sets `context.invite` in every branch before returning.

### Backward compatibility

**Existing consumers of removed code:**

- `AiJobApplicationSummary#create_status_record` callback — deletion means any code path that creates an `AiJobApplicationSummary` but bypasses the new interactor will no longer create a status record. Audit all `AiJobApplicationSummary.create` / `ai_job_application_summaries.build(...).save` call sites on the branch. The known paths are `CreateAiSummaryGeneration` (builds directly) and `AiJobApplicationAction::Orchestrate` (downstream). Confirm status record creation is not lost for any of these.
- `AiJobApplicationSummaryStatus.find_or_create_by` in `CreateAiSummaryGeneration` line 74 currently also passes a block that sets `status_record.regenerating = false`. This write targets a nonexistent boolean column — it was effectively a no-op that triggered a method-missing error silently or on a since-removed column. Confirm removal of this block does not break any behavior that was actually working.
- `spec/models/ai_job_application_summary_status_spec.rb` — `expect(status_record.regenerating).to eq(false)` — if `regenerating` was previously a boolean column that has since been replaced by the `status` enum, this test was broken on the branch before this feature. The spec must update or delete this test to not introduce a new test failure.

### Analog completeness

`FindOrCreateOrgInterviewerInvite` has these structural pieces; verify `FindOrCreateAiJobApplicationSummaryStatus` has a corresponding piece for each:

| Analog piece | New interactor equivalent | Present? |
|---|---|---|
| Receives named context input (`organization_user`, `email`) | Receives `job_application` | Verify |
| Early guard — returns if prerequisite not found | No prerequisite lookup needed (job_application passed directly) | N/A — analog deviates; acceptable per spec |
| Feature gate check | No feature gate (AI summaries enabled check is in `ValidateAiSummaryGeneration`, upstream) | N/A — acceptable per spec |
| Find branch — sets context output, no changes | Branch 1 (record exists, summary nil) — no changes, set context output | Verify |
| Build branch — `build` + explicit `save` | Branch 3 (record does not exist) — `build` + explicit `save` | Verify |
| `context.fail!` on save failure | `context.fail!` if save fails in Branch 2 or Branch 3 | Verify |
| Sets `context.[output]` in all paths | Sets `context.ai_job_application_summary_status` in all paths | Verify |

### Analog structural matching

Per pipeline CLAUDE.md known failure pattern #14: verify the new interactor matches `FindOrCreateOrgInterviewerInvite` at the structural level, not just the layer level:

- **Parameter interface:** `context.job_application` is the single input, directly analogous to `context.organization_user` + `context.email` in the analog. The new interactor does not need multiple inputs because it can derive everything from `job_application`. Verify the interactor does not add implicit context reads beyond `context.job_application`.
- **Association-based find:** The analog uses `organization.invites.find_by_email(context.email)` — a scoped lookup through the parent association. The new interactor should use `job_application.ai_job_application_summary_status` (the `has_one` association) not a bare `AiJobApplicationSummaryStatus.find_by(job_application_id: ...)` query. Approved decision #5 confirms: use the association directly.
- **Build via association:** The analog uses `organization.invites.build(invite_params)`. The new interactor should use `job_application.build_ai_job_application_summary_status(...)` or `AiJobApplicationSummaryStatus.new(job_application: job_application, ...)`. Verify the correct pattern is used.
- **Error propagation:** The analog calls `context.fail!` with no message for save failure (the invite record carries the errors). The new interactor should follow the same pattern — `context.fail!` without a message, errors on the status record itself.
