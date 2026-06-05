"""Tests for seed plan execution, validation, and endpoint listing.

Uses the responses library for HTTP mocking, adapted from test_cypress_api.py.
"""

import json

import pytest
import responses

from qa_harness.config import SeedConfig, SeedEndpoint
from qa_harness.errors import SeedError
from qa_harness.seed import SeedExecutor

BASE_URL = "http://app.lvh.me:5007"
HEALTH_URL = "http://app.lvh.me:5007/"


@pytest.fixture
def seed_config():
    return SeedConfig(
        cleanup_endpoint="DELETE /cypress/cleanup",
        available_endpoints=[
            SeedEndpoint(
                method="POST",
                path="/cypress/users",
                params={"setActivePaidSubscription": "bool"},
                creates="Default user",
            ),
            SeedEndpoint(
                method="POST",
                path="/cypress/jobs",
                params={"published": "bool", "title": "string"},
                requires=["/cypress/users"],
                creates="A job",
            ),
            SeedEndpoint(
                method="POST",
                path="/cypress/candidates",
                params={"amount": "int"},
                requires=["/cypress/jobs"],
                creates="N candidates",
            ),
            SeedEndpoint(
                method="GET",
                path="/cypress/invites/{email_base64}",
                returns="{accept_url: string}",
            ),
        ],
    )


@pytest.fixture
def executor(seed_config):
    return SeedExecutor(seed_config, BASE_URL)


class TestCheckServerAlive:
    @responses.activate
    def test_alive_server_passes(self, executor):
        responses.add(responses.GET, HEALTH_URL, status=200)
        executor.check_server_alive(HEALTH_URL)

    @responses.activate
    def test_server_500_raises(self, executor):
        responses.add(responses.GET, HEALTH_URL, status=500)
        with pytest.raises(SeedError, match="returned 500"):
            executor.check_server_alive(HEALTH_URL)

    @responses.activate
    def test_connection_error_raises(self, executor):
        responses.add(
            responses.GET, HEALTH_URL,
            body=ConnectionError("refused"),
        )
        with pytest.raises(SeedError, match="not responding"):
            executor.check_server_alive(HEALTH_URL)


class TestCleanup:
    @responses.activate
    def test_cleanup_calls_correct_endpoint(self, executor):
        responses.add(responses.DELETE, f"{BASE_URL}/cypress/cleanup", status=200)
        executor.cleanup()
        assert len(responses.calls) == 1
        assert responses.calls[0].request.method == "DELETE"

    @responses.activate
    def test_cleanup_raises_on_http_error(self, executor):
        responses.add(
            responses.DELETE, f"{BASE_URL}/cypress/cleanup",
            status=500, body="Internal Error",
        )
        with pytest.raises(SeedError, match="500"):
            executor.cleanup()


class TestExecutePlan:
    @responses.activate
    def test_loads_and_executes_plan(self, executor, tmp_path):
        plan = [
            {"method": "POST", "path": "/cypress/users", "body": {"setActivePaidSubscription": True}},
            {"method": "POST", "path": "/cypress/jobs", "body": {"published": True}},
        ]
        plan_path = tmp_path / "plan.json"
        plan_path.write_text(json.dumps(plan))

        # Health check
        responses.add(responses.GET, HEALTH_URL, status=200)
        # Cleanup (implicit)
        responses.add(responses.DELETE, f"{BASE_URL}/cypress/cleanup", status=200)
        # Plan steps
        responses.add(responses.POST, f"{BASE_URL}/cypress/users", json={"id": 1}, status=200)
        responses.add(responses.POST, f"{BASE_URL}/cypress/jobs", json={"id": 42}, status=200)

        results = executor.execute_plan(str(plan_path), HEALTH_URL)
        assert len(results) == 2
        assert results[0]["endpoint"] == "POST /cypress/users"
        assert results[1]["endpoint"] == "POST /cypress/jobs"

    @responses.activate
    def test_calls_cleanup_before_seeding(self, executor, tmp_path):
        plan = [
            {"method": "POST", "path": "/cypress/users"},
        ]
        plan_path = tmp_path / "plan.json"
        plan_path.write_text(json.dumps(plan))

        responses.add(responses.GET, HEALTH_URL, status=200)
        responses.add(responses.DELETE, f"{BASE_URL}/cypress/cleanup", status=200)
        responses.add(responses.POST, f"{BASE_URL}/cypress/users", json={"id": 1}, status=200)

        executor.execute_plan(str(plan_path), HEALTH_URL)

        # Cleanup should be called first (after health check)
        assert responses.calls[1].request.method == "DELETE"
        assert "/cypress/cleanup" in responses.calls[1].request.url

    @responses.activate
    def test_checks_server_alive_first(self, executor, tmp_path):
        plan = [{"method": "POST", "path": "/cypress/users"}]
        plan_path = tmp_path / "plan.json"
        plan_path.write_text(json.dumps(plan))

        responses.add(
            responses.GET, HEALTH_URL,
            body=ConnectionError("refused"),
        )

        with pytest.raises(SeedError, match="not responding"):
            executor.execute_plan(str(plan_path), HEALTH_URL)

    @responses.activate
    def test_raises_on_http_error(self, executor, tmp_path):
        plan = [{"method": "POST", "path": "/cypress/users"}]
        plan_path = tmp_path / "plan.json"
        plan_path.write_text(json.dumps(plan))

        responses.add(responses.GET, HEALTH_URL, status=200)
        responses.add(responses.DELETE, f"{BASE_URL}/cypress/cleanup", status=200)
        responses.add(responses.POST, f"{BASE_URL}/cypress/users", status=500, body="Error")

        with pytest.raises(SeedError, match="500"):
            executor.execute_plan(str(plan_path), HEALTH_URL)

    @responses.activate
    def test_raises_on_invalid_json(self, executor, tmp_path):
        plan_path = tmp_path / "plan.json"
        plan_path.write_text("not json")

        responses.add(responses.GET, HEALTH_URL, status=200)

        with pytest.raises(SeedError, match="Could not load"):
            executor.execute_plan(str(plan_path), HEALTH_URL)

    @responses.activate
    def test_empty_plan_just_runs_cleanup(self, executor, tmp_path):
        plan_path = tmp_path / "plan.json"
        plan_path.write_text("[]")

        responses.add(responses.GET, HEALTH_URL, status=200)
        responses.add(responses.DELETE, f"{BASE_URL}/cypress/cleanup", status=200)

        results = executor.execute_plan(str(plan_path), HEALTH_URL)
        assert len(results) == 0


