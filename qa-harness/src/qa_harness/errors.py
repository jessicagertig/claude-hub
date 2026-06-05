"""Exception hierarchy for the QA verification harness."""


class QAHarnessError(Exception):
    """Base class for all harness errors."""


class ConfigError(QAHarnessError):
    """Config loading or validation failure."""


class ServerError(QAHarnessError):
    """Server lifecycle failure (start timeout, premature exit, health check)."""


class SeedError(QAHarnessError):
    """Seed execution failure (HTTP errors, validation errors)."""
