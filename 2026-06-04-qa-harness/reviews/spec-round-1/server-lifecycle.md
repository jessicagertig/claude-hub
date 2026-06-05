# server-lifecycle -- Round 1

## Findings

- F1 [HIGH] Mid-run server death not handled. The spec defines startup health checking (poll until ready) and start/stop lifecycle, but never addresses what happens if Rails or Sidekiq die during a QA round. The analog (`runner.py:_check_rails_health`) explicitly checks `rails_proc.poll()` and `requests.get` before each article iteration and aborts if Rails is dead. A QA agent that runs for 30+ minutes could hit a server crash and get no diagnostic -- just Playwright timeouts. The harness needs a `qa-harness status` command that checks process liveness (already in CLI section) but the spec does not specify that QA agents should call it, nor that `qa-harness seed` or `qa-harness cleanup` should fail fast if the server is down.

  **Fix:** Add language to the spec that `qa-harness seed` and `qa-harness cleanup` verify the server is responding before attempting HTTP calls, and fail with a clear error if it is not.

- F2 [MED] Sidekiq independent death. The spec kills both Rails and Sidekiq together at stop time, but does not address Sidekiq dying independently mid-run. If a feature relies on background jobs (e.g., email sending, PDF generation), Sidekiq dying silently would cause QA failures misattributed to the feature. The analog does not address this either, but the QA harness context is more sensitive because agents are expected to diagnose root causes.

- F3 [MED] `os.system` vs `subprocess` for process kills. The analog uses `os.system` with temp-file redirection specifically so that tests which mock `subprocess.Popen` are not affected by the cleanup step. The spec does not mention this pattern. Whether to follow it is an implementation detail, but the rationale should be noted for the implementer.

- F4 [LOW] The analog's startup health check also checks `rails_proc.poll()` during the polling loop (detecting premature exit). The spec's health check section only mentions polling the HTTP endpoint. The analog's premature-exit detection is important because it avoids waiting 180s when Rails crashes immediately on boot.

  **Note:** This is partially implied by "Polls health check until ready or timeout" but the premature-exit short-circuit should be explicit.

## Amendments Applied

- Spec "Seed execution" section: added that seed/cleanup commands verify server is alive before making HTTP calls.
- Spec "Health check" section: added premature process exit detection.
