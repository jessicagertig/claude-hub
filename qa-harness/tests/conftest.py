"""Shared fixtures for QA harness tests."""

import pytest
import yaml


MINIMAL_CONFIG = {
    "pipeline": "test-pipeline",
    "source_repo": "/tmp/test-repo",
}

FULL_CONFIG = {
    "pipeline": "inflow-ats",
    "source_repo": "/Users/jessica/wrk/wrk-corp/inflow-ats",
    "server": {
        "start_command": "RAILS_ENV=test bundle exec rails s -p 5007",
        "base_url": "http://app.lvh.me:5007",
        "port": 5007,
        "health_check_path": "/",
        "startup_timeout_seconds": 180,
        "supporting_commands": [
            "RAILS_ENV=test bundle exec sidekiq",
        ],
    },
    "seed": {
        "cleanup_endpoint": "DELETE /cypress/cleanup",
        "available_endpoints": [
            {
                "method": "POST",
                "path": "/cypress/users",
                "params": {"setActivePaidSubscription": "bool"},
                "creates": "Default user (Rezu May) + org (Acme Inc)",
            },
            {
                "method": "POST",
                "path": "/cypress/jobs",
                "params": {"published": "bool", "title": "string"},
                "requires": ["/cypress/users"],
                "creates": "A job in the default org",
            },
            {
                "method": "POST",
                "path": "/cypress/candidates",
                "params": {"amount": "int"},
                "requires": ["/cypress/jobs"],
                "creates": "N candidates on the default job",
            },
            {
                "method": "GET",
                "path": "/cypress/invites/{email_base64}",
                "returns": "{accept_url: string}",
            },
        ],
    },
    "auth": {
        "default_user": "rezu.may@wrkhq.com",
        "instructions": "Navigate to /auth and use magic link",
    },
    "script_runner": {
        "command": "test_frr",
        "file_extension": ".rb",
    },
    "verification_layers": [
        "script_runner",
        "rspec",
        "cypress",
        "playwright_mcp",
    ],
    "qa_team_size": 3,
}

SIDEKIQ_ALIAS_CONFIG = {
    "pipeline": "test-pipeline",
    "source_repo": "/tmp/test-repo",
    "server": {
        "start_command": "RAILS_ENV=test bundle exec rails s -p 5007",
        "base_url": "http://app.lvh.me:5007",
        "port": 5007,
        "sidekiq_command": "RAILS_ENV=test bundle exec sidekiq",
    },
}


@pytest.fixture
def minimal_config_file(tmp_path):
    """Write a minimal config YAML and return its path."""
    config_path = tmp_path / "qa-config.yml"
    config_path.write_text(yaml.dump(MINIMAL_CONFIG))
    return str(config_path)


@pytest.fixture
def full_config_file(tmp_path):
    """Write a full config YAML and return its path."""
    config_path = tmp_path / "qa-config.yml"
    config_path.write_text(yaml.dump(FULL_CONFIG))
    return str(config_path)


@pytest.fixture
def sidekiq_alias_config_file(tmp_path):
    """Write a config with sidekiq_command alias and return its path."""
    config_path = tmp_path / "qa-config.yml"
    config_path.write_text(yaml.dump(SIDEKIQ_ALIAS_CONFIG))
    return str(config_path)


@pytest.fixture
def sample_seed_plan(tmp_path):
    """Write a sample seed plan JSON and return its path."""
    import json

    plan = [
        {"method": "POST", "path": "/cypress/users", "body": {"setActivePaidSubscription": True}},
        {"method": "POST", "path": "/cypress/jobs", "body": {"published": True, "title": "Test Job"}},
        {"method": "POST", "path": "/cypress/candidates", "body": {"amount": 5}},
    ]
    plan_path = tmp_path / "seed-plan.json"
    plan_path.write_text(json.dumps(plan))
    return str(plan_path)
