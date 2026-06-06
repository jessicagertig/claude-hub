# Pipeline Scalability — Pass 2

## Pass 1 Corrections Verification

No amendments were applied in Pass 1 for this angle. N/A.

## Fresh Scrutiny

- **qa-config.yml placement:** The plan puts pipeline configs at `~/claude-hub/<pipeline>/qa-config.yml`. The hub CLAUDE.md says "Always create a subdirectory for new work (`<pipeline>/<workflow>/<dated-slug>/`)" but qa-config.yml is a pipeline-level config file, not a work item. It goes at the pipeline root level, similar to how CLAUDE.md files go at pipeline roots. The spec also places it there. Acceptable.

- **YAML footgun concern from review angles:** The review angles raised "Is `qa-config.yml` the right format? YAML has footguns (implicit type coercion, indentation sensitivity)." The plan uses YAML because the help pipeline's existing config patterns use YAML-like formats and the config is relatively simple. The plan's `load_config` validates the parsed YAML strictly. YAML type coercion is a risk (e.g., `true` vs `"true"`) but the dataclass validation catches type mismatches. Acceptable for v1.

- **Auth flow expressiveness from review angles:** The review angles asked "Is this mini-DSL expressive enough for auth flows that aren't magic-link?" The plan's auth config is NOT a DSL -- it's free-text `instructions` that the agent reads and interprets. Since the agent has judgment, it can follow arbitrarily complex auth instructions (OAuth redirect flows, multi-step verification, etc.). This is more flexible than a declarative DSL. Good design choice.

- **Non-web pipeline seed question:** The review angles noted "Non-Rails pipelines won't have `/cypress/*` endpoints." The plan handles this by making `seed` optional in the config. Non-web pipelines omit the `seed` block entirely. If a non-web pipeline needs seed data, it would define its own endpoints or use a different mechanism declared in the config. The schema supports this.

## Completeness Sweep

All spec requirements for pipeline scalability remain addressed. No gaps found.

## Findings

No BLOCKER, HIGH, or MED findings.

## Amendments Applied

None needed.
