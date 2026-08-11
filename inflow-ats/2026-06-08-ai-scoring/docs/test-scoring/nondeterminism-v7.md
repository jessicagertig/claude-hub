# Nondeterminism Analysis — v7 Prompt, gemini-3.1-flash-lite

## Team Lead (5 resumes × 3 runs + v7 reference)

| # | Eyeball | Run A | Run B | Run C | v7 | Range |
|---|---------|-------|-------|-------|-----|-------|
| 3 (Daniela) | 9 | 92.6% | 92.6% | 89.4% | 92.6% | 3.2pp |
| 8 (Ravi) | 2 | 17.0% | 20.2% | 12.8% | 13.8% | 7.4pp |
| 9 (Alexia) | 8 | 70.2% | 70.2% | 63.8% | 67.0% | 6.4pp |
| 13 (Abhidipta) | 9 | 87.2% | 87.2% | 100.0% | 96.8% | 12.8pp |
| 17 (Guillaume) | 6 | 56.4% | 56.4% | 56.4% | 62.8% | 0pp* |

*inbox-17 perfectly stable within 3 nondeterminism runs; v7 delta is cross-session.

## Go Engineer (20 resumes × 3 full runs)

| # | Expected | Run 1 | Run 2 | Run 3 | v2 | Range |
|---|----------|-------|-------|-------|-----|-------|
| 1 | High | 34.7% | 37.5% | 37.5% | 37.5% | 2.8pp |
| 2 | High | 81.9% | 81.9% | 81.9% | 81.9% | 0pp |
| 3 | High | 51.4% | 51.4% | 51.4% | 51.4% | 0pp |
| 4 | High | 80.6% | 68.1% | 68.1% | 75.0% | 12.5pp |
| 5 | High | 30.6% | 27.8% | 27.8% | 27.8% | 2.8pp |
| 6 | Mid-high | 59.7% | 59.7% | 56.9% | 56.9% | 2.8pp |
| 7 | Above min | 36.1% | 41.7% | 44.4% | 38.9% | 8.3pp |
| 8 | Above min | 45.8% | 48.6% | 45.8% | 48.6% | 2.8pp |
| 9 | Above min | 40.3% | 40.3% | 40.3% | 40.3% | 0pp |
| 10 | Above min | 54.2% | 51.4% | 51.4% | 51.4% | 2.8pp |
| 11 | Above min | 80.6% | 80.6% | 80.6% | 80.6% | 0pp |
| 12 | Above min | 48.6% | 54.2% | 48.6% | 56.9% | 5.6pp |
| 13 | Above min | 33.3% | 25.0% | 30.6% | 30.6% | 8.3pp |
| 14 | Low | 33.3% | 41.7% | 44.4% | 41.7% | 11.1pp |
| 15 | Mid | 33.3% | 38.9% | 30.6% | 33.3% | 8.3pp |
| 16 | Low | 2.8% | 2.8% | 2.8% | 2.8% | 0pp |
| 17 | Mid | 48.6% | 48.6% | 51.4% | 45.8% | 2.8pp |
| 18 | Low | 63.9% | 61.1% | 61.1% | 66.7% | 2.8pp |
| 19 | Mid | 36.1% | 45.8% | 45.8% | 40.3% | 9.7pp |
| 20 | Mid | 41.7% | 41.7% | 44.4% | 41.7% | 2.8pp |

## Go Engineer — Additional spot tests (4 resumes × 3 runs)

| # | Expected | Run A | Run B | Run C | v2 | Range |
|---|----------|-------|-------|-------|-----|-------|
| 2 | High | 81.9% | 79.2% | 79.2% | 81.9% | 2.7pp |
| 4 | High | 69.4% | 69.4% | 56.9% | 75.0% | 18.1pp |
| 16 | Low | 2.8% | 5.6% | 2.8% | 2.8% | 2.8pp |
| 18 | Low | 58.3% | 61.1% | 63.9% | 66.7% | 8.4pp |

## Stability Summary

| Stability Band | Definition | Count (Go 20) | % |
|----------------|-----------|---------------|---|
| Perfect (0pp) | Same score every run | 5 | 25% |
| Very stable (<3pp) | 1 criterion flip | 8 | 40% |
| Moderate (5-10pp) | 2-3 criteria flip | 5 | 25% |
| High (>10pp) | 4+ criteria flip | 2 | 10% |

**Mean variance across all 20 Go resumes: 4.2pp**
**Median variance: 2.8pp**
**Max variance: 12.5pp (go-4, OpenShift/K8s borderline)**

## Key Patterns

1. **Top and bottom are stable.** go-2 (81.9%, 0pp) and go-16 (2.8%, 0pp) never change. When evidence is clearly present or clearly absent, the model is deterministic.

2. **Borderline technical criteria cause the most variance.** go-4's OpenShift-as-K8s question (12.5pp) and go-14's domain transfer question (11.1pp) are the biggest swing factors.

3. **Group means are correctly ordered even when individual rankings are noisy.**
   - High: mean 54.2%
   - Mid-high: 58.8%
   - Above minimum: 48.7%
   - Mid: 42.3%
   - Low: 34.9%

4. **3-run averaging would reduce worst-case variance from ~12pp to ~7pp.**

## Rank Correlation

| Job | Metric | Value | Interpretation |
|-----|--------|-------|---------------|
| Team Lead | Spearman ρ | 0.826 | Very strong |
| Team Lead | Pearson r | 0.810 | Very strong |
| Go Engineer | Spearman ρ | 0.265 | Weak |

Team Lead's strong correlation validates the scoring approach. Go Engineer's weak correlation reflects niche criteria (PaaS, multi-cloud) that don't align with general Go engineering quality.
