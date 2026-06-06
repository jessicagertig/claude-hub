"""Server lifecycle management, adapted from inflow_bootstrap.py.

Manages the test server and supporting processes as subprocesses. Config-driven
instead of hardcoded -- server commands, health check paths, and timeouts all
come from qa-config.yml.

The bash -c wrapper exists so we can source nvm (or any shell function) in the
subprocess shell -- Python's subprocess does not inherit shell functions.
"""

import atexit
import datetime
import json
import logging
import os
import signal
import subprocess
import sys
import time
from typing import Optional

import requests

from qa_harness.config import ServerConfig
from qa_harness.errors import ServerError

logger = logging.getLogger(__name__)

STATE_FILE = "/tmp/qa-harness-state.json"


class ServerManager:
    """Manages a test server and supporting processes as subprocesses."""

    def __init__(self, config: ServerConfig, source_repo: str, config_path: Optional[str] = None):
        self.config = config
        self.source_repo = source_repo
        self.config_path = config_path
        self._procs: list[tuple[subprocess.Popen, str]] = []
        self._cleanup_registered = False
        self._started_at: Optional[str] = None
        self._detached = False

    def is_running(self) -> bool:
        return len(self._procs) > 0

    def start(self, detach: bool = False) -> None:
        """Kill existing processes on port, start server + supporting processes,
        poll health check.

        Args:
            detach: If True (CLI mode), subprocesses survive after the
                parent Python process exits. No atexit/signal cleanup is
                registered. If False (context-manager mode), cleanup
                handlers are registered so subprocesses are terminated
                when the parent exits.
        """
        self._detached = detach
        self._kill_existing_processes()

        env = os.environ.copy()
        # Enforce RAILS_ENV=test defensively, matching the analog
        # (inflow_bootstrap.py). The spec's hard rules require
        # RAILS_ENV=test always -- we must not rely on config commands
        # to include it inline.
        env["RAILS_ENV"] = "test"

        # Start the main server
        logger.info(
            "Starting server on port %d in %s",
            self.config.port,
            self.source_repo,
        )
        server_proc = self._start_subprocess(
            self.config.start_command, "server", env
        )
        self._procs.append((server_proc, "server"))

        # Start supporting processes
        for i, cmd in enumerate(self.config.supporting_commands):
            label = _extract_process_label(cmd, i)
            logger.info("Starting supporting process: %s", label)
            proc = self._start_subprocess(cmd, label, env)
            self._procs.append((proc, label))

        if not detach:
            self._register_cleanup()
        self._wait_for_health()
        self._started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
        self._write_state_file()
        logger.info("Server ready at %s", self.config.base_url)

    def stop(self) -> None:
        """SIGTERM all subprocesses, wait 10s, SIGKILL if needed, print STOPPED."""
        for proc, label in self._procs:
            try:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    logger.warning(
                        "%s did not terminate gracefully, killing", label
                    )
                    proc.kill()
                    proc.wait(timeout=5)
            except Exception as e:
                logger.warning("Error stopping %s: %s", label, e)

        self._procs = []
        self._started_at = None
        self._remove_state_file()

    def status(self) -> dict:
        """Return dict with is_running, port, pids, uptime."""
        state = self._read_state_file()
        if state is None:
            return {
                "is_running": False,
                "port": self.config.port,
                "pids": [],
                "labels": [],
                "uptime": None,
            }

        # Verify PIDs are actually alive
        live_pids = []
        live_labels = []
        for pid, label in zip(state.get("pids", []), state.get("labels", [])):
            try:
                os.kill(pid, 0)
                live_pids.append(pid)
                live_labels.append(label)
            except (ProcessLookupError, PermissionError):
                pass

        is_running = len(live_pids) > 0
        uptime = None
        if is_running and state.get("started_at"):
            try:
                started = datetime.datetime.fromisoformat(state["started_at"])
                uptime = str(
                    datetime.datetime.now(datetime.timezone.utc) - started
                )
            except (ValueError, TypeError):
                pass

        return {
            "is_running": is_running,
            "port": state.get("port", self.config.port),
            "pids": live_pids,
            "labels": live_labels,
            "uptime": uptime,
        }

    def __enter__(self) -> "ServerManager":
        self.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.stop()

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _kill_existing_processes(self) -> None:
        """Kill PIDs on configured port via lsof, kill supporting processes via pgrep.

        Uses os.system with temp-file redirection so tests which mock
        subprocess.Popen aren't affected by the cleanup step.
        """
        killed_port = self._kill_pids_from_command(
            f"lsof -ti tcp:{self.config.port}",
            label=f"port {self.config.port}",
        )
        killed_supporting = False
        for cmd in self.config.supporting_commands:
            keyword = _extract_process_keyword(cmd)
            if keyword:
                killed = self._kill_pids_from_command(
                    f"pgrep -f {keyword}",
                    label=keyword,
                )
                killed_supporting = killed_supporting or killed

        if killed_port or killed_supporting:
            time.sleep(2)

    def _kill_pids_from_command(self, command: str, label: str) -> bool:
        """Run a shell command that prints PIDs, SIGTERM each.
        Return True if any killed."""
        import tempfile

        try:
            with tempfile.NamedTemporaryFile(mode="r", delete=False) as tmp:
                tmp_path = tmp.name
            os.system(f"{command} > {tmp_path} 2>/dev/null")
            with open(tmp_path, "r") as f:
                output = f.read()
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
        except Exception as e:
            logger.debug("Skipping kill step for %s: %s", label, e)
            return False

        pids = [p.strip() for p in output.splitlines() if p.strip()]
        killed_any = False
        for pid in pids:
            logger.info("Killing existing %s process (pid %s)", label, pid)
            try:
                os.kill(int(pid), signal.SIGTERM)
                killed_any = True
            except (ProcessLookupError, ValueError):
                pass
        return killed_any

    def _start_subprocess(
        self, command: str, label: str, env: dict
    ) -> subprocess.Popen:
        """Start a subprocess via bash -c wrapper. Logs command and PID.

        In detach mode (CLI start/stop), stdout goes to DEVNULL so the
        child survives after the parent Python process exits. With PIPE,
        the child receives SIGPIPE when the parent exits and the pipe
        closes. In attached mode (context manager), stdout goes to PIPE
        so the parent can read subprocess output.
        """
        if self._detached:
            stdout_target = subprocess.DEVNULL
            stderr_target = subprocess.DEVNULL
        else:
            stdout_target = subprocess.PIPE
            stderr_target = subprocess.STDOUT

        proc = subprocess.Popen(
            ["bash", "-c", command],
            cwd=self.source_repo,
            env=env,
            stdout=stdout_target,
            stderr=stderr_target,
        )
        logger.info("Started %s (pid %d)", label, proc.pid)
        return proc

    def _wait_for_health(self) -> None:
        """Poll GET base_url+health_check_path every 1s. Accept status < 500.
        Check for premature process exit on each iteration.
        Raise ServerError on timeout."""
        health_url = self.config.base_url.rstrip("/") + self.config.health_check_path
        deadline = time.time() + self.config.startup_timeout_seconds
        last_err: Optional[str] = None

        while time.time() < deadline:
            # Check for premature exit of the main server process
            if self._procs:
                main_proc, main_label = self._procs[0]
                if main_proc.poll() is not None:
                    raise ServerError(
                        f"Server process exited prematurely with code "
                        f"{main_proc.returncode}"
                    )
            try:
                response = requests.get(health_url, timeout=5)
                if response.status_code < 500:
                    return
            except Exception as e:
                last_err = str(e)
            time.sleep(1)

        raise ServerError(
            f"Health check timed out after {self.config.startup_timeout_seconds}s "
            f"polling {health_url}. Last error: {last_err}"
        )

    def _check_server_alive(self) -> bool:
        """Quick health check -- hit the health endpoint, return True if < 500."""
        health_url = self.config.base_url.rstrip("/") + self.config.health_check_path
        try:
            response = requests.get(health_url, timeout=5)
            return response.status_code < 500
        except Exception:
            return False

    def _register_cleanup(self) -> None:
        """atexit + SIGINT/SIGTERM handlers."""
        if self._cleanup_registered:
            return
        atexit.register(self.stop)
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                signal.signal(sig, self._signal_handler)
            except (ValueError, OSError):
                pass
        self._cleanup_registered = True

    def _signal_handler(self, signum, frame) -> None:
        """Stop all subprocesses, exit with 128+signum."""
        logger.info("Received signal %d, stopping QA harness server", signum)
        self.stop()
        sys.exit(128 + signum)

    def _write_state_file(self) -> None:
        """Write process state to /tmp for stop/status commands."""
        state = {
            "config_path": self.config_path,
            "base_url": self.config.base_url,
            "port": self.config.port,
            "pids": [proc.pid for proc, _ in self._procs],
            "labels": [label for _, label in self._procs],
            "started_at": self._started_at,
        }
        try:
            with open(STATE_FILE, "w") as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            logger.warning("Could not write state file: %s", e)

    def _remove_state_file(self) -> None:
        """Remove the state file."""
        try:
            os.unlink(STATE_FILE)
        except OSError:
            pass

    def _read_state_file(self) -> Optional[dict]:
        """Read the state file, return None if missing or invalid."""
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return None


