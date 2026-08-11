# Phase 2 Summary — Go Engineer (20 resumes)

## Prompt version: v7 (v2 for Go scoring files)
Rule added: "If a criterion matches only because of what the role would typically involve — not because the resume describes doing it — score partial_match."

## Full Ranking (v2)

| Rank | # | Name | v1 | v2 | Expected | Notes |
|------|---|------|-----|-----|----------|-------|
| 1 | 2 | Narendran R | 81.9% | 81.9% | High | ✓ Stable |
| 2 | 11 | Abdulrahman | 69.4% | 80.6% | Above min | Overscored |
| 3 | 4 | Ganesh Pawar | 54.2% | 75.0% | High | ✓ Major improvement |
| 4 | 18 | William Morris | 58.3% | 66.7% | Low | Overscored |
| 5 | 6 | Deepak Bhargav | 56.9% | 56.9% | Mid-high+ | ✓ |
| 6 | 12 | Miguel Silva | 48.6% | 56.9% | Above min | ✓ |
| 7 | 3 | Kushagra Shukla | 51.4% | 51.4% | High | Low for High |
| 8 | 10 | Michael Mensah | 51.4% | 51.4% | Above min | ✓ |
| 9 | 8 | Amrish Kumar | 51.4% | 48.6% | Above min | ✓ |
| 10 | 17 | Matheus Caetano | 48.6% | 45.8% | Mid | ✓ |
| 11 | 14 | Ohm Patel | 38.9% | 41.7% | Low | Overscored |
| 12 | 20 | Mayank Mohan | 38.9% | 41.7% | Mid | ✓ |
| 13 | 9 | Furkan Ozalp | 40.3% | 40.3% | Above min | ✓ |
| 14 | 19 | Anna Verkho. | 45.8% | 40.3% | Mid | ✓ |
| 15 | 7 | Julian Lim | 38.9% | 38.9% | Above min | ✓ |
| 16 | 1 | Abhishek | 30.6% | 37.5% | High | Underscored |
| 17 | 15 | Alan Niemiec | 33.3% | 33.3% | Mid | ✓ |
| 18 | 13 | Milan Stankovic | 27.8% | 30.6% | Above min | Low |
| 19 | 5 | Nishant | 30.6% | 27.8% | High | Underscored |
| 20 | 16 | Barruri Sai | 2.8% | 2.8% | Low | ✓ |

## Correlation Assessment

The criteria are extremely demanding and specific to Convox's PaaS/infrastructure niche (multi-cloud, cloud marketplace, multi-tenant HA). Most backend Go engineers won't match these niche criteria regardless of skill level.

### What works
- go-2 (Kubestronaut, Civo) correctly ranks #1 — deep PaaS/K8s experience
- go-4 (Go + OpenShift + distributed systems) improved to #3 in v2
- go-16 (wrong stack entirely) correctly scores 2.8%
- "Above minimum" candidates cluster in 38-57% range appropriately
- "Mid" candidates cluster in 33-46% range appropriately

### What doesn't work
- go-1 and go-5 (High) score 28-38% — both are junior candidates (intern, 5 months Go) with limited matching evidence. Their "High" status may reflect potential/interview performance rather than resume match.
- go-18 (Low) at 66.7% — resume has strong technical content that matches criteria. The "Low" assessment may reflect factors not in the resume.
- go-11 (Above min) at 80.6% — may be overscored based on skills-list inflation.

### Key lesson
The Go criteria are so niche that criteria-based scoring separates "exact domain match" (PaaS/infrastructure Go engineers) from everyone else. The eyeball rankings were likely based on broader Go engineering quality, not PaaS-specific criteria match. This is a criteria design issue, not a scoring prompt issue.

## No prompt change needed for Go
The prompt worked without Go-specific modifications. The domain-agnostic behavior is confirmed.
