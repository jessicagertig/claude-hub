# Scoring Pipeline — Cost Estimate

## Per Job (runs once when job is published)

| Step | Model | Cost |
|------|-------|------|
| Call 1 — Section decomposition | gpt-4.1-mini | ~$0.003 |
| Call 2 — Criteria extraction | gpt-4o | ~$0.035 |
| Code — Heading tier override | n/a | $0 |
| **Per job total** | | **~$0.04** |

**250 published jobs/month × $0.04 = $10/month**

## Per Candidate (runs once per candidate per job)

| Step | Model | 1 scoring call | 5-run median |
|------|-------|---------------|-------------|
| Call 4 — Scoring | Gemini flash | $0.0004 | $0.002 |
| Call 5 — Display sentences | Gemini flash | $0.0004 | $0.0004 |
| **Per candidate total** | | **$0.0008** | **$0.0024** |

### Actual candidate volume (job applications with resume)

| Month | Applications | 1-call scoring | 5-run median |
|-------|-------------|---------------|-------------|
| 2025-04 | 42,562 | $34.05 | $102.15 |
| 2025-05 | 19,907 | $15.93 | $47.78 |
| 2025-06 | 21,147 | $16.92 | $50.75 |
| 2025-07 | 17,573 | $14.06 | $42.18 |
| 2025-08 | 23,489 | $18.79 | $56.37 |
| 2025-09 | 25,781 | $20.62 | $61.87 |
| 2025-10 | 25,272 | $20.22 | $60.65 |
| 2025-11 | 20,834 | $16.67 | $50.00 |
| 2025-12 | 17,123 | $13.70 | $41.10 |
| 2026-01 | 21,681 | $17.34 | $52.03 |
| 2026-02 | 19,191 | $15.35 | $46.06 |
| 2026-03 | 41,898 | $33.52 | $100.56 |
| 2026-04 | 40,195 | $32.16 | $96.47 |
| 2026-05 | 51,239 | $40.99 | $122.97 |

**Recent average (~25k/month):** $20-30 (1-call) or $60-80 (5-run median)
**Peak months (~50k):** $41 (1-call) or $123 (5-run median)

## Monthly Total Estimates (jobs + candidates)

| Scenario | Jobs cost | Candidate cost (1-call) | Candidate cost (5-run) | Total (1-call) | Total (5-run) |
|----------|----------|----------------------|---------------------|---------------|--------------|
| Typical (25k) | $10 | $20 | $60 | $30 | $70 |
| Peak (50k) | $10 | $41 | $123 | $51 | $133 |

## Existing AI Summary Pipeline (per candidate, gpt-4o-mini)

| Call | What it does | Avg cost |
|------|-------------|----------|
| Extraction | Resume → structured data (name, work history, education, skills) | $0.0005 |
| Assessment | Identifies domains, career narrative, key skills, accomplishments | $0.0004 |
| Comparison | Compares candidate to job title → applicable experience, gaps | $0.0002 |
| Summary | Generates headline, summary text, role analysis | $0.0003 |
| **Summary total** | | **$0.002** (high estimate, actual range $0.0008-$0.0019) |

Based on 124 actual summaries generated in last 30 days. Cost column in AiApiRequest stores $0.0 due to model name mismatch (API returns "gpt-4o-mini-2024-07-18", pricing hash has "gpt-4o-mini"). Bug to fix.

## Combined Cost Per Candidate (Summary + Scoring)

| Step | Model | Cost |
|------|-------|------|
| Summary (4 calls) | gpt-4o-mini | $0.002 |
| Scoring (1 call) | Gemini flash | $0.0004 |
| Scoring (5-run median) | Gemini flash × 5 | $0.002 |
| Display sentences | Gemini flash | $0.0004 |
| **Total (1-call scoring)** | | **$0.003** |
| **Total (5-run median)** | | **$0.005** |

## Monthly Totals (jobs + candidates, all-in, high estimates)

| Scenario | Jobs ($0.04 × 250) | Candidates (summary + scoring) | Total |
|----------|-------------------|-------------------------------|-------|
| Typical 25k, 1-call | $10 | $75 | $85 |
| Typical 25k, 5-run | $10 | $125 | $135 |
| Peak 50k, 1-call | $10 | $150 | $160 |
| Peak 50k, 5-run | $10 | $250 | $260 |

## Textract Cost (runs for all applicants with resumes)

$1.50 per 1,000 pages = $0.0015/page. Assuming 2 pages per resume = **$0.003 per resume**.

## Actual Monthly Volume (job applications with resume)

| Month | Applications | Textract ($0.003) | Summary+Scoring 1-call ($0.003) | Summary+Scoring 5-run ($0.005) |
|-------|-------------|-------------------|-------------------------------|-------------------------------|
| 2025-04 | 42,562 | $127.69 | $127.69 | $212.81 |
| 2025-05 | 19,907 | $59.72 | $59.72 | $99.54 |
| 2025-06 | 21,147 | $63.44 | $63.44 | $105.74 |
| 2025-07 | 17,573 | $52.72 | $52.72 | $87.87 |
| 2025-08 | 23,489 | $70.47 | $70.47 | $117.45 |
| 2025-09 | 25,781 | $77.34 | $77.34 | $128.91 |
| 2025-10 | 25,272 | $75.82 | $75.82 | $126.36 |
| 2025-11 | 20,834 | $62.50 | $62.50 | $104.17 |
| 2025-12 | 17,123 | $51.37 | $51.37 | $85.62 |
| 2026-01 | 21,681 | $65.04 | $65.04 | $108.41 |
| 2026-02 | 19,191 | $57.57 | $57.57 | $95.96 |
| 2026-03 | 41,898 | $125.69 | $125.69 | $209.49 |
| 2026-04 | 40,195 | $120.59 | $120.59 | $200.98 |
| 2026-05 | 51,239 | $153.72 | $153.72 | $256.20 |

## All-In Monthly Cost (Textract + Jobs + Summary + Scoring)

| Scenario | Textract | Jobs | Summary+Scoring | Total |
|----------|---------|------|----------------|-------|
| Typical 25k, 1-call | $75 | $10 | $75 | $160 |
| Typical 25k, 5-run | $75 | $10 | $125 | $210 |
| Peak 50k, 1-call | $150 | $10 | $150 | $310 |
| Peak 50k, 5-run | $150 | $10 | $250 | $410 |

Textract is roughly equal to the AI pipeline cost. The AI scoring adds $50-100/month on top of existing summary costs.

## Notes

- Partial match weight: 0.7
- Scoring model: Gemini 3.1 flash lite (no temperature override)
- Criteria extraction: gpt-4o with temperature 0
- Section decomposition: gpt-4.1-mini with temperature 0
- No decomposition judge or decomposer calls (dropped)
- Heading tier override handled in code
- Display sentences generated once per candidate (not per scoring run)
- 5-run median adds ~10 seconds per candidate (sequential) or ~5 seconds (parallel)
- These costs do NOT include the existing AI summary pipeline costs (separate)
