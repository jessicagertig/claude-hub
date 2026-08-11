# websocket-broadcast contract (incl. FE) (W4) — Round 1

Traced model `broadcast_status_change` -> `JobChannel` event -> `WebsocketJobChannelHandler` invalidation -> `useAiJobApplicationSummary` refetch -> `PlatoTab` loading branch -> `PlatoLoadingState` stepper, and confirmed all `awaiting_job_criteria`/`retrying` writers.

Chain: `ai_job_application_summary.rb:23,100-111` -> `summary/generate.rb:175` -> `WebsocketJobChannelHandler.tsx:73-76` -> `PlatoTab.tsx:157-174` -> `PlatoLoadingState.tsx:8-13,22-28,37`.

## All status writers verified (grep app/)
- `awaiting_job_criteria` writers: `score_job_application.rb:22,28,44`, `orchestrate.rb:72` -- ALL `.update` (callback-firing) -> broadcast automatically once added to BROADCAST_STATUSES. No `update_columns` writer missed. CONFIRMED.
- `retrying` writers on `AiJobApplicationSummary`: `score_job_application.rb:129` (`.update`), `integrate_analysis.rb:59` (`.update`) -> broadcast automatically; `generate.rb:175` (`update_columns`) -> needs conversion. CONFIRMED only `:175` needs it.
- `extract_criteria.rb:146` `@ai_job_criteria&.update_columns(status: :retrying)` is on **AiJobCriteria**, not the summary -- irrelevant to BROADCAST_STATUSES; do NOT touch. CONFIRMED.

## Findings

- **F1 [MED]** -- The FE `PlatoGenerationStatus` union (`PlatoLoadingState.tsx:8-13`) must also gain `awaiting_job_criteria` + `retrying`, or the code does not compile. SPEC.md W4 (line 103) says only "add `STATUS_TO_STEP` entries for `awaiting_job_criteria` and `retrying`". But `STATUS_TO_STEP` is typed `Record<PlatoGenerationStatus, number>` (`:22`); the `Record` type requires its keys to be EXACTLY the union members (`:8-13`). Adding `awaiting_job_criteria`/`retrying` keys without adding them to the union is a TS error ("Object literal may only specify known properties"). Fix: spec must require adding both values to the `PlatoGenerationStatus` union (`:8-13`) AND the `STATUS_TO_STEP` map (`:22-28`). APPLIED.

- **F2 [LOW]** -- The `generate.rb:175` conversion drops `error_message`. The live line is `ai_summary&.update_columns(status: :retrying, error_message: e&.message)`. SPEC.md W4 (line 100) says "Convert it to `.update(status: :retrying)`" -- which drops `error_message: e&.message`. The two analog retrying writers preserve it: `score_job_application.rb:129` / `integrate_analysis.rb:59` both `&.update(status: :retrying, error_message: e&.message)`. Fix: convert to `ai_summary&.update(status: :retrying, error_message: e&.message)` (preserve `error_message`, keep `&.`), matching the analogs. APPLIED.

## Verified-correct (no change)
- `.update` conversion at `generate.rb:175` does not double-fire harmfully: `before_update :broadcast_status_change` now broadcasts (intended); `after_commit :destroy_previous_textract_results` and `:update_summary_status_record` both guard on `status_succeeded?` -> no-op for `retrying`. It is a rescue-before-`raise(:176)` best-effort write; the analogs at score:129/integrate:59 already use the same `&.update(... )` shape without checking the return value (consistent -- core rule 12's return-value check is relaxed for these best-effort rescue-path status writes, matching the established pattern). Retry semantics preserved (the `raise` still propagates). CONFIRMED.
- `WebsocketJobChannelHandler.tsx:73-76` invalidates only `["aiJobApplicationSummary", id]` + `["jobApplication", id]` (detail-view) -- no `jobApplicationsForStage` list invalidation, so no list refetch storm. CONFIRMED (SPEC.md line 99).
- `PlatoTab.tsx:163,166` already route `awaiting_job_criteria`/`retrying` to `PlatoLoadingState` (the loading branch `:157-174` already lists both). So the only FE gap is `PlatoLoadingState` (union + STATUS_TO_STEP). CONFIRMED (SPEC.md line 103).
- Spec inversion target `ai_job_application_summary_spec.rb:57-62` (the `%w[awaiting_job_criteria retrying]` "does not broadcast" block) confirmed; W4 correctly requires inverting it + grepping spec/ for other stale assertions (Known Failure Pattern #6). The W4 broadcast-positive case at `:43` already updates to `awaiting_job_criteria` for the broadcast test -- the impl must reconcile both. CONFIRMED.
- Enum values stay snake_case on FE (core rule 7 exception) -- `awaiting_job_criteria`/`retrying` are Ruby enum values, kept snake_case in the union. CONFIRMED.

## Amendments Applied
- SPEC.md W4 (line 103): require adding `awaiting_job_criteria` + `retrying` to the `PlatoGenerationStatus` union (`PlatoLoadingState.tsx:8-13`) in addition to `STATUS_TO_STEP` (`:22-28`), else TS will not compile.
- SPEC.md W4 (line 100): the `generate.rb:175` conversion must preserve `error_message` -> `ai_summary&.update(status: :retrying, error_message: e&.message)` (matching analogs score:129/integrate:59), not `.update(status: :retrying)`.
