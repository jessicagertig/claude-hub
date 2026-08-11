# Code Quality -- Round 1

## Findings

- F6 [MED] `app/services/ai_job_application_action/scoring/extract_criteria.rb`:148 / `AiApiRequest.create(...)` does not check the return value. Per `cursor_rules/core_critical_rules.md` Rule 11: "Always Check save/update Return Values." The analog `Summary::Generate` also does not check the return value for `AiApiRequest.create` (its `create_ai_api_request` private method at line 296-312 also uses bare `create`). Since the analog doesn't check it either, this matches the existing pattern. However, a failed `AiApiRequest.create` silently drops cost tracking data with no indication. **This is a pre-existing analog pattern** -- flagged as MED because it matches existing code.

No other code quality issues found. Naming conventions are correct (snake_case, model-name variables per Rule 9). Guard clauses use bare `return` per Rule 8. No begin blocks. No bang methods in app code. Error handling follows the three-tier pattern. `ap` used consistently for debug logging per Rule 3. Single quotes used for string literals per Rule 7.
