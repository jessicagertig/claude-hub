# AI Scoring — JD Extraction Summary

## What we built

A two-call pipeline that takes a job description and produces structured scoring criteria.

**Call 1** (gpt-4o-mini, ~$0.001/JD): Splits the JD into sections. Tags each as `criteria` or `non_criteria`. Company blurbs, benefits, EEO statements → non_criteria. Requirements, responsibilities, skills, nice-to-haves → criteria.

**Call 2** (gpt-4o, ~$0.01/JD): Takes the criteria sections and extracts individual requirements. Each gets:
- `text` — the atomic requirement
- `tier` — tier_1 (required/strong), tier_2 (standard/nice-to-have), tier_3 (bonus)
- `tier_reasoning` — why that tier (cites the signal word or "default — no signal word")
- `binary` — true/false (degree/license/vehicle = binary, skills/experience = spectrum)
- `source_text` — full original sentence from the JD

## How well it works

Tested on all 180 sample JDs. 886 total API calls. ~$2.55 total cost.

**What works reliably:**
- Section decomposition — near-perfect across 180 JDs
- Tier distribution — 20% T1, 77% T2, 2% T3 (healthy, not over-aggressive)
- Signal word recognition — "excellent", "strong", "proficiency", "minimum", "at least" consistently caught
- Non-English — German, Chinese, Norwegian, Spanish, Portuguese all work
- Minimal/general postings — correctly skipped (22 of 180)
- "Minimum Qualifications" / "Nice to Have" heading structure — correctly maps to T1/T2

**What's nondeterministic (varies between runs on same JD):**
- Binary flagging — sometimes catches a degree requirement, sometimes misses it. 40% of JDs produce consistent binary results across 5 runs; 30% vary.
- Text preservation — model sometimes rephrases criterion text instead of preserving source verbatim. 63% preservation rate.
- Compound decomposition — "5+ years including frontend and backend" sometimes splits into 3 criteria, sometimes stays as 1.
- JDs with all-Required headings — model oscillates on whether heading or inline signal wins.

**What it can't do:**
- "proven" signal word — gpt-4o-mini never catches it. gpt-4o catches it ~50% of the time.
- Guarantee identical results on re-run — inherent model limitation.

## Files

- **Prompts**: `app/services/ai_job_application_action/scoring/prompts/` (2 files)
- **Decisions**: `docs/jd-extraction-decisions.md` (20 decisions we made together)
- **Full report**: `docs/benchmark/FINAL-REPORT.md`
- **Regression test set**: `docs/benchmark/regression-set/` (20 JDs — 5 standard + 15 problematic)
- **Rake tasks**: `lib/tasks/ai_scoring.rake`, `ai_scoring_batch.rake`, `ai_scoring_regression.rake`

## Cost in production

Per JD: ~$0.011 (Call 1 mini + Call 2 4o)
1,000 JDs/month: ~$11/month

## Decisions to revisit

1. **Decision 9** (AI detects JD's own tier structure) — flagged for A/B testing. May cause more harm than good on structured JDs.
2. **Binary flag** — nondeterministic. Options: accept noise, run 3x and majority-vote (+$0.02/JD), or make it advisory-only.
3. **gpt-4o vs gpt-4o-mini** for Call 2 — we chose gpt-4o (2x more stable, uses T3 properly). Cost is 10x but still <$0.01/JD.

## Next step

Build Call 3: take the extracted criteria + a candidate's resume → score each criterion as matched/partial/missing. That's the actual scoring.