def stop_from_state_file(config: ServerConfig) -> bool:
    """Stop processes using the state file. Fallback to lsof if state file missing.
    Returns True if processes were stopped."""
    try:
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
    except (OSError, json.JSONDecodeError):
        state = None

    stopped = False

    if state and "pids" in state:
        for pid in state["pids"]:
            try:
                os.kill(pid, signal.SIGTERM)
                stopped = True
                logger.info("Sent SIGTERM to pid %d", pid)
            except (ProcessLookupError, PermissionError):
                pass
    else:
        # Fallback: kill by port
        import tempfile

        try:
            with tempfile.NamedTemporaryFile(mode="r", delete=False) as tmp:
                tmp_path = tmp.name
            os.system(f"lsof -ti tcp:{config.port} > {tmp_path} 2>/dev/null")
            with open(tmp_path, "r") as f:
                output = f.read()
            try:
                os.unlink(tmp_path)
            except OSError:
                pass
            for pid_str in output.splitlines():
                pid_str = pid_str.strip()
                if pid_str:
                    try:
                        os.kill(int(pid_str), signal.SIGTERM)
                        stopped = True
                        logger.info("Sent SIGTERM to pid %s (from lsof)", pid_str)
                    except (ProcessLookupError, ValueError, PermissionError):
                        pass
        except Exception as e:
            logger.warning("Fallback kill failed: %s", e)

    # Remove state file
    try:
        os.unlink(STATE_FILE)
    except OSError:
        pass

    return stopped


def _extract_process_keyword(command: str) -> str:
    """Extract a distinctive keyword from a shell command for pgrep -f.

    For 'bundle exec sidekiq', returns 'sidekiq'.
    For 'bundle exec rails s -p 5007', returns 'rails'.
    """
    # Split on common shell operators to get the actual command part
    # Strip nvm/source preamble by taking text after the last '&&'
    parts = command.split("&&")
    actual_cmd = parts[-1].strip()

    # Look for known keywords in order of distinctiveness
    keywords = ["sidekiq", "puma", "unicorn", "rails", "node", "next"]
    for kw in keywords:
        if kw in actual_cmd:
            return kw

    # Fall back to the first word after 'exec' if present
    words = actual_cmd.split()
    for i, word in enumerate(words):
        if word == "exec" and i + 1 < len(words):
            return words[i + 1]

    # Last resort: first word
    return words[0] if words else ""


def _extract_process_label(command: str, index: int) -> str:
    """Extract a human-readable label from a shell command."""
    keyword = _extract_process_keyword(command)
    return keyword if keyword else f"supporting-{index}"
