# Seed Data Design — Pass 1

## Fact Check

- **Claim:** Plan describes `SeedExecutor` with `requests.Session`, `Content-Type: application/json` header, timeout of 120.
  - Verified: Analog `CypressApi.__init__` (cypress_api.py lines 27-33) uses `requests.Session()`, `Content-Type: application/json`, `timeout=120`. Plan matches exactly.

- **Claim:** "Generic instead of per-endpoint methods. The QA harness does not have `create_default_user()` etc."
  - Verified: The analog `CypressApi` has per-endpoint methods like `create_default_user()`, `add_users()`, `create_default_job()`, etc. (lines 50-135). The plan replaces these with a generic `_execute_step({method, path, body})` approach. This is an intentional, justified design choice for a pipeline-agnostic harness.

- **Claim:** "Validation is against the config's `available_endpoints` catalog."
  - The plan's `validate_plan` method checks method+path exists in catalog, required params present, and ordering respects `requires` dependencies. This matches the spec review MED finding #6.

- **Claim:** "`cleanup` parses the `cleanup_endpoint` config string (e.g., 'DELETE /cypress/cleanup') into method+path."
  - The plan describes this in the `cleanup()` method. The spec defines `cleanup_endpoint: DELETE /cypress/cleanup`. Parsing "DELETE /cypress/cleanup" into method="DELETE" and path="/cypress/cleanup" is straightforward.

- **Claim:** "Seed plans are JSON files, not parsed strings."
  - Verified: The analog uses `seed_parser.py` with regex-based string parsing. The plan uses JSON directly. This is an improvement (no SeedParseError from string parsing needed).

- **Claim:** Plan says `execute_plan` "calls cleanup first, then runs the endpoints in order."
  - Verified: Spec says "Calls cleanup first, then runs the endpoints in order." Consistent.

- **Claim:** "check_server_alive is called before any HTTP operation (spec amendment from Round 1)."
  - Verified: Spec says "Before making any HTTP calls, `seed` and `cleanup` commands verify the server is alive." Plan's `execute_plan` and `cleanup` both check server alive first. Consistent.

## Completeness

Spec requirements covered by this angle:
1. Seed plan JSON format (spec: array of `{method, path, body}`) -- plan: `execute_plan` loads JSON
2. Cleanup before seeding (spec: "Calls cleanup first") -- plan: `execute_plan` calls `cleanup()` first
3. Cleanup endpoint (spec: `DELETE /cypress/cleanup`) -- plan: `cleanup()` parses `cleanup_endpoint` config
4. Seed-endpoints listing (spec: CLI `seed-endpoints` command) -- plan: `list_endpoints()` method
5. Server alive check before HTTP (spec: "verify the server is alive") -- plan: `check_server_alive`
6. Error handling for HTTP failures -- plan: `SeedError` with status+endpoint

All spec requirements for seed data addressed.

## Findings

- F1 [MED] The plan's `SeedExecutor` constructor takes `base_url` but the `check_server_alive` method takes a `health_url` parameter. The health check URL is `base_url + health_check_path`, but `SeedExecutor` doesn't have access to `health_check_path` (that's on `ServerConfig`). The `cli.py` layer will need to construct the full health URL and pass it to `check_server_alive`. This works but requires the CLI to bridge two config sections. Not a blocker but implementation needs to be aware.

## Amendments Applied

None needed -- no HIGH or BLOCKER findings.
