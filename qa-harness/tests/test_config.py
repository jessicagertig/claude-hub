"""Tests for config loading and validation."""

import os

import pytest
import yaml

from qa_harness.config import (
    QAConfig,
    ServerConfig,
    SeedConfig,
    SeedEndpoint,
    AuthConfig,
    ScriptRunnerConfig,
    load_config,
    resolve_config_path,
)
from qa_harness.errors import ConfigError


class TestLoadConfig:
    """Tests for load_config."""

    def test_load_full_config(self, full_config_file):
        config = load_config(full_config_file)
        assert config.pipeline == "inflow-ats"
        assert config.source_repo == "/Users/jessica/wrk/wrk-corp/inflow-ats"
        assert config.server is not None
        assert config.server.port == 5007
        assert config.server.base_url == "http://app.lvh.me:5007"
        assert config.server.health_check_path == "/"
        assert config.server.startup_timeout_seconds == 180
        assert len(config.server.supporting_commands) == 1
        assert "sidekiq" in config.server.supporting_commands[0]
        assert config.seed is not None
        assert config.seed.cleanup_endpoint == "DELETE /cypress/cleanup"
        assert len(config.seed.available_endpoints) == 4
        assert config.auth is not None
        assert config.auth.default_user == "rezu.may@wrkhq.com"
        assert config.script_runner is not None
        assert config.script_runner.command == "test_frr"
        assert config.verification_layers == [
            "script_runner", "rspec", "cypress", "playwright_mcp"
        ]
        assert config.qa_team_size == 3

    def test_load_minimal_config(self, minimal_config_file):
        config = load_config(minimal_config_file)
        assert config.pipeline == "test-pipeline"
        assert config.source_repo == "/tmp/test-repo"
        assert config.server is None
        assert config.seed is None
        assert config.auth is None
        assert config.script_runner is None
        assert config.verification_layers == []
        assert config.qa_team_size == 3

    def test_load_server_without_seed(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "server": {
                "start_command": "rails s",
                "base_url": "http://localhost:3000",
                "port": 3000,
            },
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        config = load_config(str(config_path))
        assert config.server is not None
        assert config.seed is None

    def test_load_seed_without_server(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "seed": {
                "cleanup_endpoint": "DELETE /cleanup",
                "available_endpoints": [],
            },
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        config = load_config(str(config_path))
        assert config.server is None
        assert config.seed is not None

    def test_missing_pipeline_raises(self, tmp_path):
        data = {"source_repo": "/tmp/repo"}
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        with pytest.raises(ConfigError, match="pipeline"):
            load_config(str(config_path))

    def test_missing_source_repo_raises(self, tmp_path):
        data = {"pipeline": "test"}
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        with pytest.raises(ConfigError, match="source_repo"):
            load_config(str(config_path))

    def test_server_missing_start_command_raises(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "server": {
                "base_url": "http://localhost:3000",
                "port": 3000,
            },
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        with pytest.raises(ConfigError, match="start_command"):
            load_config(str(config_path))

    def test_invalid_verification_layer_raises(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "verification_layers": ["invalid_layer"],
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        with pytest.raises(ConfigError, match="invalid_layer"):
            load_config(str(config_path))

    def test_qa_team_size_non_positive_raises(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "qa_team_size": 0,
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        with pytest.raises(ConfigError, match="qa_team_size"):
            load_config(str(config_path))

    def test_sidekiq_command_alias(self, sidekiq_alias_config_file):
        config = load_config(sidekiq_alias_config_file)
        assert config.server is not None
        assert len(config.server.supporting_commands) == 1
        assert "sidekiq" in config.server.supporting_commands[0]

    def test_config_file_not_found_raises(self):
        with pytest.raises(ConfigError, match="not found"):
            load_config("/nonexistent/qa-config.yml")

    def test_invalid_yaml_raises(self, tmp_path):
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(": invalid: yaml: [unclosed")
        with pytest.raises(ConfigError, match="Invalid YAML"):
            load_config(str(config_path))

    def test_seed_endpoint_method_and_path_parsed(self, full_config_file):
        config = load_config(full_config_file)
        ep = config.seed.available_endpoints[0]
        assert ep.method == "POST"
        assert ep.path == "/cypress/users"
        assert "setActivePaidSubscription" in ep.params

    def test_seed_endpoint_requires_parsed(self, full_config_file):
        config = load_config(full_config_file)
        jobs_ep = config.seed.available_endpoints[1]
        assert jobs_ep.requires == ["/cypress/users"]

    def test_server_defaults(self, tmp_path):
        data = {
            "pipeline": "test",
            "source_repo": "/tmp/repo",
            "server": {
                "start_command": "rails s",
                "base_url": "http://localhost:3000",
                "port": 3000,
            },
        }
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text(yaml.dump(data))
        config = load_config(str(config_path))
        assert config.server.health_check_path == "/"
        assert config.server.startup_timeout_seconds == 180
        assert config.server.supporting_commands == []


class TestResolveConfigPath:
    """Tests for resolve_config_path."""

    def test_explicit_path(self, tmp_path):
        config_path = tmp_path / "custom-config.yml"
        config_path.write_text("pipeline: test")
        result = resolve_config_path(str(config_path))
        assert result == str(config_path)

    def test_finds_in_cwd(self, tmp_path, monkeypatch):
        config_path = tmp_path / "qa-config.yml"
        config_path.write_text("pipeline: test")
        monkeypatch.chdir(tmp_path)
        result = resolve_config_path()
        assert result == str(config_path)

    def test_uses_env_var(self, tmp_path, monkeypatch):
        config_path = tmp_path / "env-config.yml"
        config_path.write_text("pipeline: test")
        monkeypatch.setenv("QA_CONFIG_PATH", str(config_path))
        monkeypatch.chdir("/tmp")
        result = resolve_config_path()
        assert result == str(config_path)

    def test_raises_when_not_found(self, tmp_path, monkeypatch):
        monkeypatch.chdir(tmp_path)
        monkeypatch.delenv("QA_CONFIG_PATH", raising=False)
        with pytest.raises(ConfigError, match="No config file found"):
            resolve_config_path()
