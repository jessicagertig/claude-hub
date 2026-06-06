# Pipeline Scalability — Pass 1

## Fact Check

- **Claim:** "Every pipeline-specific detail is in `qa-config.yml`, not in harness code."
  - Verified: Plan section 5 shows all config values come from the YAML file. `ServerConfig` gets `start_command`, `base_url`, `port` from config. `SeedConfig` gets `cleanup_endpoint` and `available_endpoints` from config. `AuthConfig` gets `default_user` and `instructions` from config. `ScriptRunnerConfig` gets `command` and `file_extension` from config. No hardcoded pipeline-specific values in any module.

- **Claim:** "supporting_commands replaces hardcoded sidekiq_command."
  - Verified: Plan section 5 `config.py` defines `supporting_commands: list[str]` on `ServerConfig`. Plan section 7 confirms the schema uses `supporting_commands` as a list. Plan section 7 also says "the spec's `sidekiq_command` should be accepted as an alias during config loading." This handles backward compatibility.

- **Claim:** "server, seed, auth are all optional for non-web pipeline support."
  - Verified: Plan section 5 `config.py`: `server: ServerConfig | None = None`, `seed: SeedConfig | None = None`, `auth: AuthConfig | None = None`. Spec says "For a non-web pipeline, the config would omit `server`, `auth`, and the `playwright_mcp` layer." Consistent.

- **Claim:** "A new pipeline adds a config file. No harness code changes."
  - Verified: The plan's architecture is fully config-driven. The harness reads YAML, executes generic HTTP calls, starts generic subprocess commands. No pipeline-specific code paths.

- **Claim:** "The `sidekiq_command` from the spec maps to `supporting_commands: [<the sidekiq command>]`."
  - Verified: This is a design decision in the plan that generalizes the spec. The spec shows `sidekiq_command` as a named field. Plan generalizes to a list. The backward compatibility alias is documented.

## Completeness

Spec requirements covered by this angle:
1. qa-config.yml format -- plan: section 7 full schema
2. Config-driven server lifecycle -- plan: `ServerConfig` dataclass
3. Config-driven seeding -- plan: `SeedConfig` + `SeedEndpoint` dataclasses
4. Config-driven auth -- plan: `AuthConfig` dataclass
5. Config-driven script runner -- plan: `ScriptRunnerConfig` dataclass
6. Non-web pipeline support (omit server/auth/playwright) -- plan: all Optional
7. verification_layers validation -- plan: "entries must be from the known set"
8. qa_team_size configuration -- plan: `QAConfig.qa_team_size: int = 3`

All spec requirements for pipeline scalability addressed.

## Findings

- F1 [MED] The spec shows `sidekiq_command` as a direct field in the server config, but the plan uses `supporting_commands` (a list). While the plan documents backward compatibility ("accept as alias"), the inflow-ats qa-config.yml file that will be created should use `supporting_commands` (the plan's schema) not `sidekiq_command` (the spec's example). This is a minor consistency point -- not a blocker since the alias handles it.

## Amendments Applied

None needed -- no HIGH or BLOCKER findings.
