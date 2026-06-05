"""Allow `python -m qa_harness` to run the CLI."""

import sys

from qa_harness.cli import main

if __name__ == "__main__":
    sys.exit(main())
