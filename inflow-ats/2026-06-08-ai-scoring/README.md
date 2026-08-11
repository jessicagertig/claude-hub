# AI Scoring — JD Criteria Extraction

Two-call pipeline for extracting structured scoring criteria from job descriptions.

## Quick Start

Read `docs/SUMMARY-FOR-JESSICA.md` for the 5-minute overview.

## Source Code

All in `/Users/jessica/wrk/wrk-corp/inflow-ats/`:

```
app/services/ai_job_application_action/scoring/
  prompts/
    job_description_structured_data.rb   # Call 1 — section decomposition (gpt-4o-mini)
    job_description_criteria_extraction.rb  # Call 2 — criteria extraction (gpt-4o)
app/services/ai_client.rb               # Added gpt-4o pricing

lib/tasks/
  ai_scoring.rake          # Benchmark Call 1 and Call 2 individually
  ai_scoring_batch.rake    # Run Call 1 + Call 2 on batches of JDs
  ai_scoring_regression.rake  # Run on 20-JD regression set
```

## Design Decisions

`docs/jd-extraction-decisions.md` — 20 decisions made during the design session

## Data & Analysis

```
docs/
  job_descriptions.json          # 180 sample JDs from production
  jd-headings-and-qualifiers.md  # Raw inventory of all headings and inline signals
  jd-extraction-analysis.md      # Data-driven findings from the 180 JDs

  benchmark/
    FINAL-REPORT.md              # Comprehensive benchmark report
    gpt4o-definitive-180.md      # Definitive gpt-4o stats on all 180 JDs
    gpt4o-nondeterminism-5run.md # 5-run stability analysis
    model-comparison.md          # gpt-4o-mini vs gpt-4o
    volatile-jd-analysis.md      # Root cause analysis of unstable JDs
    spot-check-quality.md        # Manual quality review
    regression-set/              # 20 JDs for regression testing (5 standard + 15 problematic)
    batch-1-results/ ... batch-35-results/  # Full 180-JD results
```

## Rake Task Usage

```bash
# Run Call 1 + Call 2 on a batch
rake ai:scoring:batch BATCH=1

# Run on the 20-JD regression set
rake ai:scoring:regression VERSION=1

# Benchmark Call 1 only
rake ai:scoring:benchmark VERSION=1

# Benchmark Call 2 only (uses Call 1 v5 output)
rake ai:scoring:benchmark_criteria VERSION=1
```
