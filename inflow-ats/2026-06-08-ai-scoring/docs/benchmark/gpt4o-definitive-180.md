# Definitive gpt-4o Analysis — All 180 JDs

## Aggregate Stats

| Metric | Value |
|---|---|
| JDs processed | 174 |
| JDs with criteria | 152 |
| JDs skipped (minimal/general) | 22 |
| Total criteria extracted | 2,800 |
| Avg criteria per JD | 18.4 |
| Tier 1 | 571 (20.4%) |
| Tier 2 | 2,166 (77.4%) |
| Tier 3 | 63 (2.2%) |
| Binary flagged | 145 (5.2%) |
| Avg binary per JD | 1.0 |
| Text preservation | 1,771/2,800 (63.2%) |
| Avg T1% per JD | 20.2% |

## Flag Summary

| Flag | Count | Notes |
|---|---|---|
| HIGH_T1 | 2 | Both Fire Alarm JDs — known structural issue |
| NO_BINARY | 52 | 41 legitimate (no binary content), 11 real misses |
| ALL_DECOMPOSED | 30 | Text rewriting — nondeterministic, not fixable via prompt |
| OVER_BINARY | 1 | One JD with >50% binary |

## NO_BINARY Real Misses (11 JDs)

These JDs have degree/vehicle/portfolio/cert content that wasn't flagged binary:

| Type | Count | Examples |
|---|---|---|
| Degree missed | 7 | AI/ML Lead, AI Gameplay Programmer, Organic Synthesis Chemist |
| Vehicle missed | 3 | Office Administrator, Project Manager, Software Engineer Fullstack |
| Portfolio missed | 1 | Sales Development Representative |

**Note**: Some of the 11 "real misses" are false positives in the detection script (regex matching "transportation" as a vehicle requirement, or matching words that aren't actually degree requirements). After manual verification, the true binary miss count is closer to 7-9. The most common real miss: compound sentences combining a degree + years of experience, where the model keeps it as one non-binary criterion instead of decomposing.

## 22 Skipped JDs (No Criteria)

All are minimal/general postings: talent pools, open applications, general interest, co-op portal redirects. Correct behavior.

## Comparison: gpt-4o-mini vs gpt-4o (definitive)

| Metric | gpt-4o-mini (55 JDs) | gpt-4o (174 JDs) |
|---|---|---|
| Avg T1% per JD | 22.0% | 20.2% |
| Tier 3 % | 1.7% | 2.2% |
| Binary real misses | 16 | 11 |
| Binary nondeterminism σ | 1.99 | 0.99 |
| T1% nondeterminism σ | 8.0 | 7.3 |
| Stable JDs (nondeterminism test) | 25% | 50% |
| Text preservation | 62.1% | 63.2% |

gpt-4o wins on every metric. Recommended for Call 2.
