# Seed Data Design — Pass 2

## Pass 1 Corrections Verification

No amendments were applied in Pass 1 for this angle. N/A.

## Fresh Scrutiny

- **`_request` return type:** The plan says `_request` returns `dict` but the analog's `CypressApi._request` (cypress_api.py lines 141-157) returns `Any` -- it can return `None` (status 204), `dict` (JSON), or `str` (non-JSON). The plan's `_execute_step` return type says `{endpoint, status_code, response_body}` which wraps the raw response. This is fine -- `_execute_step` constructs the wrapper dict, and `_request` should return the parsed response (which may be None, dict, or str). The plan should type `_request` as returning `Any` or `dict | str | None` to match the analog, but this is an implementation detail not a plan-level issue.

- **validate_plan dependency check:** The plan says `validate_plan` "checks dependency ordering (requires)" by verifying "required paths appear earlier in the array." This is a linear scan -- O(n) per step. For the inflow-ats endpoint catalog (12 endpoints), this is trivial. No performance concern.

- **Timeout for seed HTTP calls:** The plan sets `self.timeout = 120` matching the analog's `CypressApi.__init__` timeout of 120. Good.

- **Error class:** The plan's `SeedError(QAHarnessError)` replaces the analog's `CypressApiError(Exception)`. The analog stores `status`, `endpoint`, `body` on the error (cypress_api.py lines 18-23). The plan doesn't detail `SeedError`'s attributes, but section 5 says "Custom exception classes: ... `SeedError(QAHarnessError)` -- seed execution failures (HTTP errors, validation errors)." The analog pattern should be preserved (status code + endpoint + body). Implementation detail.

- **check_server_alive health URL gap:** Pass 1 MED noted that `SeedExecutor.check_server_alive` takes a `health_url` but `SeedExecutor` only has `base_url`. The CLI layer constructs the full URL. This works but means the CLI must know the health_check_path from the server config to construct the URL. For pipelines without a server config (non-web), seed operations would need a different check. This is acceptable for v1 since non-web pipelines omit seed config too.

## Completeness Sweep

All spec requirements for seed data remain addressed. No gaps found.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
