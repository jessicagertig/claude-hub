"""Seed plan execution, cleanup, and endpoint listing.

Executes seed plans (JSON arrays of {method, path, body?} objects) against
configured endpoints. Generic instead of per-endpoint methods -- reads the
plan and dispatches HTTP calls through a single _request method.

Adapted from cypress_api.py's HTTP wrapper pattern.
"""

import json
import logging
from typing import Any, Optional

import requests

from qa_harness.config import SeedConfig
from qa_harness.errors import SeedError

logger = logging.getLogger(__name__)


class SeedExecutor:
    """Executes seed plans, runs cleanup, and lists available endpoints."""

    def __init__(self, seed_config: SeedConfig, base_url: str):
        self.seed_config = seed_config
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update({"Content-Type": "application/json"})
        self.timeout = 120

    def check_server_alive(self, health_url: str) -> None:
        """Hit health check endpoint. Raise SeedError with actionable message
        if server is not responding."""
        try:
            response = requests.get(health_url, timeout=5)
            if response.status_code >= 500:
                raise SeedError(
                    f"Server returned {response.status_code} at {health_url}. "
                    "Check `qa-harness status` for details."
                )
        except (requests.RequestException, ConnectionError) as e:
            raise SeedError(
                f"Server not responding at {health_url} -- "
                "run `qa-harness start` first or check `qa-harness status`. "
                f"Error: {e}"
            ) from e

    def cleanup(self) -> dict:
        """Parse cleanup_endpoint (e.g., 'DELETE /cypress/cleanup'), execute it.
        Returns the response dict."""
        method, path = self._parse_endpoint_string(
            self.seed_config.cleanup_endpoint
        )
        logger.info("Running cleanup: %s %s", method, path)
        _status_code, body = self._request(method, path)
        return body

    def execute_plan(self, plan_path: str, health_url: str) -> list[dict]:
        """Load JSON seed plan from file, validate against catalog,
        call cleanup first, then execute each step sequentially.
        Return list of results [{endpoint, status_code, response_body}]."""
        self.check_server_alive(health_url)

        # Load plan
        try:
            with open(plan_path, "r") as f:
                plan = json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            raise SeedError(f"Could not load seed plan {plan_path}: {e}") from e

        if not isinstance(plan, list):
            raise SeedError(
                f"Seed plan must be a JSON array, got {type(plan).__name__}"
            )

        # Validate
        errors = self.validate_plan(plan)
        if errors:
            raise SeedError(
                "Seed plan validation failed:\n" + "\n".join(f"  - {e}" for e in errors)
            )

        # Cleanup before seeding
        self.cleanup()

        # Execute steps
        results = []
        for i, step in enumerate(plan):
            logger.info(
                "Seed step %d/%d: %s %s",
                i + 1,
                len(plan),
                step.get("method", "?"),
                step.get("path", "?"),
            )
            result = self._execute_step(step)
            results.append(result)

        return results

    def validate_plan(self, plan: list[dict]) -> list[str]:
        """Validate a seed plan against the available_endpoints catalog.
        Return list of error messages (empty = valid).

        Checks: method+path exists in catalog, ordering respects
        'requires' dependencies (direct only).
        """
        errors = []

        # Build catalog lookup: (method, path) -> SeedEndpoint
        catalog = {}
        for ep in self.seed_config.available_endpoints:
            catalog[(ep.method.upper(), ep.path)] = ep

        # Track which paths have been called (for dependency ordering)
        called_paths: list[str] = []

        for i, step in enumerate(plan):
            method = step.get("method", "").upper()
            path = step.get("path", "")

            if not method or not path:
                errors.append(f"Step {i}: missing 'method' or 'path'")
                continue

            # Check if the endpoint exists in the catalog
            # For paths with placeholders like /cypress/invites/{email_base64},
            # match by prefix
            ep = catalog.get((method, path))
            if ep is None:
                # Try placeholder matching
                ep = self._find_placeholder_match(method, path, catalog)
            if ep is None:
                errors.append(
                    f"Step {i}: {method} {path} not in available_endpoints catalog"
                )
                continue

            # Check dependency ordering
            for req_path in ep.requires:
                if req_path not in called_paths:
                    errors.append(
                        f"Step {i}: {method} {path} requires {req_path} "
                        f"to be called first"
                    )

            called_paths.append(path)

        return errors

    def list_endpoints(self) -> str:
        """Format available_endpoints as human-readable text for the seed planner.

        Shows method, path, params with types, creates/returns description,
        and dependency ordering.
        """
        lines = ["Available seed endpoints:", ""]

        for ep in self.seed_config.available_endpoints:
            lines.append(f"  {ep.method} {ep.path}")

            if ep.params:
                param_parts = []
                for name, type_hint in ep.params.items():
                    param_parts.append(f"{name}: {type_hint}")
                lines.append(f"    Params: {{{', '.join(param_parts)}}}")

            if ep.requires:
                lines.append(f"    Requires: {', '.join(ep.requires)}")

            if ep.creates:
                lines.append(f"    Creates: {ep.creates}")

            if ep.returns:
                lines.append(f"    Returns: {ep.returns}")

            lines.append("")

        # Cleanup endpoint
        lines.append(f"Cleanup: {self.seed_config.cleanup_endpoint}")
        lines.append(
            "  (Always called automatically before seeding. "
            "Call explicitly between test scenarios.)"
        )

        return "\n".join(lines)

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _execute_step(self, step: dict) -> dict:
        """Execute one seed plan step: {method, path, body?}.
        Return {endpoint, status_code, response_body}."""
        method = step.get("method", "").upper()
        path = step.get("path", "")
        body = step.get("body")

        status_code, response_body = self._request(method, path, body)
        return {
            "endpoint": f"{method} {path}",
            "status_code": status_code,
            "response_body": response_body,
        }

    def _request(
        self, method: str, path: str, body: Optional[dict] = None
    ) -> tuple[int, Any]:
        """HTTP request wrapper. Adapted from CypressApi._request.

        Returns (status_code, parsed_body) tuple.
        """
        url = f"{self.base_url}{path}"
        try:
            response = self.session.request(
                method, url, json=body, timeout=self.timeout
            )
        except (requests.RequestException, ConnectionError) as e:
            raise SeedError(
                f"Network error on {method} {path}: {e}"
            ) from e

        if not response.ok:
            raise SeedError(
                f"Seed endpoint error {response.status_code} on "
                f"{method} {path}: {response.text[:200]}"
            )

        if response.status_code == 204 or not response.content:
            return response.status_code, None

        try:
            return response.status_code, response.json()
        except ValueError:
            return response.status_code, response.text

    def _parse_endpoint_string(self, endpoint_str: str) -> tuple[str, str]:
        """Parse 'DELETE /cypress/cleanup' into ('DELETE', '/cypress/cleanup')."""
        parts = endpoint_str.strip().split(None, 1)
        if len(parts) != 2:
            raise SeedError(
                f"Invalid endpoint string: {endpoint_str!r}. "
                "Expected format: 'METHOD /path'"
            )
        return parts[0].upper(), parts[1]

    def _find_placeholder_match(
        self, method: str, path: str, catalog: dict
    ) -> Optional[Any]:
        """Match a concrete path against catalog entries with {placeholders}."""
        for (cat_method, cat_path), ep in catalog.items():
            if cat_method != method:
                continue
            if "{" not in cat_path:
                continue
            # Simple prefix match: /cypress/invites/{email_base64}
            # matches /cypress/invites/abc123
            prefix = cat_path.split("{")[0]
            if path.startswith(prefix):
                return ep
        return None
