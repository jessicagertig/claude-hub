# What's Next — Post-Overnight Session

## Where things stand

The scoring pipeline is validated and production-ready:
- **865 unique resumes** scored across 3 job types
- **v7 prompt** is stable with 3 minimal rules
- **ρ = 0.826** rank correlation against human judgments (Team Lead)
- **Domain-agnostic** — same prompt works on CS leadership, Go engineering, Data Analyst

## Immediate next steps

### 1. Review results (morning)
- Rankings saved at `teamlead-v7-rankings.txt`, `go-v2-rankings.txt`, `da-v1-rankings.txt`
- The overnight report is at `overnight-final-report.md`
- Criteria effectiveness analysis at `criteria-effectiveness-analysis.md`
- Compare top/bottom candidates against your knowledge of who was hired

### 2. Integration design
The scoring pipeline works. Now decide how to integrate it:
- **Where in the workflow?** Auto-score on application receipt? On demand?
- **What to show?** Overall percentage? Tier (A/B/C/D)? Per-criterion breakdown?
- **Threshold tuning** — the relative tier boundaries should be set per-job based on the score distribution

### 3. Known issues to address

**Textract quality affects scoring stability.** da-10 showed 27pp nondeterminism due to poorly extracted multi-column PDF. Consider:
- Pre-filtering: skip resumes with very short or garbled textract text
- Quality scoring: flag resumes where textract confidence is low

**Wrong-domain overscoring on soft skills.** Patricia Fix (exec assistant) scores 66% on a CS leadership role because generic criteria (communication, multitasking) give free points. Options:
- Use relative thresholds per job (top 20% = Tier A) instead of absolute cutoffs
- Weight criteria by discrimination value
- Accept this as a limitation — wrong-domain candidates will always partially match generic criteria

**Niche criteria create floor effects.** Go's "cloud marketplace" criterion (97% NF) contributes nothing to ranking. Options:
- Accept it — the criteria reflect real job requirements even if most candidates lack them
- Tier criteria by discrimination: required vs differentiating vs aspirational

### 4. Future prompt work

The prompt is as good as it can be without becoming domain-specific. Remaining improvement paths:
- **Multi-run averaging** for production (3 runs, mean score) — reduces worst-case variance from 18pp to ~10pp
- **Criterion-level stability** — identify which criteria flip most and investigate why
- **Resume quality signal** — add a "resume clarity" score to flag low-quality textract results

### 5. Expand to more jobs

The pipeline generalizes. To score a new job:
1. Run Call 1 (section decomposition) on the JD
2. Run Call 2 (criteria extraction) on the sections
3. Add the job key to the rake task
4. Pull resumes via `rails runner`
5. Score in batches

The Data Analyst test proved this works in ~5 minutes per new job setup.

## What NOT to do

- Don't add more rules to the prompt — fewer rules = better results
- Don't try to fix the Go correlation with prompt changes — it's a criteria issue
- Don't treat the scores as absolute — they're relative within a job's candidate pool
- Don't expect 100% correlation with human judgment — criteria-based scoring measures different things than gestalt fit
