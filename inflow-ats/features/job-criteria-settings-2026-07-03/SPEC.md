# SPEC — Job criteria in Plato AI settings

Binding inputs: `DECISIONS.md` in this directory (wins over every design file), `design/bundle-1-decisions/Job criteria - decisions.html` (decided design), `design/bundle-3-reference-tsx/` (structure/styles skeleton only — its variable names, guard modals, tier hints, and sync-response assumptions are overridden).

Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings` (branch `job-criteria-settings` off `qa-refinements`). All file:line citations below are from this worktree.

---

## 1. Summary

Expose AI-extracted job criteria in the per-job Plato AI settings tab (`JobSetupAiSettings.tsx`). Four pieces:

1. **Fetch** — new GET endpoint returning the job's criteria payload (criteria content + extraction status + extracted-at time).
2. **View** — read-only FullModal right slide-over listing criteria grouped by tier.
3. **Regenerate** — new POST endpoint that starts an async extraction; completion notifies the requesting user via a backend-triggered WebSocket toast; the frontend learns in-flight status from the fetched payload (survives reload), not local mutation state.
4. **Backend enforcement** — no new AI summary reviews may start while the job's latest extraction is a zero-criteria failure.

Also includes the Jessica-approved `Job#extract_job_criteria_immediately` / `#extract_job_criteria_if_needed` gating change (made in the main checkout, NOT yet in this worktree — verified: `app/models/job.rb:726-743` still has the old form).

## 2. Stack scope

- **Backend:** Rails — 1 new controller, 1 new serializer, 2 new routes, model changes (`Job`, `AiJobCriteria`), 2 job changes (`ExtractJobCriteriaJob` signature + broadcasts; `BulkGenerateAiSummariesJob` claim-row fix, Section 6.3), guard additions in 2 validator interactors + 1 bulk-queue interactor + 1 model pipeline entry point, 3 one-line constant substitutions in existing services.
- **Frontend:** React/TypeScript — 1 new query-hook file, 2 new modal components, extension of `JobSetupAiSettings.tsx`, 1 new WebSocket handler case, 1 payload type addition.
- **No Cypress changes** (see Test plan).

## 3. Data model changes

**None.** Verified sufficient:

- `ai_job_criteria` table (db/schema.rb:181-190): `job_id`, `status` (int enum), `criteria` jsonb, `metadata` jsonb, `error_message` text, timestamps. History table; newest row is what scoring consults (`app/services/ai_job_application_action/scoring/score_job_application.rb:19`).
- Card timestamp ("extracted these … 2 hours ago") uses the latest succeeded row's `updated_at` — set when `ExtractCriteria` updates status to `succeeded` (`app/services/ai_job_application_action/scoring/extract_criteria.rb:132-141` uses `update`, which touches `updated_at`). No `extracted_at` column needed.
- Zero-criteria discrimination uses existing `status` + `error_message` (Section 6). No new column.
- `jobs.internal_job_criteria` (db/schema.rb:909) is dead and explicitly OUT — do not touch, reference, or build on it.

## 4. Backend — model changes

### 4.1 `Job` gating change (DECISIONS.md, verbatim except the kwarg noted below)

`app/models/job.rb:726-743` currently:

```ruby
def extract_job_criteria_immediately
  return unless description.present?

  new_ai_job_criteria = ai_job_criteria.new(status: :pending)
  return unless new_ai_job_criteria.save

  ExtractJobCriteriaJob.perform_later(new_ai_job_criteria.id)
end

def extract_job_criteria_if_needed
  return if latest_ai_job_criteria&.status_succeeded?
  return if latest_ai_job_criteria&.status_in_progress?
  return if latest_ai_job_criteria&.status_retrying?

  extract_job_criteria_immediately
end
```

Replace with (guards moved INTO `_immediately`; `_if_needed` keeps only the `succeeded` guard):

```ruby
def extract_job_criteria_immediately(requesting_organization_user_id: nil)
  return unless description.present?
  return if latest_ai_job_criteria&.status_in_progress?
  return if latest_ai_job_criteria&.status_retrying?

  new_ai_job_criteria = ai_job_criteria.new(status: :pending)
  return unless new_ai_job_criteria.save

  ExtractJobCriteriaJob.perform_later(new_ai_job_criteria.id, requesting_organization_user_id)
end

def extract_job_criteria_if_needed
  return if latest_ai_job_criteria&.status_succeeded?

  extract_job_criteria_immediately
end
```

**Deviation from the DECISIONS.md code block, flagged for review:** the optional `requesting_organization_user_id:` kwarg (default nil — the only existing caller of `_immediately` is `extract_job_criteria_if_needed` (job.rb:742, reached via `textract_result.rb:70`), which passes nothing; the other three `ExtractJobCriteriaJob.perform_later` enqueue sites (job.rb:707, 709, 723) sit in `auto_extract_job_criteria`/`extract_job_criteria`, which this change does not touch). It reconciles two DECISIONS.md requirements: the exact gating code AND the backend-triggered completion toast, whose analog (`GenerateAiJobApplicationSummaryJob`, `app/jobs/generate_ai_job_application_summary_job.rb:24,34,50-80`) threads `requesting_organization_user_id` through the job's arguments and broadcasts only when it is present (manual path) — mirrored here.

**Documented consequence (per DECISIONS, do not "fix"):** `_immediately` does NOT guard `pending`. Two rapid POSTs can create two pending rows. The frontend disables the button once the payload shows an in-flight status; residual double-enqueue is wasteful but harmless (latest row wins).

### 4.2 `AiJobCriteria` — zero-criteria discrimination

Add to `app/models/ai_job_criteria.rb`:

```ruby
ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE = 'No criteria sections found in job description'
ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE = 'No criteria extracted from job description'
ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE = 'Criteria array is empty'

ZERO_CRITERIA_ERROR_MESSAGES = [
  ZERO_CRITERIA_NO_SECTIONS_ERROR_MESSAGE,
  ZERO_CRITERIA_NONE_EXTRACTED_ERROR_MESSAGE,
  ZERO_CRITERIA_EMPTY_ARRAY_ERROR_MESSAGE
].freeze

def zero_criteria_failure?
  status_failed? && ZERO_CRITERIA_ERROR_MESSAGES.include?(error_message)
end
```

Writers switch to the constants (one-line substitutions, no behavior change):
- `app/services/ai_job_application_action/scoring/extract_criteria.rb:62` (`'No criteria sections found in job description'`) and `:122` (`'No criteria extracted from job description'`).
- `app/services/ai_job_application_action/scoring/score_job_application.rb:43` (`'Criteria array is empty'`).

**Flagged spec decision:** DECISIONS.md names only the two `ExtractCriteria` messages. `'Criteria array is empty'` is included as a third because it is also "extraction completed with zero usable criteria" (written onto the ai_job_criteria row when a succeeded row turns out to have a blank criteria array — `score_job_application.rb:42-47`); excluding it would let that state pass the review guard and render the generic failure state instead of the zero-found state. Succeeded rows always have ≥1 criterion (`extract_criteria.rb:121-124` guards before the succeeded update), so `succeeded` never means zero.

