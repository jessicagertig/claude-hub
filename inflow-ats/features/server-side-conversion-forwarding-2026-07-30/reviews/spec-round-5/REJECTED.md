# Spec review round 5 — findings not applied

None. All seven findings were verified against the live codebase on branch `server-side-conversion-events` and
against the authoritative reference material in this directory, and all seven were applied.

Verification performed per finding is recorded in `FINDINGS.md`. The two claims most worth re-checking if this
round is ever revisited:

- F1's claim that the cited precedents pass model instances. Confirmed at four call sites and one rules file
  line, all quoted in `FINDINGS.md`.
- F3's claim that the third dot-separated segment of the `_ga_<container>` value is the session's start time
  in Unix seconds. Confirmed at `GCLID-THROUGH-GA4.md:130` and `GCLID-THROUGH-GA4.md:488`, both giving the
  format as `GS1.1.<timestamp>.<session_number>…`.
