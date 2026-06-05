# source-accuracy -- Round 1

## Findings

- F1 [HIGH] `test_frr` definition is wrong. Spec said `RAILS_ENV=test bundle exec rails runner`. Actual alias (from `~/.bash_profile`) is `RAILS_ENV=test foreman run rails runner`. Uses `foreman run`, not `bundle exec`. This matters because `foreman run` loads `.env` and Procfile context, which `bundle exec` does not.

  **Status:** Already fixed in pipeline-scalability amendments this round.

- F2 [HIGH] Missing seed endpoints. Spec omitted `POST /cypress/organizations/create_complete_subscription` and `GET /cypress/individual_app/careers_page_subscriptions/{id}` from the endpoint catalog. Also omitted the `setFreeV2Subscription` param on `POST /cypress/users`.

  **Status:** Already fixed in seed-data-design amendments this round.

- F3 [MED] The spec references `mcp__playwright__browser_fill_form` and `mcp__playwright__browser_click` and `mcp__playwright__browser_navigate` and `mcp__playwright__browser_snapshot`. Cross-referencing against the available MCP tools in the system-reminder: all four are present (`browser_fill_form`, `browser_click`, `browser_navigate`, `browser_snapshot`). Verified correct.

- F4 [MED] The spec references `~/claude-hub/qa-harness/` as the harness code location. This is a new directory that does not yet exist, which is expected since this is a spec for new code. However, the hub CLAUDE.md does not list `qa-harness/` in its directory conventions. It may need to be added after implementation.

- F5 [LOW] The spec references `reviews/seed-plans/` as the location for seed plan files. This is within the feature working directory (`~/claude-hub/<pipeline>/YYYY-MM-DD-feature-name/reviews/seed-plans/`), which is consistent with hub conventions.

- F6 [LOW] The analog table references `fallback_executor.py` as "NOT used" which is accurate -- Playwright MCP replaces it. Verified by reading the actual file.

## Amendments Applied

- None new (F1 and F2 fixes applied in other angles this round).
