# Reference Fidelity + Internal Consistency — Round 2

## Findings

- F1 [MED] SPEC.md lines 129-132 / **Internal inconsistency: "Textract success handler" section still says "OR" for call site, but "Changes > Call site" section (lines 193-197) specifically chose `after_commit` with background job.** The "Integration point" paragraph at lines 129-132 reads: "The new extraction service call goes in `GetResumeTextFromTextract#parse_resume_text` after the successful update, OR via a new `after_commit` callback on TextractResult." The Round 1 amendments resolved this choice at lines 193-197: "Integration: add a new `after_commit` callback on `TextractResult`..." The old section must be updated to match the decision. / Fix: replace the "Integration point" paragraph to state the decided approach (after_commit callback + background job) and remove the "OR" alternative.

- F2 [MED] SPEC.md line 207 / **Model section omits `has_many :ai_api_requests, as: :requestable`.** The Service section (line 174) says: "This requires adding `has_many :ai_api_requests, as: :requestable` to `TextractResult`." But the Model section (line 207) only lists: "`include PgSearch::Model`, `pg_search_scope :search_resume_text`, and `search_resume_by_keyword` class method." The Model section should enumerate ALL changes to the model file. The `has_many :ai_api_requests` association is a model change, not a service change. / Fix: add `has_many :ai_api_requests, as: :requestable` to the Model section's change list.

- F3 [MED] SPEC.md line 174 / **`call_type` value for AiApiRequest not specified.** The spec says "Creates an `AiApiRequest` record for the GPT-4o-mini call" but doesn't state what `call_type` value to use. The existing extraction uses `call_type: 'extraction'` (generate.rb:56). Using the same value would conflate the two paths in cost reporting — you couldn't distinguish "extraction for keyword search" from "extraction for AI summary." Using a different value (e.g., `'keyword_extraction'`) distinguishes them but adds a new call_type. The `call_type` column is a plain string with only a presence validation (ai_api_request.rb:7), not an enum, so any value works. / Fix: specify the `call_type` value explicitly. Recommend `'keyword_extraction'` to distinguish from the summary pipeline's `'extraction'`.

- F4 [MED] SPEC.md line 174 / **`organization` required for AiApiRequest but not mentioned in service.** The `ai_api_requests` table has `organization_id NOT NULL`. The existing pattern gets organization via `@organization = @job_application.job&.organization` (generate.rb:20). The new service needs to do the same: `textract_result.job_application.job&.organization`. The spec references "Match the existing pattern in `create_ai_api_request`" but doesn't call out that `organization` is required and must be navigated from TextractResult. If the organization is nil (possible via `&.` safe navigation), the AiApiRequest.create will fail on the NOT NULL constraint. / Fix: explicitly state how to obtain the organization and handle the nil case.

- F5 [LOW] SPEC.md lines 211-221 / **Backfill "enqueue a background job" pattern is novel in this codebase.** All existing data migrations (checked `db/data/` — 10 files, including the recent `create_organization_ai_credit_balances` at `20260408040801`) iterate inline in `up`. None enqueue Sidekiq jobs. The enqueue-from-migration pattern has a risk: if Sidekiq isn't running when the migration runs (e.g., during a deploy that starts workers after migrations), the job is enqueued but never processes. The migration is marked "up" regardless. This is an acceptable trade-off given the API-call-per-record requirement, but it should be noted. / Not blocking — but the spec should acknowledge that the backfill job must be monitored separately from the deploy to confirm completion.

## Verified — No New Issues

- **`sql_definition:` migration syntax** (lines 155-164): Confirmed correct. The `fx` 0.8.0 `create_trigger` method accepts `sql_definition:` as a keyword in the options hash (verified at `/Users/jessica/.rvm/gems/ruby-3.1.6@wrkhq-gemset-v2/gems/fx-0.8.0/lib/fx/statements/trigger.rb:30-53`). Including `on: :textract_results` is required for rollback — `invert_create_trigger` passes args to `drop_trigger`, which calls `options.fetch(:on)`.
- **`cursor_rules/backend/services.md`** exists and confirms rules 2 (descriptive method names, not `call`) and 3 (IDs from jobs, objects in request cycle) — both correctly referenced by Round 1 amendments.
- **AiApiRequest requestable polymorphic** confirmed: `belongs_to :requestable, polymorphic: true` at ai_api_request.rb:5. Two other models already use it (`AiJobApplicationSummary`, `AiJobCriteria`).
- **Flattening algorithm** (lines 179-191): Complete and clear. All schema fields accounted for.
- **Test requirements** (lines 227-240): Covers the right areas. Existing tests correctly identified.
- **pg_search and fx gem versions**: Confirmed and closed in Round 1.

## Amendments Needed

1. (F1) Update "Textract success handler > Integration point" paragraph to reflect the `after_commit` + background job decision
2. (F2) Add `has_many :ai_api_requests, as: :requestable` to the Model section
3. (F3) Specify `call_type` value for the new AiApiRequest
4. (F4) Specify how to obtain `organization` for AiApiRequest and handle nil
