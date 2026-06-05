"""Command-line interface for the QA verification harness.

Usage:
    qa-harness start [--config PATH]        Start test server
    qa-harness stop [--config PATH]         Stop test server
    qa-harness seed --plan PATH [--config]  Execute seed plan
    qa-harness seed-endpoints [--config]    List available seed endpoints
    qa-harness cleanup [--config PATH]      Run cleanup
    qa-harness status [--config PATH]       Report server status
"""

import argparse
import json
import logging
import sys
from typing import Optional

logger = logging.getLogger(__name__)


def _setup_logging(verbose: bool) -> None:
    """Configure logging. Verbose sends DEBUG to stderr; otherwise INFO."""
    logging.basicConfig(
        level=logging.DEBUG if verbose else logging.INFO,
        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
        stream=sys.stderr,
    )


def cmd_start(args) -> int:
    """Start the test server."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError, ServerError
    from qa_harness.server import ServerManager

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.server is None:
        print("No server configuration in config file", file=sys.stderr)
        return 1

    try:
        manager = ServerManager(config.server, config.source_repo)
        manager.start()
        print("READY")
        return 0
    except ServerError as e:
        print(f"Server error: {e}", file=sys.stderr)
        return 1


def cmd_stop(args) -> int:
    """Stop the test server."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError
    from qa_harness.server import stop_from_state_file

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.server is None:
        print("No server configuration in config file", file=sys.stderr)
        return 1

    stopped = stop_from_state_file(config.server)
    if stopped:
        print("STOPPED")
    else:
        print("No running processes found")
    return 0


def cmd_seed(args) -> int:
    """Execute a seed plan."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError, SeedError
    from qa_harness.seed import SeedExecutor

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.seed is None:
        print("No seed configuration in config file", file=sys.stderr)
        return 1

    if config.server is None:
        print("No server configuration in config file", file=sys.stderr)
        return 1

    health_url = (
        config.server.base_url.rstrip("/") + config.server.health_check_path
    )

    try:
        executor = SeedExecutor(config.seed, config.server.base_url)
        results = executor.execute_plan(args.plan, health_url)
        for result in results:
            print(
                f"  {result['endpoint']} -> {result['status_code']}"
            )
        print(f"Seed plan complete: {len(results)} steps executed")
        return 0
    except SeedError as e:
        print(f"Seed error: {e}", file=sys.stderr)
        return 1


def cmd_seed_endpoints(args) -> int:
    """List available seed endpoints."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError
    from qa_harness.seed import SeedExecutor

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.seed is None:
        print("No seed configuration in config file", file=sys.stderr)
        return 1

    base_url = config.server.base_url if config.server else "http://localhost"
    executor = SeedExecutor(config.seed, base_url)
    print(executor.list_endpoints())
    return 0


def cmd_cleanup(args) -> int:
    """Run cleanup."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError, SeedError
    from qa_harness.seed import SeedExecutor

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.seed is None:
        print("No seed configuration in config file", file=sys.stderr)
        return 1

    if config.server is None:
        print("No server configuration in config file", file=sys.stderr)
        return 1

    health_url = (
        config.server.base_url.rstrip("/") + config.server.health_check_path
    )

    try:
        executor = SeedExecutor(config.seed, config.server.base_url)
        executor.check_server_alive(health_url)
        executor.cleanup()
        print("Cleanup complete")
        return 0
    except SeedError as e:
        print(f"Seed error: {e}", file=sys.stderr)
        return 1


def cmd_status(args) -> int:
    """Report server status."""
    from qa_harness.config import load_config, resolve_config_path
    from qa_harness.errors import ConfigError
    from qa_harness.server import ServerManager

    try:
        config_path = resolve_config_path(args.config)
        config = load_config(config_path)
    except ConfigError as e:
        print(f"Config error: {e}", file=sys.stderr)
        return 1

    if config.server is None:
        print("No server configuration in config file", file=sys.stderr)
        return 1

    manager = ServerManager(config.server, config.source_repo)
    status = manager.status()
    print(json.dumps(status, indent=2))
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    """Main entry point. Parse args, dispatch to handler."""
    parser = argparse.ArgumentParser(
        prog="qa-harness",
        description="QA verification harness for the feature development lifecycle",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    sub = parser.add_subparsers(dest="cmd", required=True)

    # start
    p_start = sub.add_parser("start", help="Start test server")
    p_start.add_argument("--config", default=None, help="Path to qa-config.yml")

    # stop
    p_stop = sub.add_parser("stop", help="Stop test server")
    p_stop.add_argument("--config", default=None, help="Path to qa-config.yml")

    # seed
    p_seed = sub.add_parser("seed", help="Execute a seed plan")
    p_seed.add_argument(
        "--plan", required=True, help="Path to seed plan JSON file"
    )
    p_seed.add_argument("--config", default=None, help="Path to qa-config.yml")

    # seed-endpoints
    p_endpoints = sub.add_parser(
        "seed-endpoints", help="List available seed endpoints"
    )
    p_endpoints.add_argument(
        "--config", default=None, help="Path to qa-config.yml"
    )

    # cleanup
    p_cleanup = sub.add_parser("cleanup", help="Run cleanup")
    p_cleanup.add_argument(
        "--config", default=None, help="Path to qa-config.yml"
    )

    # status
    p_status = sub.add_parser("status", help="Report server status")
    p_status.add_argument(
        "--config", default=None, help="Path to qa-config.yml"
    )

    args = parser.parse_args(argv)
    _setup_logging(args.verbose)

    handlers = {
        "start": cmd_start,
        "stop": cmd_stop,
        "seed": cmd_seed,
        "seed-endpoints": cmd_seed_endpoints,
        "cleanup": cmd_cleanup,
        "status": cmd_status,
    }
    return handlers[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
