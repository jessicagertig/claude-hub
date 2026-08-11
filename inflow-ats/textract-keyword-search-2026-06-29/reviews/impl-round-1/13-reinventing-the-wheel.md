# reinventing-the-wheel -- Round 1

## Findings

No issues found.

## Verified

- **Prompt/schema**: Reuses `AiJobApplicationAction::Summary::Prompts::ResumeStructuredData` for the GPT-4o-mini call -- the exact same prompt class used by the existing AI summary pipeline's Call 1. Does not duplicate the prompt, schema, or model selection.

- **AiClient**: Reuses `AiClient.new(provider: 'openai')` and `ai_client.chat(messages:, model:, response_format:)` -- the existing AI provider abstraction. Does not create a new HTTP client or OpenAI wrapper.

- **AiApiRequest**: Reuses the existing `AiApiRequest.create(...)` pattern with the same fields as `AiJobApplicationAction::Summary::Generate#create_ai_api_request` (generate.rb:296-313). Does not create a new cost tracking mechanism.

- **AiClient.calculate_cost**: Reuses the existing cost calculation utility with the same `.to_f.round(6)` pattern.

- **Error class pattern**: `CustomErrorStructuredExtraction` follows the exact structure of `CustomErrorTextract` and `CustomErrorAiSummary` -- same `attr_reader :param`, same constructor signature. Does not invent a new error hierarchy.

- **Job retry pattern**: `retry_on CustomErrorStructuredExtraction, wait: 5.minutes, attempts: 3 do |job, error| ... end` matches `GetResumeTextFromTextractJob` (retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3). Does not invent a new retry mechanism.

- **Callback pattern**: `after_commit :queue_structured_extraction_job, on: [:create, :update]` mirrors the existing `after_commit :queue_ai_summary_job, on: [:create, :update]`. Same event types, same callback structure.

- **pg_search_scope**: Reuses the `pg_search` gem (already in Gemfile at 2.3.2) with the same configuration pattern as the reference branch. Does not build a custom full-text search implementation.

- **fx gem for triggers**: Uses the `fx` gem's `create_trigger` API rather than raw SQL for trigger management. This is the same approach as the reference branch.

- **find_each for batching**: Uses ActiveRecord's built-in `find_each(batch_size: 100)` for memory-efficient iteration in the backfill. Does not build a custom batching mechanism.
