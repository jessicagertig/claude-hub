# Deep Investigation Results

Exhaustive inventory of existing code relevant to the 8 outline components. Ground truth for design decisions.

## 1. Existing AI Summary Pipeline

### AiJobApplicationSummary Model
**File:** `app/models/ai_job_application_summary.rb`

**Schema columns:**
| Column | Type | Default | Null? |
|--------|------|---------|-------|
| job_application_id | bigint | — | NOT NULL |
| textract_result_id | bigint | — | nullable |
| structured_data | jsonb | — | nullable |
| headline | string | — | nullable |
| summary_text | text | — | nullable |
| status | integer | 0 | NOT NULL |
| error_message | text | — | nullable |
| stale | boolean | false | NOT NULL |
| requested_by_organization_user_id | bigint | — | nullable |

**Status enum** (prefix: true): `pending: 0`, `in_progress: 1`, `succeeded: 2`, `failed: 3`, `extracted: 4`, `textract_processing: 6` (5 skipped)

**Associations:**
- `belongs_to :job_application`
- `belongs_to :textract_result, optional: true`
- `has_many :ai_api_requests, as: :requestable` (polymorphic)

**Instance methods:** `total_input_tokens`, `total_output_tokens`, `total_cost` — all `.sum()` over `ai_api_requests`

**Callback:** `after_commit :destroy_previous_textract_results, on: :update` — cleans up old textract results when summary succeeds

### Generate Service
**File:** `app/services/ai_job_application_action/summary/generate.rb` (315 lines)

4-call pipeline, all `gpt-4o-mini` via OpenAI:
1. **ResumeStructuredData** — extract name, work_experience, education, skills from OCR text + job_title
2. **ResumeAssessment** — role-blind domain classification, career narrative, key skills (anonymized)
3. **ResumeComparison** — role-aware: applicable_experience, gaps, overlap_summary (uses `job.title` only, NOT `job.description`)
4. **ResumeSummary** — headline, summary, role_analysis

Each call creates an `AiApiRequest` via `create_ai_api_request`. Data accumulates in `structured_data` jsonb.

**Error handling:** `CustomErrorAiSummary` re-raises (triggers job retry), `JSON::ParserError` and `StandardError` set status to `:failed` without re-raise.

### Scoring Pipeline (Prompt-Only)
**Directory:** `app/services/ai_job_application_action/scoring/prompts/`

8 prompt files exist. NO orchestration service (`generate.rb` equivalent) exists. No controller, serializer, or model for scoring.

| File | Model Constant | Status |
|------|---------------|--------|
| job_description_structured_data.rb | gpt-4.1-mini | ACTIVE (Call 1) |
| job_description_criteria_extraction.rb | gemini-3.1-flash-lite (wrong, should be gpt-4o) | ACTIVE (Call 2) |
| criteria_review.rb | gemini-3.1-flash-lite | NOT IN USE |
| criteria_decomposer.rb | gpt-4o-mini | NOT IN USE |
| criteria_decomposition_judge.rb | gemini-3.1-flash-lite | NOT IN USE |
| criteria_expansion.rb | gemini-3.1-flash-lite | NOT IN USE |
| candidate_criteria_scoring.rb | gpt-4o-mini (wrong, should be Gemini) | ACTIVE (Call 4) |
| scoring_display.rb | no MODEL constant | ACTIVE (Call 5, on spike branch) |

## 2. Job Model Lifecycle

**File:** `app/models/job.rb`

### Publishing Flow
`PUT /api/v1/jobs/:id/publish` → `JobsController#publish` → `job.published!`

Callbacks on publish (`handle_status_changed_to_published`):
- `touch(:published_at)`
- `update_column(:originally_published_at, ...)` (first publish only)
- Enqueues: `Notification::JobStatusChangeJob`, `JobPingGoogleIndexJob`, `UpdateStripeSubscriptionJob`, `CareersPageSubscriptionsNotifierJob`, `RegisteredWebhooks::NewJobPublishedJob`
- Updates distributions (WWR, Webflow, WhatJobs)

**Publishing does NOT trigger Textract or AI summary generation.** AI is triggered only at JobApplication level.

### Description Storage
- `description` column: text, stored as HTML, sanitized on save
- `requirements` column: separate text field, also HTML
- No plain-text column — `description_without_html` strips on the fly
- No description-change detection exists

