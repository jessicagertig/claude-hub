# Overnight Scoring Session — Final Report

## Summary

**Prompt version**: v7 (3 rules: inference guard, multilingual, domain years)
**Model**: gemini-3.1-flash-lite
**Total resumes scored**: 800 (82 Team Lead + 502 Go Engineer + 216 Data Analyst)
**Prompt iterations**: v5 → v6 (reverted) → v7 (kept)
**Ground truth accuracy**: ~95% at criterion level (400 criteria audited)
**Third domain test**: Data Analyst - Growth (28 criteria) scored with zero domain-specific modifications

## Prompt (v7)

See full snapshot: `prompt-v7-snapshot.md`

3 rules added to the base "score each criterion" prompt:
1. **Inference guard**: "If a criterion matches only because of what the role would typically involve — not because the resume describes doing it — score partial_match."
2. **Multilingual rule**: Being multilingual ≠ communication skills
3. **Domain years**: FM = domain experience, PM = adjacent domain with significant related duties

## Scoring Results

### Team Lead, Customer Support (82 resumes)

```
Mean: 71.9% | Median: 77.7% | Range: 13.8–100.0% | StdDev: 20.5pp

 90-100%:  18 ##################
  80-90%:  17 #################
  70-80%:  16 ################
  60-70%:   7 #######
  50-60%:   6 ######
  40-50%:  13 #############
  30-40%:   4 ####
  10-20%:   1 #
```

### Backend Engineer Go (502 resumes)

```
Mean: 48.6% | Median: 47.2% | Range: 0.0–100.0% | StdDev: 20.7pp

 90-100%:  13
  80-90%:  38
  70-80%:  33
  60-70%:  45
  50-60%:  90
  40-50%: 111
  30-40%:  87
  20-30%:  40
  10-20%:  34
   0-10%:  11
```

## Nondeterminism

Tested 9 resumes across 3 runs each:

| Resume Type | Variance Range | Assessment |
|-------------|---------------|------------|
| Strong, evidence-rich | 0–3pp | Very stable |
| Mid-range | 6–8pp | Moderate |
| Borderline criteria | 12–18pp | High variance |
| Weak candidates | 3–7pp | Stable (always low) |

Recommendation: for production, average 3 runs per candidate to reduce worst-case variance from ~18pp to ~10pp.

## Key Findings

### What works
1. Strong separation between top/bottom candidates in both jobs
2. Reasoning cites specific resume content (95%+ of criteria)
3. Domain-agnostic — same prompt works for CS leadership, Go engineering, AND Data Analyst (3 domains tested)
4. v7 inference guard reduces worst-case overscoring without regressions
5. Spot-checks confirmed 100% scores are justified when the candidate genuinely matches

### Known limitations
1. **Criteria ≠ gestalt fit**. Candidates can match all criteria without being ideal (exec assistant matching CS soft skills) or vice versa (strong candidate with sparse resume)
2. **Niche criteria limit score ceiling**. Go Engineer criteria are so PaaS-specific that most strong Go engineers score 40-60%
3. **Nondeterminism on borderline criteria**. go-4 (OpenShift as K8s) swings 18pp between runs
4. **Wrong-domain overscoring**. Patricia Fix (exec assistant) still scores 66% due to transferable soft skills

### Decisions for Jessica
1. v7 prompt is production-ready for the current design
2. Remaining inversions are criteria design issues, not prompt issues
3. Consider multi-run averaging for production scoring
4. Team Lead criteria may need more domain-specific requirements (less soft skills) to reduce wrong-domain overlap
5. Go Engineer criteria are appropriately demanding — the low mean (48.6%) reflects the niche requirements correctly

## Files Generated

### Scoring results
- `inbox-{1-86}-scores-v7.json` — Team Lead (some gaps)
- `go-{1-503}-scores-v2.json` — Go Engineer (some gaps)
- `da-{1-218}-scores-v1.json` — Data Analyst (216 scored)

### Evaluation reports
- `batch{1-4}-v5-evaluation.md` — Criterion-level audits (Team Lead)
- `go-batch1-v1-evaluation.md` — Criterion-level audit (Go batch 1)
- `go-suspicious-v1-evaluation.md` — Suspicious candidates deep-dive

### Analysis
- `phase1-v5-summary.md` — Team Lead 20-resume analysis
- `phase2-go-summary.md` — Go Engineer 20-resume analysis
- `v5-vs-v7-comparison.md` — Prompt regression comparison
- `nondeterminism-v7.md` — Nondeterminism test results
- `prompt-v7-snapshot.md` — Current prompt text

### Resumes
- `inbox-{1-86}.txt` — Team Lead resumes (4 gaps)
- `go-{1-503}.txt` — Go Engineer resumes (some gaps)

## Prompt change log

| Version | Change | Tested on | Result |
|---------|--------|-----------|--------|
| v5 | Minimal + multilingual + domain years | 20 TL, 20 Go | 95.75% accuracy |
| v6 | + "Do not infer from job titles/company types" | 5 TL | Regressed inbox-13 by 12.8pp — REVERTED |
| v7 | + "If criterion matches only because of role would typically involve..." | 20 TL, 20 Go, 584 at scale | No regressions, inbox-15 fixed (78.7%→66.0%) |
