# Overnight Scoring Session — Status Report

## Prompt State (v7)

File: `app/services/ai_job_application_action/scoring/prompts/candidate_criteria_scoring.rb`
Model: gemini-3.1-flash-lite

Current prompt (3 rules total):
1. Core: score full_match / partial_match / not_found with reasoning citing resume evidence
2. "If a criterion matches only because of what the role would typically involve — not because the resume describes doing it — score partial_match." (NEW in v7)
3. Multilingual ≠ communication skills
4. Years of experience domain guidance (tiered)

## Prompt Evolution

| Version | Rule | Result |
|---------|------|--------|
| v5 | Minimal + 2 rules (multilingual, years) | 95.75% accuracy on 400 criteria |
| v6 | Added "do not infer from job titles/company types" | Fixed inbox-15 but REGRESSED inbox-13 by 12.8 points |
| v7 | Refined to "If criterion matches only because of what role would typically involve..." | Fixed inbox-15 (78.7%→66.0%) WITHOUT regressing inbox-13 (stable at 96.8%) |

## Scoring Progress

### Team Lead Customer Support — 86 resumes scored (v7)

| Score Range | Count | % |
|-------------|-------|---|
| 90-100% | 12 | 14% |
| 80-90% | 12 | 14% |
| 70-80% | 12 | 14% |
| 60-70% | 7 | 8% |
| 50-60% | 6 | 7% |
| 40-50% | 11 | 13% |
| 30-40% | 8 | 9% |
| 20-30% | 0 | 0% |
| 10-20% | 1 | 1% |
| 0-10% | 0 | 0% |
| Missing/skipped | 4 | -- |

Good bell-curve distribution centered around 60-70%.

### Backend Engineer Go — 200+ resumes scored (v2 = same prompt as v7)

| Score Range | Count (approx) | % |
|-------------|-------|---|
| 90-100% | 7 | 3.5% |
| 80-90% | 11 | 5.5% |
| 70-80% | 9 | 4.5% |
| 60-70% | 18 | 9% |
| 50-60% | 27 | 13.5% |
| 40-50% | 37 | 18.5% |
| 30-40% | 27 | 13.5% |
| 20-30% | 12 | 6% |
| 10-20% | 11 | 5.5% |
| 0-10% | 8 | 4% |

Right-skewed distribution — most candidates score 30-60%, reflecting the demanding PaaS/infrastructure criteria.

## Ground Truth Correlation

### Team Lead (20 benchmarked resumes)
- Eyeball 8-9 candidates: all score 85-97% ✓
- Eyeball 6-7 candidates: score 52-96% (wider range)
- Eyeball 2-4 candidates: mostly score 13-56% ✓
- Main inversions: inbox-15 (eyeball 3 at 66%), inbox-9 (eyeball 8 at 67%)

### Go Engineer (20 benchmarked resumes)
- "High" candidates: 28-82% (wide range due to niche criteria)
- "Above minimum": 38-81% 
- "Mid": 33-46% ✓
- "Low": 2.8-67% (go-18 overscored)
- Main issue: criteria are too niche (PaaS-specific) for general Go engineers

## Key Findings

### What works
1. Strong separation between top and bottom candidates
2. Reasoning consistently cites specific resume content
3. Works across domains without domain-specific rules
4. The v7 inference rule reduced worst-case overscoring without regressions

### Known limitations
1. Criteria-based scoring ≠ gestalt fit. Candidates can match all criteria without being ideal (or vice versa)
2. Sparse resumes underscore strong candidates (inbox-9, eyeball 8 at 67%)
3. Wrong-domain candidates with strong soft skills can overscore (inbox-15, exec assistant at 66%)
4. Nondeterministic variation of ~5-13 points on some resumes between runs

### Decisions for Jessica
1. The v7 prompt is as good as it can be without adding domain-specific rules
2. The remaining inversions are criteria design issues, not scoring prompt issues
3. Consider adding nondeterminism averaging (score 3x, take mean) for production use
4. Consider whether the Team Lead criteria are too heavily weighted toward soft skills
