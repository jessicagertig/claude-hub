# Phase 1 Summary — Team Lead v5 (20 resumes)

## Full Ranking

| Rank | # | Name | AI v5 | Eyeball | Delta |
|------|---|------|-------|---------|-------|
| 1 | 14 | Chris Morosini | 100.0% | 8 | |
| 2 | 12 | Iulia Tamini | 97.9% | 8 | |
| 3 | 13 | Abhidipta Kaviraj | 96.8% | 9 | |
| 4 | 5 | Adrien Seret | 94.7% | 7 | HIGH for 7 |
| 5 | 3 | Daniela Vasilev | 92.6% | 9 | |
| 5 | 6 | Angel Bermudez | 92.6% | 6 | HIGH for 6 |
| 5 | 11 | Generoso Carmando | 92.6% | 9 | |
| 8 | 4 | Yann Baudic | 90.4% | 8 | |
| 9 | 1 | Connor Galbraith | 85.1% | 7 | |
| 10 | 2 | Yonatan Souid | 84.0% | 7 | |
| 11 | 15 | Patricia Fix | 78.7% | 3 | **OVERSCORED** (-21 pts) |
| 12 | 7 | Revathi Ramachandran | 63.8% | 5 | |
| 12 | 9 | Alexia Mboulé | 63.8% | 8 | LOW for 8 |
| 14 | 20 | Mohamed Ali Dhouib | 54.3% | 3 | HIGH for 3 |
| 15 | 17 | Guillaume Ledogard | 52.1% | 6 | |
| 16 | 18 | Chaimaa Oummou | 48.9% | 6 | |
| 17 | 19 | Carole Ratsimanohatra | 46.8% | 4 | |
| 17 | 10 | Daniel Nagy | 46.8% | 5 | |
| 19 | 16 | Btissam Aissaoui | 30.9% | 4 | |
| 20 | 8 | Ravi Patron | 13.8% | 2 | |

## Overall Correlation

The scoring correctly separates strong candidates (eyeball 7-9) from weak ones (eyeball 2-4) in most cases. The top tier (85%+) contains all eyeball 7-9 candidates except inbox-9 (Alexia, 63.8%). The bottom tier (<55%) contains mostly eyeball 2-5 candidates.

### Notable rank inversions

1. **Patricia Fix (inbox-15)**: 78.7% vs eyeball 3. Executive assistant/office manager with no CS experience scored above Revathi (eyeball 5) and Alexia (eyeball 8). Corrected score: ~57.4%. 7 false positives from domain conflation (financial/admin work scored as CS work).

2. **Alexia Mboulé (inbox-9)**: 63.8% vs eyeball 8. Managed team of 14 CS agents but sparse resume. 2 false negatives found, corrected to ~68%. Still low for eyeball 8 — the gap is resume sparseness, not prompt issues.

3. **Mohamed Ali Dhouib (inbox-20)**: 54.3% vs eyeball 3. IT Project Manager scored moderately because soft skill criteria match. 2 errors found, corrected to ~49%. Moderate domain conflation.

4. **Adrien Seret (inbox-5)**: 94.7% vs eyeball 7. Evaluator confirmed all FMs evidence-backed. The high score reflects a genuinely criteria-rich resume despite lower eyeball.

5. **Angel Bermudez (inbox-6)**: 92.6% vs eyeball 6. Evaluator confirmed all FMs evidence-backed. Tech support + CS supervisor genuinely matches criteria.

## Error Patterns (400 criteria evaluations)

| Pattern | Count | Impact | Resumes |
|---------|-------|--------|---------|
| Virtual tools inference FM | 5/20 | 2-3 pts each | 2, 4, 14, 15, 20 |
| Domain conflation | 2/20 | 5-21 pts | 15, 20 |
| MS Office inference | 3/20 | 2-3 pts each | 12, 15, 16 |
| CS software vague FM | 2/20 | 2 pts each | 13 (reasoning), 18 |
| Conservative false negatives | 2/20 | 2-4 pts each | 1, 9 |
| Reasoning fabrication | 1/20 | 0 pts (score ok) | 13 |

## Decision: No prompt change for Phase 2

Accuracy: ~95.75% (17 errors across 400 evaluations)

The domain conflation is the most impactful issue but is concentrated on 2 extreme resumes (EA/office manager and IT project manager). Adding a rule risks overreach — it could penalize legitimate adjacent-domain candidates (tech support IS customer service). Moving to Phase 2 to test on a completely different job type before iterating.

The virtual tools pattern is consistent but low-impact (2-3 points per resume). The model inconsistency (correctly scoring PM on some resumes, incorrectly FM on others with identical evidence gaps) suggests nondeterminism more than a prompt gap.