Failure messages NOT in the set (examples, land in the generic failure state): `'Job description is blank'` (`extract_criteria.rb:32`), `"Failed to parse AI response: …"` (`extract_criteria.rb:151`), retry-exhaustion messages (`extract_job_criteria_job.rb:9`), any StandardError message.

### 4.3 `Job` convenience predicate

```ruby
def zero_criteria_extraction_failure?
  latest_ai_job_criteria&.zero_criteria_failure?
end
```

Place next to `latest_ai_job_criteria` (`job.rb:688`). Semantics: the job's **latest** extraction row (any status) is a terminal zero-criteria failure. Deliberately NOT "latest terminal row": if a new extraction is pending/in-flight, the predicate is false and reviews may start and wait via the existing `awaiting_job_criteria` mechanics (`orchestrate.rb:68-83`, `ai_job_criteria.rb:21-30`) — starting a review while extraction runs is not pointless; the pipeline is built for it. Used by the guard call sites (Section 6) and the serializer (Section 5.3).

## 5. API changes

### 5.1 Routes

In `config/routes.rb` inside `resources :jobs do` (line 224), alongside the other job-nested resources (e.g., `resources :bulk_channel_messages, only: [:create]`, line 265):

```ruby
resource :ai_job_criteria, only: [:show, :create], controller: 'ai_job_criteria'
```

- `GET  /api/v1/jobs/:job_id/ai_job_criteria` → `Api::V1::AiJobCriteriaController#show`
- `POST /api/v1/jobs/:job_id/ai_job_criteria` → `Api::V1::AiJobCriteriaController#create`

Singleton `resource` because the payload is "the job's current criteria view", not an id-addressed collection member; the explicit `controller:` option follows the AI-credits singleton precedent (`resource :ai_credits, only: [:show], controller: 'organization_ai_credit_balance'`, routes.rb:189) and sidesteps Rails' criteria/criterium inflection (documented in `ai_job_criteria.rb:33-37`).

**Analog resolution (required by the orchestrator):** the closest AI-scoring fetch analog is the dedicated endpoint + dedicated serializer + dedicated hook used for summaries — `resources :ai_job_application_summaries, only: [:show, :create]` (routes.rb:314) → `Api::V1::AiJobApplicationSummariesController` → `Api::V1::AiJobApplicationSummarySerializer` → `useAiJobApplicationSummary.ts`. POST-as-create-a-new-run also matches that analog's `#create`. **One documented deviation:** for summaries, the status pointer rides the parent serializer (`Api::V1::JobApplicationSerializer` `has_one :ai_job_application_summary_status`, job_application_serializer.rb:41) because summary status is needed on every applicant row in list views. Criteria status is needed ONLY in this settings tab, so status rides the same dedicated endpoint instead of burdening `Api::V1::JobSerializer` (fetched app-wide) with per-job criteria queries. DECISIONS.md explicitly allows either ("existing job serializer vs a dedicated endpoint: follow the closest AI-scoring analog").

### 5.2 Controller — `app/controllers/api/v1/ai_job_criteria_controller.rb` (new)

```ruby
# frozen_string_literal: true

class Api::V1::AiJobCriteriaController < Api::V1::BaseController
  def show
    exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|
      authorize job, :show?
      render_one(job, Api::V1::JobAiJobCriteriaSerializer)
    end
  end

  def create
    exists(current_organization.jobs.where(id: params[:job_id]), 'no job found') do |job|
      authorize job, :update?

      unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, current_organization)
        render_general_errors(['AI summaries are not enabled for this organization.'])
        return
      end

      if job.description.blank?
        render_general_errors(['This job needs a description before Plato can extract criteria. Add one in Job setup.'])
        return
      end

      job.extract_job_criteria_immediately(requesting_organization_user_id: current_organization_user.id)
      render_one(job, Api::V1::JobAiJobCriteriaSerializer)
    end
  end
end
```

Conventions honored: `exists` + block (`application_controller.rb:52-60`; same shape as `ai_job_application_summaries_controller.rb:5,31`); `render_one`/`render_general_errors` helpers (`application_controller.rb:40,89`); authorize-after-find with explicit policy query (cursor_rules/backend/controllers/pundit_policies.md, "authorize AFTER finding" and the `authorize(job_application.job, :update?)` nested-action example); no begin blocks, no bang methods, no params method (no body params are accepted — core rule 5 requires at most one params method, zero is compliant). Lookup scoping via `current_organization.jobs` matches every job-nested controller (e.g., `bulk_ai_job_application_summaries_controller.rb:9`). Note: no `hash_id` fallback — the frontend passes numeric `job.id` in the path, as job-nested hooks do (e.g. `useBulkMessage.ts:23`, `` path: `/jobs/${jobId}/bulk_channel_messages` ``).

Behavior notes:
- **Blank description** → 422 with the error message above (DECISIONS: "must return an error message when the description is blank"; the frontend toasts it — Section 8.5). Message register mirrors `'This job needs a description before Plato can review candidates. Add one in Job Setup.'` (`validate_ai_summary_generation.rb:29`).
- **Flipper check** in the controller because `extract_job_criteria_immediately` deliberately has no Flipper gate (its other caller sits behind validators that check it — `validate_ai_summary_generation.rb:26`); without this, a non-AI org could trigger paid OpenAI calls. Error text copied from `validate_ai_summary_generation.rb:26`.
- **POST while in-flight** (`in_progress`/`retrying`): `extract_job_criteria_immediately` no-ops via its guards; the response is the current payload (still in-flight) — idempotent; the frontend button is already loading in this state.
- **POST response** is the refreshed payload (same serializer as GET), mirroring `#create` render-the-resource in `ai_job_application_summaries_controller.rb:23`.

### 5.3 Serializer — `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` (new)

Serializes the **Job** (a differently-named Job serializer follows the `AdminJobSerializer`/`ShallowJobSerializer`/`PublicJobSerializer` family precedent). Only what the UI needs (DECISIONS):

```ruby
# frozen_string_literal: true

class Api::V1::JobAiJobCriteriaSerializer < ActiveModel::Serializer
  attributes :criteria, :extracted_at, :status, :zero_criteria_failure

  def criteria
    object.latest_succeeded_ai_job_criteria&.criteria
  end

  def extracted_at
    object.latest_succeeded_ai_job_criteria&.updated_at
  end

  def status
    object.latest_ai_job_criteria&.status
  end

  def zero_criteria_failure
    object.zero_criteria_extraction_failure?
  end
end
```

- `criteria` — from the **latest succeeded** row (`Job#latest_succeeded_ai_job_criteria`, job.rb:692; DECISIONS: "newest succeeded row is current"). Raw stored jsonb array of `{text, tier, source_heading, …}` entries passed through per serializer rule "JSONB columns: just list/return them" (cursor_rules/backend/serializers.md §1); the UI reads `text` and `tier` only. Frontend receives camelCased KEYS (`sourceHeading`) but tier VALUES stay `tier_1`/`tier_2`/`tier_3` (enum-like data values remain snake_case — core rule 7 exception).
- `status` — the **latest** row's enum string (`pending` / `in_progress` / `succeeded` / `failed` / `retrying`), `nil` when the job has no `ai_job_criteria` rows at all ("never ran"). Stays snake_case on the frontend (core rule 7 exception).
- `zero_criteria_failure` — `true`/`false`/`nil` via safe navigation; no fabricated `|| false` (core rule 10 / pipeline rule 13).
- Computed methods delegate to Job model methods per serializers.md §7 (computation at model level).

