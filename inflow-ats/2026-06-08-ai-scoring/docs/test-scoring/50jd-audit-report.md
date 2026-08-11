# 50 JD Audit Report

49 JDs processed through Call 2 (Gemini) + Call 2b (Gemini) using existing Call 1 sections from 180-JD benchmark.

## Critical Issues

### CRITERIA_LOST — Call 2b is deleting criteria (4 JDs)

| JD | Call 2 | Final | Lost |
|---|--------|-------|------|
| PharmD SaaS Business Strategist | 30 | 7 | 77% lost |
| Director of Learning Content | 40 | 3 | 93% lost |
| Head of Process Engineering | 25 | 15 | 40% lost |
| Bags and Packs Developer | 24 | 9 | 63% lost |
| Fire Alarm (batch 1) | 32 | 12 | 63% lost |

Call 2b is supposed to keep or decompose — never remove. It's removing criteria. This is a serious bug in the Call 2b prompt or schema.

### SOFT_T1 — Soft skills leaking to tier_1 (2 JDs)

| JD | Which soft skill |
|---|---|
| Senior Propulsion Development Engineer | Unknown — need to check |
| Operations Associate | Unknown — need to check |

Self-review is working on most JDs but still leaking on 2 of 49 (4%).

### HIGH_T1 — Over 50% of criteria at tier_1 (2 JDs)

| JD | T1 | Total | % |
|---|---|---|---|
| Cloud Engineer (batch 1) | 18 | 33 | 55% |
| Full Stack Engineer | 6 | 11 | 55% |

## Over-decomposition (>8 decompositions)

| JD | Decomp | Call 2 → Final |
|---|---|---|
| Senior Software Engineer | 11 | 29→47 |
| Chief Marketing Officer | 9 | 33→46 |

## Summary Statistics

| Metric | Value |
|---|---|
| Total JDs | 49 |
| Criteria lost (>30% reduction) | 5 (10%) |
| Soft skills at T1 | 2 (4%) |
| Over 50% T1 | 2 (4%) |
| Over-decomposed (>8) | 2 (4%) |
| Zero decompositions | 14 (29%) |
| Clean runs (no flags) | 34 (69%) |

## Assessment

69% of JDs process cleanly. The 31% with issues break down as:
- **Criteria loss is the most serious** — Call 2b is deleting criteria it should be keeping. This affects 10% of JDs.
- **Soft skills leaking** is rare (4%) and may be edge cases.
- **Over-decomposition** happens on complex JDs with many compound responsibilities.
- **High T1** typically comes from JDs where the author used strong signal words everywhere.

The criteria loss issue needs investigation before anything else. Call 2b should NEVER return fewer criteria than it received (unless it marks duplicates, which it's not doing here — duplicate detection was removed).
