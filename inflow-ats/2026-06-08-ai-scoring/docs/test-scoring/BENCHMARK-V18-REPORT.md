# Benchmark v18 — Full Pipeline Results

## Pipeline Configuration

- **Call 1** (gpt-4.1-mini, temp 0): Section decomposition
- **Call 2** (gemini-3.1-flash-lite, default temp): Criteria extraction + source_heading
- **Code**: Heading tier override (required/must/essential/minimum → T1, bonus/optional → T3, soft skills excluded)
- **Judge** (gpt-4o-mini, temp 0): Which criteria to decompose (max 4, source_text stripped)
- **Decomposer** (gpt-4.1-mini, temp 0): Decompose flagged criteria (max 3 parts)
- **Scorer** (gpt-4o-mini, temp 0): Score candidates

## Extraction Stability

### Go Engineer (10 runs)

| Run | Raw (Call 2) | Final | T1 | T2 | Decomposed | Heading Overrides |
|-----|-------------|-------|----|----|------------|-------------------|
| 1 | 20 | 28 | 8 | 20 | 4 | 2 |
| 2 | 20 | 24 | 8 | 16 | 4 | 2 |
| 3 | 20 | 28 | 10 | 18 | 4 | 6 |
| 4 | 20 | 27 | 8 | 19 | 4 | 5 |
| 5 | 20 | 29 | 10 | 19 | 4 | 2 |
| 6 | 18 | 25 | 8 | 17 | 4 | 4 |
| 7 | 20 | 23 | 8 | 15 | 3 | 2 |
| 8 | 20 | 26 | 8 | 18 | 4 | 2 |
| 9 | 20 | 27 | 8 | 19 | 4 | 5 |
| 10 | 20 | 24 | 8 | 16 | 3 | 6 |

- Call 2 raw: **18-20** (stable)
- Final: **23-29** (variance from decomposition part counts)
- T1: **8-10** (mostly 8)
- Judge flags 3-4 criteria per run

### Team Lead (10 runs)

| Run | Raw (Call 2) | Final | T1 | T2 | Decomposed | Heading Overrides |
|-----|-------------|-------|----|----|------------|-------------------|
| 1 | 24 | 25 | 11 | 14 | 1 | — |
| 2 | 23 | 24 | 11 | 13 | 1 | — |
| 3 | 20 | 21 | 11 | 10 | 1 | — |
| 4 | 20 | 22 | 10 | 12 | 1 | — |
| 5 | 20 | 22 | 10 | 12 | 1 | — |
| 6 | 24 | 25 | 11 | 14 | 1 | — |
| 7 | 24 | 25 | 11 | 14 | 1 | — |
| 8 | 23 | 24 | 11 | 13 | 1 | — |
| 9 | 24 | 26 | 10 | 16 | 1 | — |
| 10 | 24 | 25 | 11 | 14 | 1 | — |

- Call 2 raw: **20-24**
- Final: **21-26**
- T1: **10-11** (very stable)
- Only 1 decomposition per run

## Scoring Results

### Go Engineer (run 10 criteria: 24 criteria, T1:8)

Ranked by v18 score:

| # | Candidate | v18 | v7 | Delta | Expected (Jessica) | Eyeball (AI) |
|---|-----------|-----|-----|-------|-------------------|--------------|
| 2 | Narendran | 59.1% | 81.9% | -22.8 | High | High (70-80%) |
| 1 | Abhishek | 56.1% | 37.5% | +18.6 | High | Low (20-35%) |
| 8 | Amrish | 55.5% | 48.6% | +6.9 | Above min | Mid (45-55%) |
| 12 | Miguel | 55.5% | 56.9% | -1.4 | Above min | High (75-85%) |
| 10 | Michael | 53.7% | 51.4% | +2.3 | Above min | Mid (45-55%) |
| 11 | Abdulrahman | 53.0% | 80.6% | -27.6 | Above min | High (70-80%) |
| 6 | Deepak | 51.8% | 56.9% | -5.1 | Mid-high+ | Mid (45-60%) |
| 4 | Ganesh | 50.0% | 75.0% | -25.0 | High | High (70-80%) |
| 15 | Alan | 47.0% | 33.3% | +13.7 | Mid | Above min (30-40%) |
| 14 | Ohm | 46.3% | 41.7% | +4.6 | Low | Mid (40-55%) |
| 18 | Morris | 45.1% | 66.7% | -21.6 | Low | Low (15-25%) |
| 20 | Mayank | 43.3% | 41.7% | +1.6 | Mid | Mid (40-50%) |
| 3 | Kushagra | 42.7% | 51.4% | -8.7 | High | Mid (45-55%) |
| 17 | Matheus | 41.5% | 45.8% | -4.3 | Mid | Mid (50-60%) |
| 7 | Julian | 37.2% | 38.9% | -1.7 | Above min | Mid (40-50%) |
| 9 | Furkan | 36.6% | 40.3% | -3.7 | Above min | Mid (40-50%) |
| 19 | Anna | 30.5% | 40.3% | -9.8 | Mid | Above min (30-45%) |
| 5 | Nishant | 29.3% | 27.8% | +1.5 | High | Low (25-35%) |
| 13 | Milan | 28.7% | 30.6% | +2.3 | Above min | Low (20-30%) |
| 16 | Barruri | 9.1% | 2.8% | +6.3 | Low | Low (5-10%) |

### Team Lead (run 10 criteria: 25 criteria, T1:11)

Ranked by v18 score:

| # | Candidate | v18 | Eyeball (Jessica) |
|---|-----------|-----|-------------------|
| 3 | Daniela | 82.0% | 9/10 |
| 13 | Abhidipta | 82.0% | 9/10 |
| 1 | Connor | 74.6% | — |
| 14 | Chris | 73.8% | — |
| 5 | Adrien | 72.1% | — |
| 4 | Yann | 69.7% | — |
| 6 | Angel | 67.2% | — |
| 2 | Yonatan | 64.8% | — |
| 11 | Generoso | 64.8% | — |
| 12 | Iulia | 64.8% | — |
| 7 | Revathi | 55.7% | — |
| 15 | Patricia | 43.4% | — |
| 9 | Alexia | 41.8% | 8/10 |
| 17 | Guillaume | 36.9% | 6/10 |
| 19 | Carole | 34.4% | — |
| 10 | Daniel | 28.7% | — |
| 20 | Mohamed | 27.9% | — |
| 18 | Chaimaa | 26.2% | — |
| 8 | Ravi | 2.5% | 2/10 |
| 16 | Aissaoui | 0.0% | — |

## Data Locations

All records saved with full scoring details (FM/PM/NF per criterion with reasoning):

- **Go runs**: `benchmark-v18/go/run1.json` through `run10.json`
- **Go scores**: `benchmark-v18/go/score-go-1.json` through `score-go-20.json`
- **Team Lead runs**: `benchmark-v18/teamlead/run1.json` through `run10.json`
- **Team Lead scores**: `benchmark-v18/teamlead/score-inbox-1.json` through `score-inbox-20.json`
- **Stability summaries**: `benchmark-v18/go/stability-summary.json` and `benchmark-v18/teamlead/stability-summary.json`
- **Eyeball scores**: `eyeball-scores-go-combined.md`

## Other Deliverables

- **Integration proposal**: `INTEGRATION-PROPOSAL.md` — how scoring integrates with AI summaries
- **Criteria display design**: `CRITERIA-DISPLAY-DESIGN.md` — user-facing checkmark/neutral/X display concept
- **Scoring model comparison**: `SCORING-MODEL-COMPARISON.md` — gpt-4.1-mini vs gpt-4o-mini analysis
