# CLAUDE.md Hardening Report

**Source:** reviews/spec-round-1/verdict.md, reviews/impl-round-1/FAILURE-REPORT.md, reviews/IMPL-REVIEW-COMPLETE.md
**Date:** 2026-06-24

## Rules Added to ~/claude-hub/inflow-ats/CLAUDE.md

None. All findings from this feature's review cycle are covered by existing Known Failure Patterns or are one-offs.

## Existing Rules That Were Violated

- **Known Failure Pattern #3** ("Specs and plans must include test requirements"): violated in spec-round-1 F1 (HIGH) — the spec had no test requirements section. The spec review agent caught it and added the section. No change needed — the rule exists, the review process enforced it.

- **Known Failure Pattern #14** ("Analog structural matching: compare signatures, not just layers"): violated in impl-round-1 F2 (MED) — the `all_stages` controller action had a `rescue StandardError => e` block that the analog `create` action does not have. The review agent caught it; the fix agent removed it. No change needed — the rule exists, the review process enforced it.

## Findings Skipped (one-offs, not patterns)

- **impl-round-1 F1 (HIGH)** Missing controller spec: the spec's test requirements section explicitly listed a controller spec, but the implementation agent didn't create it. This is a spec-compliance miss (the agent skipped one task in a list), not a systemic pattern. The spec said what to do; the agent just didn't do it. The review process caught it.
