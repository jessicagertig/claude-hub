# Failure Report — Round 1

## HIGH issues to fix

### 1. `_execute_step` hardcodes status_code 200

**File:** `src/qa_harness/seed.py`
**Lines:** 192-206 (`_execute_step`) and 209-235 (`_request`)

**Problem:** `_request` returns only the parsed response body (JSON, text, or None). `_execute_step` always reports `"status_code": 200` in the result dict because it has no access to the actual HTTP response status code. This means `cmd_seed` prints "200" for every step regardless of the actual response (which could be 201, 204, etc.), producing misleading output for QA agents.

**Fix:** Change `_request` to return a dict with both `status_code` and `body`, or return a tuple. Then have `_execute_step` use the actual status code. Update the test `test_loads_and_executes_plan` to verify the actual status code is propagated.

**Evidence:** Read `seed.py` lines 192-235. The `_request` method on line 215 does `return response.json()` or `return response.text` or `return None` -- never includes `response.status_code`. The `_execute_step` method on line 201 hardcodes `"status_code": 200`.
