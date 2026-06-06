"""Tests for server lifecycle management.

Mocks subprocess.Popen and requests.get so we don't actually boot servers.
Adapted from test_inflow_bootstrap.py.
"""

import json
from unittest.mock import MagicMock, patch, call

import pytest

from qa_harness.config import ServerConfig
from qa_harness.errors import ServerError
from qa_harness.server import ServerManager, STATE_FILE, _extract_process_keyword


@pytest.fixture
def server_config():
    return ServerConfig(
        start_command="RAILS_ENV=test bundle exec rails s -p 5007",
        base_url="http://app.lvh.me:5007",
        port=5007,
        health_check_path="/",
        startup_timeout_seconds=60,
        supporting_commands=["RAILS_ENV=test bundle exec sidekiq"],
    )


@pytest.fixture
def minimal_server_config():
    return ServerConfig(
        start_command="rails s",
        base_url="http://localhost:3000",
        port=3000,
    )


class TestServerConfig:
    def test_defaults(self):
        cfg = ServerConfig(
            start_command="rails s",
            base_url="http://localhost:3000",
            port=3000,
        )
        assert cfg.health_check_path == "/"
        assert cfg.startup_timeout_seconds == 180
        assert cfg.supporting_commands == []


class TestServerManager:
    def test_constructed_not_started(self, server_config):
        manager = ServerManager(server_config, "/tmp/repo")
        assert not manager.is_running()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_launches_server_and_supporting(
        self, mock_get, mock_popen, server_config, tmp_path
    ):
        mock_proc_server = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_proc_sidekiq = MagicMock(pid=5678, poll=MagicMock(return_value=None))
        mock_popen.side_effect = [mock_proc_server, mock_proc_sidekiq]
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start()

        assert mock_popen.call_count == 2
        assert manager.is_running()

        # Verify bash -c wrapper
        server_call = mock_popen.call_args_list[0]
        assert server_call.args[0] == ["bash", "-c", server_config.start_command]

        sidekiq_call = mock_popen.call_args_list[1]
        assert sidekiq_call.args[0] == [
            "bash", "-c", server_config.supporting_commands[0]
        ]

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_uses_correct_cwd(self, mock_get, mock_popen, server_config):
        mock_popen.return_value = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/my/source/repo")
        manager.start()

        for popen_call in mock_popen.call_args_list:
            assert popen_call.kwargs["cwd"] == "/my/source/repo"

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_sets_rails_env_test(self, mock_get, mock_popen, server_config):
        mock_popen.return_value = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start()

        for popen_call in mock_popen.call_args_list:
            env = popen_call.kwargs["env"]
            assert env["RAILS_ENV"] == "test"

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    @patch("qa_harness.server.time.sleep")
    def test_start_raises_on_health_check_timeout(
        self, mock_sleep, mock_get, mock_popen, server_config
    ):
        mock_popen.return_value = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_get.side_effect = Exception("connection refused")

        server_config.startup_timeout_seconds = 2
        manager = ServerManager(server_config, "/tmp/repo")
        with pytest.raises(ServerError, match="Health check timed out"):
            manager.start()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_raises_on_premature_exit(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc = MagicMock(pid=1234)
        mock_proc.poll.return_value = 1
        mock_proc.returncode = 1
        mock_popen.return_value = mock_proc
        mock_get.side_effect = Exception("connection refused")

        manager = ServerManager(server_config, "/tmp/repo")
        with pytest.raises(ServerError, match="exited prematurely"):
            manager.start()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_stop_terminates_all_processes(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc_server = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_proc_sidekiq = MagicMock(pid=5678, poll=MagicMock(return_value=None))
        mock_popen.side_effect = [mock_proc_server, mock_proc_sidekiq]
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start()
        manager.stop()

        mock_proc_server.terminate.assert_called_once()
        mock_proc_sidekiq.terminate.assert_called_once()
        assert not manager.is_running()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_stop_kills_if_terminate_times_out(
        self, mock_get, mock_popen, server_config
    ):
        import subprocess as sp

        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_proc.wait.side_effect = sp.TimeoutExpired("cmd", 10)
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start()
        manager.stop()

        mock_proc.kill.assert_called()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_status_returns_dict(self, mock_get, mock_popen, server_config):
        manager = ServerManager(server_config, "/tmp/repo")
        status = manager.status()
        assert "is_running" in status
        assert "port" in status
        assert "pids" in status
        assert status["is_running"] is False

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_context_manager_starts_and_stops(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        with ServerManager(server_config, "/tmp/repo") as manager:
            assert manager.is_running()
        assert not manager.is_running()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_state_file_written_on_start(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start()

        import os

        assert os.path.isfile(STATE_FILE)
        with open(STATE_FILE) as f:
            state = json.load(f)
        assert state["port"] == 5007
        assert len(state["pids"]) > 0

        manager.stop()
        assert not os.path.isfile(STATE_FILE)

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_detach_skips_cleanup_registration(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start(detach=True)

        assert not manager._cleanup_registered
        manager.stop()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_no_detach_registers_cleanup(
        self, mock_get, mock_popen, server_config
    ):
        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start(detach=False)

        assert manager._cleanup_registered
        manager.stop()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_detach_uses_devnull(
        self, mock_get, mock_popen, server_config
    ):
        import subprocess as sp

        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start(detach=True)

        for popen_call in mock_popen.call_args_list:
            assert popen_call.kwargs["stdout"] == sp.DEVNULL
            assert popen_call.kwargs["stderr"] == sp.DEVNULL

        manager.stop()

    @patch("qa_harness.server.subprocess.Popen")
    @patch("qa_harness.server.requests.get")
    def test_start_attached_uses_pipe(
        self, mock_get, mock_popen, server_config
    ):
        import subprocess as sp

        mock_proc = MagicMock(pid=1234, poll=MagicMock(return_value=None))
        mock_popen.return_value = mock_proc
        mock_get.return_value = MagicMock(status_code=200)

        manager = ServerManager(server_config, "/tmp/repo")
        manager.start(detach=False)

        for popen_call in mock_popen.call_args_list:
            assert popen_call.kwargs["stdout"] == sp.PIPE
            assert popen_call.kwargs["stderr"] == sp.STDOUT

        manager.stop()


class TestExtractProcessKeyword:
    def test_extracts_sidekiq(self):
        assert _extract_process_keyword("bundle exec sidekiq") == "sidekiq"

    def test_extracts_from_nvm_preamble(self):
        cmd = "source ~/.nvm/nvm.sh && nvm use > /dev/null 2>&1 && bundle exec sidekiq"
        assert _extract_process_keyword(cmd) == "sidekiq"

    def test_extracts_rails(self):
        cmd = "bundle exec rails s -p 5007"
        assert _extract_process_keyword(cmd) == "rails"

    def test_fallback_to_exec_next_word(self):
        cmd = "bundle exec custom_process"
        assert _extract_process_keyword(cmd) == "custom_process"