class TestValidatePlan:
    def test_valid_plan(self, executor):
        plan = [
            {"method": "POST", "path": "/cypress/users"},
            {"method": "POST", "path": "/cypress/jobs"},
            {"method": "POST", "path": "/cypress/candidates"},
        ]
        errors = executor.validate_plan(plan)
        assert errors == []

    def test_unknown_endpoint_rejected(self, executor):
        plan = [
            {"method": "POST", "path": "/cypress/unknown"},
        ]
        errors = executor.validate_plan(plan)
        assert len(errors) == 1
        assert "not in available_endpoints" in errors[0]

    def test_dependency_ordering_violation(self, executor):
        plan = [
            {"method": "POST", "path": "/cypress/jobs"},  # requires /cypress/users
        ]
        errors = executor.validate_plan(plan)
        assert len(errors) == 1
        assert "requires /cypress/users" in errors[0]

    def test_dependency_ordering_satisfied(self, executor):
        plan = [
            {"method": "POST", "path": "/cypress/users"},
            {"method": "POST", "path": "/cypress/jobs"},
        ]
        errors = executor.validate_plan(plan)
        assert errors == []

    def test_missing_method_or_path(self, executor):
        plan = [
            {"method": "POST"},
        ]
        errors = executor.validate_plan(plan)
        assert len(errors) == 1
        assert "missing" in errors[0]

    def test_placeholder_path_matches(self, executor):
        plan = [
            {"method": "GET", "path": "/cypress/invites/abc123base64"},
        ]
        errors = executor.validate_plan(plan)
        assert errors == []

    def test_empty_plan_valid(self, executor):
        errors = executor.validate_plan([])
        assert errors == []


class TestListEndpoints:
    def test_lists_all_endpoints(self, executor):
        output = executor.list_endpoints()
        assert "POST /cypress/users" in output
        assert "POST /cypress/jobs" in output
        assert "POST /cypress/candidates" in output
        assert "GET /cypress/invites/{email_base64}" in output

    def test_includes_params(self, executor):
        output = executor.list_endpoints()
        assert "setActivePaidSubscription" in output
        assert "bool" in output

    def test_includes_requires(self, executor):
        output = executor.list_endpoints()
        assert "Requires:" in output
        assert "/cypress/users" in output

    def test_includes_creates(self, executor):
        output = executor.list_endpoints()
        assert "Creates:" in output
        assert "Default user" in output

    def test_includes_cleanup(self, executor):
        output = executor.list_endpoints()
        assert "DELETE /cypress/cleanup" in output


class TestNetworkError:
    @responses.activate
    def test_network_error_raises_seed_error(self, executor):
        responses.add(
            responses.POST, f"{BASE_URL}/cypress/users",
            body=ConnectionError("refused"),
        )
        with pytest.raises(SeedError, match="Network error"):
            executor._request("POST", "/cypress/users")
