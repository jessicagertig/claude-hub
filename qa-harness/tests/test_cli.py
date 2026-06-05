"""Tests for CLI argument parsing and subcommand dispatch."""

import json
from unittest.mock import patch, MagicMock

import pytest

from qa_harness.cli import main


class TestArgParsing:
    """Test that subcommands parse their arguments correctly."""

    def test_start_parses_config(self):
        with patch("qa_harness.cli.cmd_start", return_value=0) as mock:
            main(["start", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.config == "/path/to/config.yml"
            assert args.cmd == "start"

    def test_stop_parses_config(self):
        with patch("qa_harness.cli.cmd_stop", return_value=0) as mock:
            main(["stop", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.config == "/path/to/config.yml"

    def test_seed_parses_plan_and_config(self):
        with patch("qa_harness.cli.cmd_seed", return_value=0) as mock:
            main(["seed", "--plan", "/path/to/plan.json", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.plan == "/path/to/plan.json"
            assert args.config == "/path/to/config.yml"

    def test_seed_requires_plan(self):
        with pytest.raises(SystemExit):
            main(["seed"])

    def test_seed_endpoints_parses_config(self):
        with patch("qa_harness.cli.cmd_seed_endpoints", return_value=0) as mock:
            main(["seed-endpoints", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.config == "/path/to/config.yml"

    def test_cleanup_parses_config(self):
        with patch("qa_harness.cli.cmd_cleanup", return_value=0) as mock:
            main(["cleanup", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.config == "/path/to/config.yml"

    def test_status_parses_config(self):
        with patch("qa_harness.cli.cmd_status", return_value=0) as mock:
            main(["status", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.config == "/path/to/config.yml"

    def test_no_subcommand_exits(self):
        with pytest.raises(SystemExit):
            main([])

    def test_default_config_is_none(self):
        with patch("qa_harness.cli.cmd_start", return_value=0) as mock:
            main(["start"])
            args = mock.call_args[0][0]
            assert args.config is None


class TestVerboseFlag:
    def test_verbose_flag_accepted(self):
        with patch("qa_harness.cli.cmd_start", return_value=0) as mock:
            main(["-v", "start", "--config", "/path/to/config.yml"])
            args = mock.call_args[0][0]
            assert args.verbose is True

    def test_no_verbose_defaults_false(self):
        with patch("qa_harness.cli.cmd_start", return_value=0) as mock:
            main(["start"])
            args = mock.call_args[0][0]
            assert args.verbose is False


class TestReturnCodes:
    @patch("qa_harness.cli.cmd_start", return_value=0)
    def test_success_returns_0(self, mock):
        result = main(["start"])
        assert result == 0

    @patch("qa_harness.cli.cmd_start", return_value=1)
    def test_error_returns_1(self, mock):
        result = main(["start"])
        assert result == 1