Payload examples (frontend camelCase after api.ts transform):

| State | criteria | extractedAt | status | zeroCriteriaFailure |
|---|---|---|---|---|
| Never ran | null | null | null | null |
| First extraction running | null | null | "pending"/"in_progress"/"retrying" | false |
| Succeeded | [...] | ts | "succeeded" | false |
| Regenerating after success | [...] (old) | ts (old) | "pending"/"in_progress"/"retrying" | false |
| Zero-criteria failure | null or [...] (older succeeded) | null or ts | "failed" | true |
| Other failure | null or [...] (older succeeded) | null or ts | "failed" | false |

## 6. Backend — zero-criteria review guard

**Requirement (DECISIONS):** when the latest completed extraction found zero criteria, new AI summary reviews must not start (they would burn the first pipeline steps pointlessly). Condition = `Job#zero_criteria_extraction_failure?` (Section 4.3).

### 6.1 All AI-summary creation entry points (traced)

| # | Entry point | Path to pipeline | Validator on path |
|---|---|---|---|
| 1 | Manual single: `Api::V1::AiJobApplicationSummariesController#create` (ai_job_application_summaries_controller.rb:4-28) | `CreateAiSummaryGeneration` → `GenerateAiJobApplicationSummaryJob` → credit flow | `ValidateAiSummaryGeneration` (line 8) |
| 2 | Bulk: `Api::V1::BulkAiJobApplicationSummariesController#create` / `#all_stages` (bulk_ai_job_application_summaries_controller.rb:6,30) | `QueueBulkAiSummaryJobs` → `BulkGenerateAiSummariesJob#each_iteration` → credit flow | `ValidateAiSummaryGeneration` per record (bulk_generate_ai_summaries_job.rb:59) |
| 3 | Auto on new applicant: `JobApplication#enqueue_new_job_application` → `#auto_generate_ai_summary_if_enabled` (job_application.rb:168-188) | `CreateAiSummaryGeneration` (textract_processing) → textract completion picks it up | `ValidateAutoAiSummaryGeneration` (job_application.rb:186) |
| 4 | Auto on resume upload: `job_applications_controller.rb:118` → `#auto_generate_ai_summary_if_enabled` | same as #3 | same as #3 |
| 5 | Textract completion: `TextractResult#queue_ai_summary_job` after_commit (textract_result.rb:116-146) — both the manual-waiting branch and the auto-generate branch | `GenerateAiJobApplicationSummaryJob` → credit flow | `ValidateAiSummaryGeneration` (lines 128, 142) |
| 6 | Criteria-succeeded resume: `AiJobCriteria#resume_waiting_summaries` (ai_job_criteria.rb:21-30) | `GenerateAiJobApplicationSummaryJob` → credit flow | none (fires only when criteria just succeeded — guard is definitionally false; also not a NEW review) |
| 7 | Shared pipeline entry every path funnels through: `TextractResult#generate_ai_summary_with_credit_flow` (textract_result.rb:61-91), called by `GenerateAiJobApplicationSummaryJob#perform` (generate_ai_job_application_summary_job.rb:32) and `BulkGenerateAiSummariesJob#each_iteration` (bulk_generate_ai_summaries_job.rb:80) | — | — |

### 6.2 Guard placement (shared entry point + user-facing validators, no scattering)

Pipeline rule 16 precedent (shared entry points over scattered `find_or_create_by`) and the harness "defense in depth" pattern:

1. **`ValidateAiSummaryGeneration`** (`app/interactors/validate_ai_summary_generation.rb`) — add after the `has_job_description?` fail (line 29):
   ```ruby
   context.fail!(error: 'No scoring criteria were found in the job description. Regenerate job criteria in Plato AI settings before running reviews.') if @job_application.job&.zero_criteria_extraction_failure?
   ```
   Covers entry points 1 (synchronous 422 → existing toast path in the frontend), 2 (per-record backstop), 5 (auto branch: silently skips enqueue, textract_result.rb:144; manual-waiting branch: destroys the waiting summary and broadcasts `AI_SUMMARY_FAILED` with the error, textract_result.rb:135-137 — existing behavior, now carrying this message).
2. **`ValidateAutoAiSummaryGeneration`** (`app/interactors/validate_auto_ai_summary_generation.rb`) — same `fail!` after line 18. Covers entry points 3 and 4 (auto path silently declines, matching how it declines on missing credits/description today).
3. **`QueueBulkAiSummaryJobs`** (`app/interactors/queue_bulk_ai_summary_jobs.rb`) — new context input `job`; add after the credits fail (line 18):
   ```ruby
   context.fail!(error: 'No scoring criteria were found in the job description. Regenerate job criteria in Plato AI settings before running reviews.') if context.job&.zero_criteria_extraction_failure?
   ```
   Both bulk controller actions already hold `@job` and pass `job: @job` to the `.call` (bulk_ai_job_application_summaries_controller.rb:13-17 and 37-43 — modified files). Safe navigation keeps the input optional so nothing else breaks; the fail-fast gives bulk users a synchronous error toast instead of an all-failed completion toast.
4. **`TextractResult#generate_ai_summary_with_credit_flow`** (`app/models/textract_result.rb`) — defensive guard at the shared funnel, after the succeeded-summary early return (line 68) and BEFORE `extract_job_criteria_if_needed` (line 70):
   ```ruby
   return if job_application.job.zero_criteria_extraction_failure?
   ```
   This is the layer that covers EVERY path regardless of what validators upstream did (jobs already enqueued when criteria zeroed out, future callers). Ordering matters: placed before `extract_job_criteria_if_needed` so a blocked review does not silently re-trigger extraction on an unchanged description.

**Not placed** in `Orchestrate`/`ScoreJobApplication` (mid-pipeline — reviews there have already started and are handled by existing `awaiting_job_criteria` mechanics) nor in `CreateAiSummaryGeneration`/`CreateBulkAiSummaryGeneration` (both sit behind a validator on every path).

### 6.3 Adjacent fix required for guard safety (flagged — shared-infrastructure change)

`BulkGenerateAiSummariesJob#each_iteration` currently leaves the claim row `:processing` when per-record validation fails (`return unless result.success?`, bulk_generate_ai_summaries_job.rb:60): nothing ever updates that row, and `QueueBulkAiSummaryJobs` treats `:processing` rows as "already claimed" (queue_bulk_ai_summary_jobs.rb:45-49), so those candidates become permanently un-queueable. This is a pre-existing latent gap (e.g., credits running out mid-batch), but the new guard makes it a common path (any bulk run against a zero-criteria job would poison every selected candidate). Minimal fix, in scope:

```ruby
result = ValidateAiSummaryGeneration.call(job_application: job_application, organization: organization)
unless result.success?
  job_application_bulk_job_status.update_columns(status: :failed)
  return
end
```

