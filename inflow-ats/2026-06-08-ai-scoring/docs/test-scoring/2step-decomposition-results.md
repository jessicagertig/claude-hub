# Two-Step Decomposition Results

Call 1: gpt-4.1-mini
Call 2: gemini-3.1-flash-lite
Call 2b judge: gemini-3.1-flash-lite (decides keep/decompose)
Call 2b decomposer: gpt-4.1-mini (does the actual splitting)
Call 4: gemini-3.1-flash-lite (scoring)

Using Run 2 criteria (33 criteria after decomposition, from original 20).

## Go Engineer — High, Mid, Low (v7 scores)

| Rank | # | Candidate | v7 Score | Expected |
|------|---|-----------|----------|----------|
| 1 | 2 | R Narendran | 77.4% | High |
| 2 | 4 | Ganesh Pawar | 57.7% | High |
| 3 | 3 | Kushagra Shukla | 54.3% | High |
| 4 | 18 | William H. Morris | 50.0% | Low |
| 5 | 1 | Abhishek | 49.5% | High |
| 6 | 17 | Matheus Caetano | 48.6% | Mid |
| 7 | 19 | Anna Verkhogliadova | 48.1% | Mid |
| 8 | 20 | Mayank Mohan | 46.2% | Mid |
| 9 | 5 | Nishant | 41.3% | High |
| 10 | 14 | Ohm Patel | 40.4% | Low |
| 11 | 15 | Alan Niemiec | 39.4% | Mid |
| 12 | 16 | Barruri Sai Suhas Sharma | 7.7% | Low |

## William Morris progression across versions

| Version | Score | What changed |
|---------|-------|-------------|
| v2 (original extraction) | 66.7% | 17 criteria, no decomposition |
| v3 (fixed Call 1 headings) | 67.0% | 20 criteria, soft skills at tier_2 |
| v5 (title tech triple weight) | 51.8% | Triple weight on Go criteria |
| v7 (2-step decomposition) | 50.0% | 33 criteria after decomposition |

## Team Lead — 5 Benchmarks (v9 scores)

| # | Candidate | Eyeball | v9 Score |
|---|-----------|---------|----------|
| 3 | Daniela Vasilev | 9 | 75.5% |
| 13 | Abhidipta Kaviraj | 9 | 77.7% |
| 9 | Alexia Mboulé | 8 | 72.3% |
| 8 | Ravi Patron | 2 | 20.2% |
| 17 | Guillaume Ledogard | 6 | 56.4% |

## Two-step pipeline consistency (5 runs)

| Run | Gemini flagged | Final criteria |
|-----|---------------|----------------|
| 1 | 9 | 37 |
| 2 | 5 | 33 |
| 3 | 8 | 47 |
| 4 | 10 | 40 |
| 5 | 5 | 39 |

Gemini judge is moderately consistent (5-10 flagged). gpt-4.1-mini decomposer is the main source of variance (33-47 final criteria).
