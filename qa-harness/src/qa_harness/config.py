"""Load and validate qa-config.yml, expose typed dataclass config.

Each pipeline provides a config file at ~/claude-hub/<pipeline>/qa-config.yml
declaring server commands, seed endpoints, auth instructions, and verification
layers. This module parses that YAML into typed dataclasses and validates
required fields.
"""

import os
from dataclasses import dataclass, field
from typing import Any

import yaml

from qa_harness.errors import ConfigError

_VALID_VERIFICATION_LAYERS = {"script_runner", "rspec", "cypress", "playwright_mcp"}


@dataclass
class ServerConfig:
    start_command: str
    base_url: str
    port: int
    health_check_path: str = "/"
    startup_timeout_seconds: int = 180
    supporting_commands: list[str] = field(default_factory=list)


@dataclass
class SeedEndpoint:
    method: str
    path: str
    params: dict[str, str] = field(default_factory=dict)
    requires: list[str] = field(default_factory=list)
    creates: str = ""
    returns: str = ""


@dataclass
class SeedConfig:
    cleanup_endpoint: str
    available_endpoints: list[SeedEndpoint] = field(default_factory=list)


@dataclass
class AuthConfig:
    default_user: str
    instructions: str


@dataclass
class ScriptRunnerConfig:
    command: str
    file_extension: str = ".rb"


@dataclass
class QAConfig:
    pipeline: str
    source_repo: str
    server: ServerConfig | None = None
    seed: SeedConfig | None = None
    auth: AuthConfig | None = None
    script_runner: ScriptRunnerConfig | None = None
    verification_layers: list[str] = field(default_factory=list)
    qa_team_size: int = 3


def load_config(config_path: str) -> QAConfig:
    """Load and validate qa-config.yml. Raises ConfigError on problems."""
    if not os.path.isfile(config_path):
        raise ConfigError(f"Config file not found: {config_path}")

    try:
        with open(config_path, "r") as f:
            raw = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ConfigError(f"Invalid YAML in {config_path}: {e}") from e

    if not isinstance(raw, dict):
        raise ConfigError(f"Config must be a YAML mapping, got {type(raw).__name__}")

    return _parse_config(raw)


def resolve_config_path(explicit_path: str | None = None) -> str:
    """Find the config file.

    Checks explicit path first, then cwd for qa-config.yml,
    then QA_CONFIG_PATH env var.
    """
    if explicit_path:
        return explicit_path

    cwd_path = os.path.join(os.getcwd(), "qa-config.yml")
    if os.path.isfile(cwd_path):
        return cwd_path

    env_path = os.environ.get("QA_CONFIG_PATH")
    if env_path and os.path.isfile(env_path):
        return env_path

    raise ConfigError(
        "No config file found. Provide --config, place qa-config.yml in cwd, "
        "or set QA_CONFIG_PATH."
    )


def _parse_config(raw: dict[str, Any]) -> QAConfig:
    """Parse and validate the raw YAML dict into a QAConfig."""
    # Required top-level fields
    pipeline = raw.get("pipeline")
    if not pipeline or not isinstance(pipeline, str):
        raise ConfigError("Required field 'pipeline' is missing or not a string")

    source_repo = raw.get("source_repo")
    if not source_repo or not isinstance(source_repo, str):
        raise ConfigError("Required field 'source_repo' is missing or not a string")

    # Optional: server
    server = None
    if "server" in raw and raw["server"] is not None:
        server = _parse_server_config(raw["server"])

    # Optional: seed
    seed = None
    if "seed" in raw and raw["seed"] is not None:
        seed = _parse_seed_config(raw["seed"])

    # Optional: auth
    auth = None
    if "auth" in raw and raw["auth"] is not None:
        auth = _parse_auth_config(raw["auth"])

    # Optional: script_runner
    script_runner = None
    if "script_runner" in raw and raw["script_runner"] is not None:
        script_runner = _parse_script_runner_config(raw["script_runner"])

    # Optional: verification_layers
    verification_layers = raw.get("verification_layers", [])
    if not isinstance(verification_layers, list):
        raise ConfigError("'verification_layers' must be a list")
    for layer in verification_layers:
        if layer not in _VALID_VERIFICATION_LAYERS:
            raise ConfigError(
                f"Invalid verification layer '{layer}'. "
                f"Valid values: {sorted(_VALID_VERIFICATION_LAYERS)}"
            )

    # Optional: qa_team_size
    qa_team_size = raw.get("qa_team_size", 3)
    if not isinstance(qa_team_size, int) or qa_team_size < 1:
        raise ConfigError("'qa_team_size' must be a positive integer")

    return QAConfig(
        pipeline=pipeline,
        source_repo=source_repo,
        server=server,
        seed=seed,
        auth=auth,
        script_runner=script_runner,
        verification_layers=verification_layers,
        qa_team_size=qa_team_size,
    )