### AI-Related Fields on Job
- `auto_generate_ai_summaries` enum: `default: 0`, `enabled: 1`, `disabled: 2`
- `should_auto_generate_ai_summaries?` method: job-level override → falls back to `organization.auto_generate_ai_summaries_enabled` (settings jsonb)
- `has_many :ai_job_application_summaries, through: :job_applications` (indirect)

### JobApplication Model
**File:** `app/models/job_application.rb`

- `has_many :textract_results, dependent: :destroy`
- `has_many :ai_job_application_summaries, dependent: :destroy`
- `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }`
- `after_commit :enqueue_new_job_application, on: :create` → enqueues `SubmitResumeToTextractJob` if Flipper `:TEXTRACT_RESUME_PROCESSING` enabled

## 3. Full Trigger Chain (Current)

```
JobApplication created (after_commit)
  → SubmitResumeToTextractJob
    → SubmitResumeToTextract service
      → Creates TextractResult (status: in_progress)
      → Marks existing AI summaries as stale
      → GetResumeTextFromTextractJob (2-minute delay)
        → GetResumeTextFromTextract service
          → Updates TextractResult with textract_job_result_text
            → TextractResult#queue_ai_summary_job (after_commit)
              → Checks Job#should_auto_generate_ai_summaries?
              → ValidateAiSummaryGeneration (Flipper + credits + resume)
              → GenerateAiJobApplicationSummaryJob
                → TextractResult#generate_ai_summary_with_credit_flow
                  → AiJobApplicationAction::Summary::Generate (4 AI calls)
                  → CreateAiCreditBalanceTransaction (1 credit)
                  → NotifyZeroAiCredits / NotifyLowAiCredits
```

Manual trigger: `AiJobApplicationSummariesController#create` → same chain from ValidateAiSummaryGeneration onward

Bulk trigger: `BulkGenerateAiSummariesJob` (job-iteration) → same pipeline per application

## 4. Serialization Layer

### AiJobApplicationSummary Serializers
- **Full:** `Api::V1::AiJobApplicationSummarySerializer` — `id, status, headline, summary_text, structured_data, job_application_id, stale, created_at`
- **Shallow:** `Api::V1::AiJobApplicationSummaryShallowSerializer` — `id, status, headline, summary_text, stale, created_at` (omits `structured_data`)

### How AI Data Reaches Frontend
- `JobApplicationSerializer` includes `has_one :ai_job_application_summary` using **shallow** serializer via `object.latest_ai_job_application_summary`
- Direct fetch via `AiJobApplicationSummariesController#show` returns **full** serializer
- Job index (`ShallowJobApplicationSerializer`) does NOT include AI data
- `JobSerializer` includes `auto_generate_ai_summaries` only

### No Scoring Serialization Exists
No serializer, controller action, or API endpoint for scoring data.

## 5. Infrastructure

### AiApiRequest Model
**File:** `app/models/ai_api_request.rb`

Polymorphic via `requestable_type` / `requestable_id`. Currently only `AiJobApplicationSummary`.

Columns: `organization_id`, `requestable_type`, `requestable_id`, `call_type`, `provider`, `model`, `input_tokens`, `output_tokens`, `cost` (decimal 10,6), `prompt_text`, `response_body`

### AiClient
**File:** `app/services/ai_client.rb`

Providers: openai, deepseek, mistral, gemini, anthropic
PRICING hash: 10 models with `[input_per_1M, output_per_1M]`
No retries at client level — retries at job level.

### Provider Temperature Settings
| Provider | Temperature |
|----------|------------|
| OpenAI | 0 (hardcoded) |
| Gemini | default (none set) |
| Anthropic | none set |

OpenAI has explicit timeouts (120s/30s). Others have none.

### Sidekiq
**Config:** `config/sidekiq.yml`
Queues: `critical:6`, `default:2`, `mailers:1`, `exports:1` + ActionMailbox/ActiveStorage
Concurrency: 5 default, 10 production
No dedicated AI queue. All AI jobs use `:default`.

### WebSocket Broadcasts
Channel: `GlobalChannel` — streams per-user and "all_users"

| Event | Trigger | Payload |
|-------|---------|---------|
| AI_SUMMARY_COMPLETE | GenerateAiJobApplicationSummaryJob (manual trigger only) | status, candidateFullName, jobApplicationLink, errorMessage? |
| AI_SUMMARY_FAILED | TextractResult validation failure | candidateFullName, jobApplicationLink, errorMessage |
| AI_SUMMARY_BULK_COMPLETE | BulkGenerateAiSummariesJob on_complete | succeededCount, failedCount, skippedCount, hiringStageLink |
| AI_SUMMARY_BULK_FAILED | BulkGenerateAiSummariesJob retry exhaustion | jobTitle, message |