`update_columns` matches every other row-status write in this job (lines 54, 66, 86) and is not inside a transaction (pipeline rule 25). Flagged per pipeline rules 10/20: this is a behavioral change to shared bulk infrastructure — it is IN the spec deliberately so it gets reviewed as scope, not smuggled in by a fix agent.

### 6.4 Interaction with the gating change

Post-change `extract_job_criteria_if_needed` re-extracts whenever the latest row is `failed` (including zero-criteria). That is unchanged from DECISIONS and correct for the auto pipeline (a review already validated as allowed to start should try to get criteria). The review guard fires earlier, so zero-criteria jobs never reach that call. Summaries already sitting in `awaiting_job_criteria` when an extraction completes with zero criteria remain waiting (resume fires only on `succeeded`, ai_job_criteria.rb:22) — existing behavior, out of scope.

**Documented consequence of the funnel guard (race window — accepted; do not "fix" without owner approval, pipeline rule 20):** a summary that was created and enqueued while the predicate was false (all validators passed) can arrive at the funnel AFTER a zero-criteria failure lands (enqueue→perform latency; `set(wait: 30.seconds)` scheduling, job.rb:707; 2-minute retry waves). The guard then returns bare, leaving the summary in its pre-pipeline status (`pending` on the manual path, create_ai_summary_generation.rb:60-74; `textract_processing` on the textract path) with no broadcast — the job's terminal-status guard skips non-terminal rows (generate_ai_job_application_summary_job.rb:62). That summary is not revivable by `resume_waiting_summaries` (queries only `awaiting_job_criteria`, ai_job_criteria.rb:24), and a manual re-click returns it via `CreateAiSummaryGeneration`'s active-summary branch (create_ai_summary_generation.rb:30-44) without enqueueing. It is revived by a bulk re-run (`:done` claim rows do not block re-claim, queue_bulk_ai_summary_jobs.rb:45-49; the funnel call at bulk_generate_ai_summaries_job.rb:80 is unconditional) or by a new resume upload (staleness branch, create_ai_summary_generation.rb:36-39). Bulk variant of the race: `each_iteration` marks the claim row `:done` (bulk_generate_ai_summaries_job.rb:86) though nothing ran, slightly inflating the completion toast's succeeded count. Pre-feature, the same race produced a revivable `awaiting_job_criteria` (Orchestrate `check_criteria_and_score`). Accepted because the window is narrow, no credit is consumed, and the alternative — the funnel guard transitioning the latest summary to `awaiting_job_criteria` instead of returning bare — is a new state transition on shared infrastructure requiring owner approval; recorded as an open question for Jessica in SPEC-REVIEW-COMPLETE.md.

## 7. Backend — WebSocket completion broadcast

**Analog (required by the orchestrator):** `GenerateAiJobApplicationSummaryJob` — kwarg-threaded `requesting_organization_user_id`, `broadcast_completion` private helper broadcasting `GlobalChannel.broadcast_to(user, action: 'AI_SUMMARY_COMPLETE', payload: {...})` from three sites: end of `perform` when a requesting user exists (line 34), `retry_on` exhaustion block (line 20), StandardError rescue (line 45); helper returns unless the record is terminal (lines 62). Consumed in `WebsocketGlobalChannelHandler.tsx:216-234` (toast + query invalidations). `GlobalChannel` is `app/channels/global_channel.rb:3`.

**Changes to `app/jobs/extract_job_criteria_job.rb`:**