def _parse_server_config(raw: dict[str, Any]) -> ServerConfig:
    """Parse the server section of the config."""
    if not isinstance(raw, dict):
        raise ConfigError("'server' must be a mapping")

    start_command = raw.get("start_command")
    if not start_command or not isinstance(start_command, str):
        raise ConfigError("server.start_command is required")

    base_url = raw.get("base_url")
    if not base_url or not isinstance(base_url, str):
        raise ConfigError("server.base_url is required")

    port = raw.get("port")
    if port is None or not isinstance(port, int):
        raise ConfigError("server.port is required and must be an integer")

    # supporting_commands: accept either the list form or the
    # spec's sidekiq_command alias for backward compatibility
    supporting_commands = raw.get("supporting_commands", [])
    if not isinstance(supporting_commands, list):
        raise ConfigError("server.supporting_commands must be a list")

    if not supporting_commands and "sidekiq_command" in raw:
        sidekiq_cmd = raw["sidekiq_command"]
        if isinstance(sidekiq_cmd, str) and sidekiq_cmd.strip():
            supporting_commands = [sidekiq_cmd]

    return ServerConfig(
        start_command=start_command,
        base_url=base_url,
        port=port,
        health_check_path=raw.get("health_check_path", "/"),
        startup_timeout_seconds=raw.get("startup_timeout_seconds", 180),
        supporting_commands=supporting_commands,
    )


def _parse_seed_config(raw: dict[str, Any]) -> SeedConfig:
    """Parse the seed section of the config."""
    if not isinstance(raw, dict):
        raise ConfigError("'seed' must be a mapping")

    cleanup_endpoint = raw.get("cleanup_endpoint")
    if not cleanup_endpoint or not isinstance(cleanup_endpoint, str):
        raise ConfigError("seed.cleanup_endpoint is required")

    raw_endpoints = raw.get("available_endpoints", [])
    if not isinstance(raw_endpoints, list):
        raise ConfigError("seed.available_endpoints must be a list")

    endpoints = []
    for i, ep in enumerate(raw_endpoints):
        if not isinstance(ep, dict):
            raise ConfigError(f"seed.available_endpoints[{i}] must be a mapping")
        method = ep.get("method")
        if not method or not isinstance(method, str):
            raise ConfigError(f"seed.available_endpoints[{i}].method is required")
        path = ep.get("path")
        if not path or not isinstance(path, str):
            raise ConfigError(f"seed.available_endpoints[{i}].path is required")
        endpoints.append(
            SeedEndpoint(
                method=method.upper(),
                path=path,
                params=ep.get("params", {}),
                requires=ep.get("requires", []),
                creates=ep.get("creates", ""),
                returns=ep.get("returns", ""),
            )
        )

    return SeedConfig(
        cleanup_endpoint=cleanup_endpoint,
        available_endpoints=endpoints,
    )


def _parse_auth_config(raw: dict[str, Any]) -> AuthConfig:
    """Parse the auth section of the config."""
    if not isinstance(raw, dict):
        raise ConfigError("'auth' must be a mapping")

    default_user = raw.get("default_user")
    if not default_user or not isinstance(default_user, str):
        raise ConfigError("auth.default_user is required")

    instructions = raw.get("instructions")
    if not instructions or not isinstance(instructions, str):
        raise ConfigError("auth.instructions is required")

    return AuthConfig(default_user=default_user, instructions=instructions)


def _parse_script_runner_config(raw: dict[str, Any]) -> ScriptRunnerConfig:
    """Parse the script_runner section of the config."""
    if not isinstance(raw, dict):
        raise ConfigError("'script_runner' must be a mapping")

    command = raw.get("command")
    if not command or not isinstance(command, str):
        raise ConfigError("script_runner.command is required")

    return ScriptRunnerConfig(
        command=command,
        file_extension=raw.get("file_extension", ".rb"),
    )