### Flipper Flags (AI-relevant)
| Flag | Purpose | Check Location |
|------|---------|---------------|
| `:AI_APPLICANT_SUMMARY` | Master switch for AI summaries | ValidateAiSummaryGeneration, QueueBulkAiSummaryJobs |
| `:AI_DAILY_CREDITS` | Daily credit reset | ResetDailyAiCredits |
| `:TEXTRACT_RESUME_PROCESSING` | OCR pipeline | JobApplication, JobApplicationsController |

All per-organization actor-based: `Flipper.enabled?(:FLAG, organization)`

## 6. Billing / Plans / Credits

### Plan System
No separate Plan model. Integer enum on `organizations.plan`:
- Current tiers: `plan_ats_tier_free_v2: 40`, `starter_v2: 41`, `growth_v2: 42`, `scale_v2: 43`, `enterprise: 1000`
- `plan_no_plan: 101` (default on creation)

Key methods on `Stripe::SubscriptionStatusChecker`:
- `paid_plan?` — non-free, non-no_plan
- `in_good_standing?` — paid plan + stripe sub + period not expired + status active/trialing/etc

### Credit System (4-bucket)
**Model:** `OrganizationAiCreditBalance` (one row per org)
Buckets: `daily_credits_remaining`, `monthly_credits_remaining`, `addon_subscription_credits_remaining`, `addon_credits_remaining`
Consumption order: daily → monthly → addon_subscription → addon

**Monthly allocation by plan:**
| Plan | Credits |
|------|---------|
| Free / No plan | 25 |
| Starter | 50 |
| Growth | 100 |
| Scale | 250 |
| Enterprise | 500 |

Daily allocation: 5 credits (requires Flipper `:AI_DAILY_CREDITS`)

**Ledger:** `AiCreditBalanceTransaction` — insert-only, `counter_culture` atomic updates
- Entry type `ai_summary_usage_debit: 60` — current consumption
- **Entry types 70+ reserved for future AI feature usage categories**

### Three Gates for AI Summary Generation
1. Flipper `:AI_APPLICANT_SUMMARY` enabled for org
2. Credits available (`organization.ai_credits_available?`)
3. Resume present on job application

**Plan does NOT gate AI access** — only determines monthly credit allocation. Even free plans get 25 credits. Flipper flag is the actual on/off switch.

### Authorization
`AiJobApplicationSummaryPolicy#can_use_ai_credits?`: org admin OR (org user + `hiring_team_ai_credits_control_enabled` setting)

## 7. Design-Critical Discoveries

1. **AiApiRequest is polymorphic** — new scoring model can use `has_many :ai_api_requests, as: :requestable` with zero schema changes to `ai_api_requests`

2. **Entry types 70+ reserved** — `AiCreditBalanceTransaction` already has space for a new scoring debit entry type

3. **No job-level AI trigger exists** — publishing fires no AI processing. Criteria extraction trigger is entirely new infrastructure.

4. **No description-change detection** — must be built from scratch. `stale` flag exists on AiJobApplicationSummary but is only set by textract re-submission, never by JD changes.

5. **Summary Call 3 (comparison) uses job.title only** — scoring results need to feed into a new field, not existing role_analysis

6. **auto_generate_ai_summaries enum** — same cascade pattern (job override → org default) should apply to scoring

7. **Flipper flags are per-org** — can reuse `:AI_APPLICANT_SUMMARY` or create new `:AI_SCORING` flag

8. **All AI jobs on :default queue** — no priority separation between summary and scoring work

9. **GlobalChannel broadcasts to requesting user only (manual trigger)** — auto-generated summaries have no broadcast. Need to decide if scoring follows same pattern.

10. **Credit cost is 1 per summary** — scoring cost TBD. If criteria extraction is free (per-job, not per-candidate) and only candidate scoring costs credits, the math is different.

11. **ValidateAiSummaryGeneration is tightly coupled to summaries** — cannot reuse directly for scoring without either extending or creating a parallel validator.

12. **BulkGenerateAiSummariesJob uses job-iteration** — good pattern to follow for bulk scoring.

13. **`free_plan_paid_features_enabled` boolean on Organization** — overrides free plan feature denials. May apply to scoring too.

14. **OrganizationAiCreditPurchase exists** — credit pack purchases (one-off and subscription). Scoring consumption would draw from same credit pool.
