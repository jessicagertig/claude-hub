# Layer 1 Diff-to-Spec: Parallel Coexistence + Gemfile

## Focus Area
Gemfile changes and parallel coexistence with the existing AI summary pipeline.

## Checks Performed

### 1. Gemfile

| Check | Result |
|-------|--------|
| `fx` ~> 0.8.0 added | PASS — line 126, placed immediately after `pg_search` |
| `fx` resolved version | PASS — Gemfile.lock shows `fx (0.8.0)` with `activerecord >= 6.0.0`, `railties >= 6.0.0` |
| `pg_search` 2.3.2 unchanged | PASS — line 125, no diff on this line (context-only in patch) |
| No other gem changes | PASS — diff touches only `fx` addition in Gemfile and Gemfile.lock |

### 2. Parallel Coexistence

| Check | Result |
|-------|--------|
| `generate.rb` NOT modified | PASS — `git diff develop...HEAD --name-only` shows no files under `app/services/ai_job_application_action/` |
| Existing Call 1 extraction intact | PASS — `generate.rb:46-58` still calls `ResumeStructuredData.messages`, `ai_client.chat`, `create_ai_api_request(call_type: 'extraction')`, `JSON.parse` — unchanged |
| Storage isolation | PASS — Summary pipeline stores on `AiJobApplicationSummary.structured_data` (jsonb column confirmed in schema). New service stores on `TextractResult.structured_extraction`. Different model, different column |
| Both read `textract_job_result_text` | PASS — Both are read-only consumers of this column. No write conflicts |
| Existing callback preserved | PASS — `textract_result.rb:10` still has `after_commit :queue_ai_summary_job, on: [:create, :update]`. New callback added on line 11 alongside it |

### 3. Backward Compatibility

| Check | Result |
|-------|--------|
| No serializers reference TextractResult | PASS — `grep -r` in `app/serializers/` returned no results |
| No controllers reference TextractResult | PASS — `grep -r` in `app/controllers/` returned no results |
| `PgSearch::Model` scope name collision | PASS — `search_resume_text` and `search_resume_by_keyword` are not used in any other PgSearch model (`Candidate`, `Organization`, `Job`, `User`) |
| Existing PgSearch models unaffected | PASS — 4 existing PgSearch models confirmed; TextractResult is the 5th. No interference |

## Verdict

VERDICT: CLEAN — 0 findings
