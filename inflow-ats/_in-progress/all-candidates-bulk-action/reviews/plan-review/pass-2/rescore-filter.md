# Rescore Filter — Pass 2

No Pass 1 corrections in this angle. Fresh scrutiny.

## Fresh Scrutiny
- Conditional skip of `:current` filter is at the right scope — only lines 36-40 (the `already_summarized_ids` subtraction from both `ready_ids` and `input_ids`)
- `:processing` filter at lines 43-45 correctly left unconditional
- Test plan C.1.1.5 explicitly verifies `:processing` filter still applies with `rescore_requested: true` — good coverage
- The `input_ids -= already_summarized_ids` at line 40 is also skipped when `rescore_requested` — this is correct because rescored candidates should count toward `queued_count`, not be silently dropped from both working set AND input tracking

## Findings
No issues found.