- Signature: `def perform(ai_job_criteria_id, requesting_organization_user_id = nil)`. Optional positional (not kwargs like the analog's `perform(textract_result_id:, requesting_organization_user_id: nil)`, generate_ai_job_application_summary_job.rb:24) — **adjudicated structural deviation (flag 4, RESOLVED by spec review round 1)**: a kwargs cutover breaks in-flight Sidekiq payloads at deploy time. All four production enqueue sites serialize a single positional argument today (`job.rb:707, 709, 723, 732`), including scheduled enqueues (`set(wait: 30.seconds)`, job.rb:707) and 2-minute `retry_on` retry waves (extract_job_criteria_job.rb:5), so positional `[id]` payloads can sit in the queue/scheduled set across a deploy. Against a kwargs signature, a deserialized old payload invokes `perform(123)` and raises `ArgumentError` at invocation — before the method body runs — so neither the method-level rescues nor `retry_on CustomErrorAiSummary` fire, no failure write happens, and the `AiJobCriteria` row is stranded in-flight forever (serializer reports in-flight; frontend button spins indefinitely). Optional positional keeps every old payload valid with zero transition machinery. The exhaustion block reads `job.arguments.first` / `job.arguments.second` — the positional counterpart of the analog's `job.arguments.first[:key]` reads (each form reads arguments in its own signature's shape, preserving the structural pattern).
- After the `extract` call in `perform`: `broadcast_completion(ai_job_criteria, requesting_organization_user_id) if requesting_organization_user_id` (skipped when a `CustomErrorAiSummary` retry is propagating, same as the analog — status is `retrying`, not terminal).
- In the `retry_on` exhaustion block (after the existing `update_columns(status: :failed, ...)`, line 9): look up the row and broadcast ONLY when the row exists — mirror the analog's `if textract_result` guard (generate_ai_job_application_summary_job.rb:17-21); a nil row must not reach `broadcast_completion` (its fresh read `AiJobCriteria.find_by(id: ai_job_criteria.id)` would raise NoMethodError on a nil row inside the exhaustion handler). Read args via `job.arguments` (`job.arguments.first` = id, `job.arguments.second` = requesting id).
- In the StandardError rescue (after line 28's failure write): broadcast when `requesting_organization_user_id` is present AND the re-looked-up row exists (the analog gates on both: `if textract_result && requesting_organization_user_id`, line 45).
- New private helper, mirroring the analog's structure (`generate_ai_job_application_summary_job.rb:50-80`):

```ruby
def broadcast_completion(ai_job_criteria, requesting_organization_user_id)
  requesting_organization_user = OrganizationUser.find_by(id: requesting_organization_user_id)
  return unless requesting_organization_user

  user = requesting_organization_user.user
  return unless user

  # (amended post-conventions-pass per backend/_base.md §8; plan R-1)
  ai_job_criteria = AiJobCriteria.find_by(id: ai_job_criteria.id)
  return unless ai_job_criteria

  return unless ai_job_criteria.status_succeeded? || ai_job_criteria.status_failed?

  payload = {
    status: ai_job_criteria.status_succeeded? ? 'succeeded' : 'failed',
    jobId: ai_job_criteria.job_id,
    jobTitle: ai_job_criteria.job.title,
    zeroCriteriaFailure: ai_job_criteria.zero_criteria_failure?
  }
  payload[:errorMessage] = ai_job_criteria.error_message if ai_job_criteria.status_failed? && ai_job_criteria.error_message.present?

  GlobalChannel.broadcast_to(
    user,
    action: 'JOB_CRITERIA_EXTRACTION_COMPLETE',
    payload: payload
  )
end
```

**Flagged deviation from DECISIONS' literal wording:** DECISIONS says "WebSocket success toast". The broadcast fires on failure too (exactly as the analog does) because (a) the frontend's loading state resolves via the payload refetch this event triggers — success-only would leave a failed regeneration spinning until manual reload, and (b) the zero-found/failed empty states (DECISIONS-required) need to appear when extraction finishes finding nothing. Auto-path extractions (`requesting_organization_user_id` nil) never broadcast — identical to the analog's auto path.

## 8. Frontend changes

### 8.1 New hook file — `app/javascript/shared/queryHooks/useAiJobCriteria.ts`

Modeled on `useAiJobApplicationSummary.ts` (query + mutation in one domain file, interfaces inline per `useBulkGenerateAiSummaries.ts:4-16`):

```ts
import { useMutation, useQuery, useQueryClient } from "react-query";
import { apiGet, apiPost } from "./api";

export interface AiJobCriterion {
  text: string;
  tier: "tier_1" | "tier_2" | "tier_3";
  sourceHeading?: string | null;
}

export interface AiJobCriteriaPayload {
  criteria: AiJobCriterion[] | null;
  extractedAt: string | null;
  status: "pending" | "in_progress" | "succeeded" | "failed" | "retrying" | null;
  zeroCriteriaFailure: boolean | null;
}

const getAiJobCriteria = async (jobId: number) => {
  return await apiGet({ path: `/jobs/${jobId}/ai_job_criteria` });
};

export function useAiJobCriteria({ jobId }: { jobId: number }) {
  return useQuery<AiJobCriteriaPayload>(["aiJobCriteria", jobId], () => getAiJobCriteria(jobId), {
    enabled: jobId != undefined,
  });
}

const regenerateAiJobCriteria = async ({ jobId }: { jobId: number }) => {
  return await apiPost({ path: `/jobs/${jobId}/ai_job_criteria`, variables: {} });
};

export function useRegenerateAiJobCriteria() {
  const queryClient = useQueryClient();
  return useMutation(regenerateAiJobCriteria, {
    onSuccess: (data, variables) => {
      queryClient.invalidateQueries(["aiJobCriteria", variables.jobId]);
    },
  });
}
```

Query key `["aiJobCriteria", jobId]` follows the `["aiJobApplicationSummary", id]` / `["jobs", jobId]` array-key convention (cursor_rules/frontend/react_query/react_query_queries.md "Query Keys"). Hook-level invalidation per react_query_mutations_and_cache.md "Hook-Level Callbacks".

### 8.2 Display-state derivation (single source of truth: the fetched payload)

| Priority | Condition (payload) | Rendering |
|---|---|---|
| 0 | query `isLoading` | `LoadingIndicator label="Loading..."` inside the Job criteria FormSection — the standard settings-view loading treatment (`OrganizationAiUsage.tsx:29-31`) |
| 1 | `status` ∈ pending/in_progress/retrying | Underlying content: row 4's card when `criteria` is present, else row 5's never-extracted EmptyState (rows 2-3 are unreachable underneath an in-flight latest row — `status` is not "failed" and `zeroCriteriaFailure` is false because the predicate reads the latest row). Generate/Regenerate button in `loading` state. Survives reload — this is backend status, not mutation state (DECISIONS requirement) |
| 2 | `status === "failed" && zeroCriteriaFailure` | Zero-found EmptyState: `icon="alert-triangle"`, title `"No criteria found"`, message `"No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against."`. Action row: `Regenerate criteria` only, no View button |
| 3 | `status === "failed"` (other) | Failure EmptyState (copy drafted, not designed — DECISIONS): `icon="alert-triangle"`, title `"Criteria generation failed"`, message `"Something went wrong while extracting criteria from the job description. Regenerate to try again."`. Action row: `Regenerate criteria` only, no View button |
| 4 | `criteria` present (status `"succeeded"`, or in-flight over an older success) | Criteria card + count rail; action row: `View criteria` + `Regenerate criteria` |
| 5 | `status === null` (never ran) | Never-extracted EmptyState: `icon="file-text"`, title `"No job criteria have been generated"`, message `"Plato extracts scoring criteria when you publish the job, or you can generate them now."`. Action row: `Generate criteria` only, no View button |

Button label: `Generate criteria` only in state 5 (and state 1 layered over state 5); otherwise `Regenerate criteria`. EmptyState always standard variant — NOT `roomy`, NOT `borderless` (`EmptyState.tsx:7-13` props verified).

**Action-row placement:** the per-state action rows render in the section, OUTSIDE the `EmptyState` component. `EmptyState` accepts only `title`/`message`/`icon`/`borderless`/`roomy` (EmptyState.tsx:7-13) — it has no action/button prop, and buttons must not be passed through its `message` prop. The action row is a section-level element rendered below the EmptyState (or below the card in state 4).

**Flagged spec decision:** when the latest row is `failed` but an older succeeded row exists (regeneration failed), rows 2/3 win over row 4 — the empty state replaces the card and the old criteria are not viewable. Rationale: scoring consults the latest row (`score_job_application.rb:19-30`), so in that state new reviews will not score against the old criteria; showing the card would misrepresent reality. The zero-found message ("Plato won't review candidates…") is literally true in that state because of the Section 6 guard.

### 8.3 `JobSetupAiSettings.tsx` (modified — `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx`)

Keep everything existing (title, description, Plato reviews FormSection, dirty tracking, bottom-bar Save — lines 15-80) untouched. Add:

- `useAiJobCriteria({ jobId: passedJob.id })` + `useModalContext` (`openModal`, `removeModal`).
- **Job criteria FormSection** below "Plato reviews": `<FormSection title="Job criteria">` with the section intro as body copy (FormSection's `intro` prop also exists — `FormSection/index.js:11,36` — either the `intro` prop or a styled paragraph is acceptable; use the `intro` prop, it is the component's own affordance and takes an element per its propTypes, `FormSection/index.js:47`). Intro copy (drafted; MUST explain the automatic lifecycle per DECISIONS; "job description" is an inline link):
  > Plato extracts scoring criteria from your job description when you publish the job, and extracts them again when you update the description while the job is published. Each review scores a candidate against the criteria as they stand when it runs. To change them, edit your <link>job description</link>.

  The link navigates to `/jobs/${passedJob.id}/setup/description` (route form verified at `RunPlatoAddDescriptionModal.tsx:32`), via `props.history.push` (router-prop navigation pattern per `OrganizationAiUsage.tsx:17-19`).
- **Criteria card** (state 4): flex card max-width 560px, radius 7px per DECISIONS visual specs; left cell = Plato disc + title "Job criteria" + description `Plato extracted these from your job description {distanceInWords(extractedAt)}.`; right cell = count rail (Core `check-circle` / Preferred `plus-circle` / Bonus `star`; Bonus row only when bonus criteria exist). Reuse **`PlatoChip`** for the disc (`PlatoMark.tsx:60-66` — already has the accent gradient + inset ring; `<PlatoChip size={36} radius={18} />` yields the 36px circle; DECISIONS: reuse the existing production asset). Relative time via `distanceInWords` (`app/javascript/shared/lib/time.ts:89-91`, takes ISO string, adds "ago"). Tabular figures on counts/timestamp.
- **Tier grouping**: a module-level `TIERS` constant `[{ key: "tier_1", label: "Core", icon: "check-circle" }, { key: "tier_2", label: "Preferred", icon: "plus-circle" }, { key: "tier_3", label: "Bonus", icon: "star" }]`; counts computed by filtering `criteria` on `tier`. (Design-bundle `tier1/tier2/tier3` keyed payload is NOT used — DECISIONS declares the shape ours; the stored values are `tier_1`-form, extract_criteria.rb:110-113.)
- **Action row**: `View criteria` (Button `styleType="secondary"`, rendered only in state 4) → `openModal(<JobCriteriaViewModal criteria={...} onCancel={removeModal} />)`. `Generate criteria`/`Regenerate criteria` (Button `styleType="secondary"`, `loading={isInFlight}` where `isInFlight` = payload status in-flight OR the modal-owned POST just fired and the query is refetching) → `openModal(<RegenerateJobCriteriaConfirmModal jobId={passedJob.id} onCancel={removeModal} />)`. `openModal`/`removeModal` pattern per `ChannelMessageListItem.tsx:52-64`.
- **Empty states** per Section 8.2 (three `EmptyState` instances).
- **Sidebar tier glossary** via `SettingsContainer`'s existing `sidebar` prop (`SettingsContainer.tsx:10,72`), following the Team-roles aside register exactly (`AccountTeam.tsx:441-477` — `Styled.Sidebar` sticky aside with h3, per-entry heading + paragraph with bold lead, no dividers; styled analog at `AccountTeam.tsx:515-552`). Entry headings carry the tier icon at 13px. Copy verbatim from DECISIONS ("Criteria tiers" title; intro; Core/Preferred/Bonus leads + descriptions per decisions.html wording; copy iteration expected later).
- **Styled components**: separate styled component per visual variant, no conditional variant props (pipeline rule 12); values from decisions.html/bundle-3 with poly theme tokens where they exist; theme colors only from `app/javascript/ats/styles/theme.ts` (core rule 2); no fabricated fallbacks (`criteria || []` is prohibited — guard with explicit conditionals; core rule 10 / pipeline rule 13); no `??` (frontend/_base.md §1); double quotes.
- If the extended component exceeds ~400 lines, extract the section into `components/JobCriteriaSection.tsx` in the same directory per cursor_rules/frontend/components/component_size_and_extraction.md (>400 → extract; a `jobSetup/components/` dir already exists). The plan should make the final call on file split; the section markup + 3 empty states + card/rail styles will likely cross the threshold.

### 8.4 View slide-over — `app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx` (new)

- `FullModal` (`app/javascript/ats/src/components/modals/FullModal.tsx` — verified: 50%-width right panel at `lg`, Esc + backdrop close built in via `onCancel`, custom header supported by omitting `headerTitleText`, lines 104-112). Opened via `openModal`, closed via `removeModal` passed as `onCancel`.
- Custom sticky header in children (bundle-3 `SlideHead` structure): h2 "Job criteria" (22px/600/-0.02em) + X icon button (28×28 hit area, Feather `x` 16px via `Icon`) calling `onCancel` — the FullModal built-in header renders a "Dismiss" text button, which the design overrides.
- Body: description paragraph (14px/400/1.6 secondary):
  > New reviews score candidates against these. To change them, edit the job description. Reviews that have already run keep the criteria they were scored against.
- Single bordered list container grouped by tier: tier head row (icon + label + count), criterion rows; empty tiers omitted; tiers after the first get top border + margin. **NO tier hint sentences** (decided OUT — bundle-3's `TierHint` is dropped). Read-only: no hover states, no footer.
- Props: `{ criteria: AiJobCriterion[]; onCancel: () => void }` — display-only; no data fetching inside.
- **Frozen-prop staleness consciously accepted (spec review round 1, pipeline rule 22):** props are captured at `openModal()` time (ModalContext.tsx:24-34), so if a regeneration completes while the slide-over is open, its content stays stale until closed and reopened. Acceptable for a read-only viewer — nothing interactive depends on the frozen `criteria`, and the completion toast + invalidated payload keep the section behind it current.

### 8.5 Regenerate confirm — `app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx` (new)

Closest analogs: `RunPlatoAddDescriptionModal.tsx` (CenterModal + statement box + actions — the exact "Run Plato modal anatomy" the design cites) and `BulkGenerateAiSummariesConfirmModal.tsx` (confirm modal that OWNS its mutation).

- `CenterModal` with `headerTitleText="Regenerate job criteria?"` (`CenterModal.tsx:13-24`; `headerTitleText` is required).
- Lead paragraph (manual variant ONLY — the after-description-update variant is decided OUT):
  > Plato will re-extract scoring criteria from the current job description. Reviews that have already run keep the criteria they were scored against.
- Bordered statement box with `refresh-cw` icon (mirror `Styled.Statement`, `RunPlatoAddDescriptionModal.tsx:63-75`):
  > Regenerating works best when you have changed the parts of the description that affect scoring, like requirements or responsibilities. Keeping regenerations rare keeps scores comparable across candidates. If the criteria change significantly, you can also regenerate all candidate reviews.
- Footer: primary Button `Regenerate criteria` + secondary `Cancel`.
- **Mutation ownership (pipeline rule 22):** the modal owns `useRegenerateAiJobCriteria()` internally, exactly as `BulkGenerateAiSummariesConfirmModal` owns `useBulkGenerateAiSummaries` (lines 43, 66-101). Internal hook state is live (only props are frozen at `openModal` time), so `loading={isLoading}` + `disabled={isLoading}` on the primary button work and prevent double-submits (pipeline rule 11: copy the analog's behavioral props, all of them). On success: `dismissModalWithAnimation(() => onCancel)` (analog line 90) — no queue toast; the section button enters loading via the invalidated payload, and the completion toast arrives over WebSocket. On error (blank description, flipper, etc.): warning toast `error?.data?.errors?.general?.[0] || "Could not regenerate job criteria"`, `delay: 10000` — the existing error-toast pattern in this exact file (`JobSetupAiSettings.tsx:39-45`) and the analog (lines 92-98). Modal stays open on error.
- Props: `{ jobId: number; onCancel: () => void }`.

### 8.6 WebSocket handler — `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` (modified)

New case alongside the AI summary cases (after line 248's `AI_SUMMARY_FAILED` block):

```tsx
case "JOB_CRITERIA_EXTRACTION_COMPLETE": {
  const payload = data.payload as JobCriteriaExtractionCompletePayload;
  if (payload.status === "succeeded") {
    addToast({ title: `Job criteria generated for ${payload.jobTitle}`, kind: "success", delay: 10000 });
  } else if (payload.zeroCriteriaFailure) {
    addToast({ title: `No criteria found in the job description for ${payload.jobTitle}`, kind: "warning", delay: 10000 });
  } else {
    addToast({ title: `Could not generate job criteria for ${payload.jobTitle}`, kind: "warning", delay: 10000 });
  }
  queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)]);
  break;
}
```

Toast shapes mirror the `AI_SUMMARY_COMPLETE` case (lines 216-234); `Number()` cast per the `attachExternalResumeComplete` precedent (line 153). Copy drafted per binding rules (sentence case, no em dashes, "extract" vocabulary, static button-free toasts); iteration expected.

### 8.7 Payload type — `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` (modified)

```ts
export interface JobCriteriaExtractionCompletePayload {
  status: "succeeded" | "failed";
  jobId: number;
  jobTitle: string;
  zeroCriteriaFailure: boolean;
  errorMessage?: string;
}
```

Update the file's header comment to say "AI WebSocket broadcasts" (it currently says "AI summary"). Import the type in the handler alongside the existing imports (line 7).

## 9. Authorization requirements

- **GET show** → `authorize job, :show?` — `JobPolicy#show?` (`app/policies/job_policy.rb:12-14`): hiring-team member or org admin. Criteria are job-setup content; whoever can see the job's setup can see them.
- **POST create (regenerate)** → `authorize job, :update?` — `JobPolicy#update?` (`job_policy.rb:20-22`) = `on_hiring_team?` = `is_org_admin? || record.users.include?(user)` (`job_policy.rb:58-60`): any hiring-team member OR org admin. Same gate that governs editing the job description. **Rationale (Jessica, 2026-07-03, overrides the earlier `update_ai_settings?` choice):** regeneration consumes NO credits, and editing the job description — open to any hiring-team member under `update?` — already re-triggers extraction on a published job. Gating the explicit Regenerate button by the stricter AI-credits-control permission while the equivalent-power description edit is open to the whole team is incoherent. Nothing should block a hiring-team member or admin from regenerating. **No new policy methods.**
- Organization scoping via `current_organization.jobs` lookup in both actions.
- Flipper `AI_APPLICANT_SUMMARY` gate on POST only (Section 5.2). GET is ungated like `GET /ai_credits` (`organization_ai_credit_balance_controller.rb:4-9`) — read-only and harmless for non-AI orgs (returns the all-null payload).

## 10. Constraints and requirements (binding)

- **Decided OUT — do not build:** guard modals (≤5-criteria warning, 0-criteria popup — bundle-3's `guard` state/`GuardTitle`/`GuardBody`/`GuardFoot` are discarded); after-description-update confirm variant; tier hint sentences in the slide-over; anything touching `internal_job_criteria`.
- **Copy rules:** no em dashes; sentence case; no emoji; "extract" never "read"; "count most/less toward the score" never "weight/heaviest"; static button labels (no interpolated counts); timestamps only in the card description; never "candidates will be rescored" (scoring is point-in-time).
- **Regenerate allowed in ANY job state** (draft, unpublished, published). No job-status checks anywhere in the new endpoint or UI.
- **Visual specs** per DECISIONS: radius 7px, disc 36px with accent gradient + inset ring, count rail 186px, description 14px/400/1.6 secondary, card meta 12.5px/1.3, weights 400/450/500/600 only, tabular figures, Feather icons 2px stroke, monochrome neutrals + accent gradient only, poly theme tokens where they exist.
- **Loading states are mandatory** (recent failure mode): initial-fetch LoadingIndicator; in-flight button loading driven by backend status.
- Pipeline rules explicitly in play: 11 (copy analog behavioral props — `loading`+`disabled` on confirm), 12 (separate styled components), 13 (no fabricated fallbacks), 14 (structural analog matching — signatures compared above; deviations flagged inline), 22 (mutation lives inside the modal so no frozen-prop loading bug), 25 (`update_columns` usage), 26 (falsifiable tests below).

## 11. Existing patterns to follow (file map)

| Pattern | File |
|---|---|
| Job-nested singleton route with explicit controller | `config/routes.rb:189` (`resource :ai_credits`) |
| AI-scoring controller shape (exists/authorize/render_one, create-returns-resource) | `app/controllers/api/v1/ai_job_application_summaries_controller.rb` |
| Singleton show controller | `app/controllers/api/v1/organization_ai_credit_balance_controller.rb` |
| Serializer conventions (computed delegation, jsonb pass-through) | `app/serializers/api/v1/organization_ai_credit_balance_serializer.rb`, `cursor_rules/backend/serializers.md` |
| Completion broadcast job (kwarg threading, 3 broadcast sites, terminal-status guard) | `app/jobs/generate_ai_job_application_summary_job.rb` |
| Websocket handler case (toast + invalidate) | `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:216-248` |
| Query/mutation hook file | `app/javascript/shared/queryHooks/useAiJobApplicationSummary.ts`, `useBulkGenerateAiSummaries.ts` |
| Settings view loading treatment | `app/javascript/ats/src/views/accountAdmin/OrganizationAiUsage.tsx:29-31` |
| Sidebar aside register | `app/javascript/ats/src/views/accountAdmin/AccountTeam.tsx:441-477, 515-552` |
| Confirm modal owning its mutation | `app/javascript/ats/src/views/jobApplications/BulkGenerateAiSummariesConfirmModal.tsx` |
| CenterModal + statement box | `app/javascript/ats/src/views/jobApplications/RunPlatoAddDescriptionModal.tsx` |
| FullModal with custom header | `app/javascript/ats/src/components/modals/FullModal.tsx:104-112` |
| openModal/removeModal | `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageListItem.tsx:52-64` |
| Plato disc asset | `app/javascript/ats/src/components/shared/PlatoMark.tsx` (`PlatoChip`) |
| Relative time | `app/javascript/shared/lib/time.ts:89` (`distanceInWords`) |
| Controller spec harness (auth stubbing) | `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb:25-37` |

## 12. Test plan (pipeline rule 3)

### New RSpec

- **`spec/controllers/api/v1/ai_job_criteria_controller_spec.rb`** (new; harness copied from `bulk_ai_job_application_summaries_controller_spec.rb:5-37`):
  - `#show`: payload for each of the six states in the Section 5.3 table (never ran → all null; succeeded → criteria/extracted_at/status; in-flight over old success → old criteria + in-flight status; zero-criteria failed → `zero_criteria_failure: true`; other failed → `false`).
  - `#create`: creates a pending `AiJobCriteria` row and enqueues `ExtractJobCriteriaJob` with the row id and `current_organization_user.id`; blank description → 422 with the exact error message and NO row created; Flipper disabled → 422, no row; latest row `in_progress`/`retrying` → 200, no new row (no-op guard); works on draft AND published jobs (regenerate-any-state requirement); authorization (amended per §9 to the `update?` gate) → a hiring-team member without AI-credits control is allowed on BOTH `show` and `create` (regenerate is gated by `JobPolicy#update?` = hiring-team member OR admin, not by AI-credits control); a user who is neither on the hiring team nor an admin is rejected (403) on `create`.
- **`spec/interactors/validate_ai_summary_generation_spec.rb`** (new — no dedicated spec exists today; the interactor is currently covered only indirectly): happy path succeeds; fails with the zero-criteria message when the job's latest `AiJobCriteria` is `failed` with each of the three `ZERO_CRITERIA_ERROR_MESSAGES`; does NOT fail when latest is `failed` with `'Job description is blank'`, when latest is `pending`, or when an in-flight row sits on top of a zero-criteria row.
- **`spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`** (new; dir precedent `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb`): attribute derivation for the mixed state (latest failed-zero over older succeeded → criteria from the succeeded row, status `failed`, `zero_criteria_failure` true).

### Modified RSpec (rule: every modified behavior gets its existing spec updated)

- **`spec/models/job_criteria_lifecycle_spec.rb`** — add `describe 'Job#extract_job_criteria_immediately'` (blank description → no row; `in_progress` latest → no row; `retrying` latest → no row; `pending` latest → row IS created (documents the deliberate absence of a pending guard); passes `requesting_organization_user_id` through to `ExtractJobCriteriaJob` args; nil default) and `describe 'Job#extract_job_criteria_if_needed'` (succeeded → no-op; failed/none → delegates to `_immediately`). Existing `extract_job_criteria` examples are untouched (that method is unchanged).
- **`spec/models/ai_job_criteria_spec.rb`** — `#zero_criteria_failure?` truth table (3 messages × failed = true; same messages × non-failed = false; failed × other message = false; nil error_message = false).
- **`spec/jobs/extract_job_criteria_job_spec.rb`** — behavioral broadcast coverage (pipeline rule 26 — assert outcomes, not reflection): with a requesting org user, success → `GlobalChannel` receives `broadcast_to` with `action: 'JOB_CRITERIA_EXTRACTION_COMPLETE'` and `status: 'succeeded'`; zero-criteria failure → `zeroCriteriaFailure: true`; StandardError → failed broadcast; `CustomErrorAiSummary` → job re-enqueued (`have_enqueued_job`) and NO broadcast; without a requesting user → no broadcast ever.
- **`spec/interactors/validate_auto_ai_summary_generation_spec.rb`** — zero-criteria fail context (mirror of the new ValidateAiSummaryGeneration contexts).
- **`spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`** — new context: `job:` with zero-criteria failure → `context.fail!` with the message, nothing enqueued, no claim rows created; existing examples updated only if they assert on context inputs (the `job` input is optional/safe-nav, so existing calls without it must still pass — assert that too).
- **`spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb`** — both actions now pass `job:` to `QueueBulkAiSummaryJobs` (update the `hash_including` expectation at line 72-77) and a zero-criteria job returns 422.
- **`spec/models/textract_result_ai_trigger_spec.rb`** (or a focused new context in the same file) — `generate_ai_summary_with_credit_flow` returns before invoking `AiJobApplicationAction::Orchestrate` and before `extract_job_criteria_if_needed` when the job has a zero-criteria failure.
- **`spec/jobs/bulk_generate_ai_summaries_job_spec.rb`** — validation-failure iteration marks the claim row `:failed` (not left `:processing`); zero-criteria job batch → all rows `:failed`, completion notification still fires.

### Frontend tests

**None** — documented decision, not an omission: the codebase has no view/hook unit-test infrastructure in use (`app/javascript` contains a single component test, `Button.test.tsx`; no view or hook tests exist to extend). Frontend behavior is verified in the LIFECYCLE QA phase (Phase 8) against the running app, per this pipeline's established practice. No Cypress specs are added for the same reason (no existing job-setup Cypress coverage to extend was found under `cypress/`).

## 13. Complete file inventory

### New files
| File | What |
|---|---|
| `app/controllers/api/v1/ai_job_criteria_controller.rb` | GET show / POST create |
| `app/serializers/api/v1/job_ai_job_criteria_serializer.rb` | Criteria payload off Job |
| `app/javascript/shared/queryHooks/useAiJobCriteria.ts` | `useAiJobCriteria` + `useRegenerateAiJobCriteria` |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx` | FullModal slide-over |
| `app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx` | Confirm modal owning the mutation |
| `spec/controllers/api/v1/ai_job_criteria_controller_spec.rb` | Controller coverage |
| `spec/interactors/validate_ai_summary_generation_spec.rb` | Validator coverage incl. new guard |
| `spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb` | Serializer coverage |
| (conditional) `app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx` | Only if `JobSetupAiSettings.tsx` crosses the 400-line extraction threshold |

### Modified files
| File | Change |
|---|---|
| `app/models/job.rb` | 4.1 gating change + kwarg; 4.3 `zero_criteria_extraction_failure?` |
| `app/models/ai_job_criteria.rb` | 4.2 constants + `zero_criteria_failure?` |
| `app/models/textract_result.rb` | 6.2.4 defensive guard in `generate_ai_summary_with_credit_flow` |
| `app/jobs/extract_job_criteria_job.rb` | 7 signature + `broadcast_completion` at 3 sites |
| `app/jobs/bulk_generate_ai_summaries_job.rb` | 6.3 validation-fail row status fix |
| `app/interactors/validate_ai_summary_generation.rb` | 6.2.1 zero-criteria fail! |
| `app/interactors/validate_auto_ai_summary_generation.rb` | 6.2.2 zero-criteria fail! |
| `app/interactors/queue_bulk_ai_summary_jobs.rb` | 6.2.3 `job` input + fail! |
| `app/controllers/api/v1/bulk_ai_job_application_summaries_controller.rb` | pass `job: @job` in both actions |
| `app/services/ai_job_application_action/scoring/extract_criteria.rb` | constants at lines 62, 122 |
| `app/services/ai_job_application_action/scoring/score_job_application.rb` | constant at line 43 |
| `config/routes.rb` | nested singleton resource |
| `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` | Job criteria section, sidebar, modals wiring |
| `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` | `JOB_CRITERIA_EXTRACTION_COMPLETE` case |
| `app/javascript/shared/types/aiSummaryWebsocketPayloads.ts` | new payload interface + header comment |
| `spec/models/job_criteria_lifecycle_spec.rb`, `spec/models/ai_job_criteria_spec.rb`, `spec/jobs/extract_job_criteria_job_spec.rb`, `spec/interactors/validate_auto_ai_summary_generation_spec.rb`, `spec/interactors/queue_bulk_ai_summary_jobs_spec.rb`, `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb`, `spec/models/textract_result_ai_trigger_spec.rb`, `spec/jobs/bulk_generate_ai_summaries_job_spec.rb` | per Test plan |

## 14. Flagged decisions for the review gate

1. `requesting_organization_user_id:` kwarg added to the DECISIONS.md `extract_job_criteria_immediately` block (Section 4.1) — reconciliation, not contradiction.
2. `'Criteria array is empty'` included in `ZERO_CRITERIA_ERROR_MESSAGES` (Section 4.2) — beyond DECISIONS' two named messages.
3. Failure broadcasts in addition to the DECISIONS "success toast" (Section 7) — required for loading-state resolution and the failed/zero-found states; mirrors the analog exactly.
4. `ExtractJobCriteriaJob` optional positional arg vs the analog's kwargs (Section 7) — RESOLVED by spec review round 1: positional stands. A kwargs conversion would break in-flight positional Sidekiq payloads at deploy (ArgumentError at invocation bypasses all rescues and `retry_on`, stranding rows in-flight with no failure write). Full evidence in reviews/spec-round-1/gating-job-signature-broadcast.md.
5. Display precedence: failed latest row hides an older succeeded card (Section 8.2) — matches scoring semantics.
6. `BulkGenerateAiSummariesJob#each_iteration` claim-row fix (Section 6.3) — shared-infrastructure change included as reviewed scope.
7. `QueueBulkAiSummaryJobs` gains an optional `job` context input (Section 6.2.3) — signature extension to an existing interactor.
