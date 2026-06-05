# reinventing-the-wheel -- Round 1

## Findings

- F1 [MED] Timeout value. The spec uses `startup_timeout_seconds: 180` for the health check timeout, matching the analog's `InflowBootstrapConfig.startup_timeout_seconds = 180`. Consistent.

- F2 [MED] Health check pattern. The spec says "accept any status < 500", matching the analog's `response.status_code < 500`. Consistent. But the analog's mid-run health check in `runner.py:_check_rails_health` uses `status_code != 200` (stricter than the startup check). The spec does not distinguish between startup health check tolerance and mid-run health check tolerance. For startup, < 500 is correct (302 redirects before login). For mid-run (with a logged-in agent), a non-200 response might indicate a problem. This is a minor inconsistency with the analog but not necessarily wrong for the harness context, since the harness only does startup health checks.

- F3 [LOW] The analog uses `subprocess.PIPE` for stdout/stderr on the Rails/Sidekiq subprocesses. The spec does not specify subprocess output handling. This is an implementation detail but worth noting: if subprocess output is not captured or redirected, Rails log output could flood the agent's terminal.

- F4 [LOW] The analog uses `requests.Session()` with `Content-Type: application/json` header for all Cypress API calls. The spec does not specify request headers. This is an implementation detail that the implementer should follow from the analog.

No issues found that are not already addressed.

## Amendments Applied

- None.
