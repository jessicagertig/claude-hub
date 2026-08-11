# v5 vs v7 Comparison — Team Lead (20 resumes)

## Prompt change (v7)
Added one rule: "If a criterion matches only because of what the role would typically involve — not because the resume describes doing it — score partial_match."

## Full Results

| # | Name | v5 | v7 | Eyeball | Delta | Notes |
|---|------|-----|-----|---------|-------|-------|
| 1 | Connor Galbraith | 85.1% | 86.2% | 7 | +1.1 | Stable |
| 2 | Yonatan Souid | 84.0% | 86.2% | 7 | +2.2 | Stable |
| 3 | Daniela Vasilev | 92.6% | 92.6% | 9 | 0 | Stable |
| 4 | Yann Baudic | 90.4% | 90.4% | 8 | 0 | Stable |
| 5 | Adrien Seret | 94.7% | 95.7% | 7 | +1.0 | Stable |
| 6 | Angel Bermudez | 92.6% | 89.4% | 6 | -3.2 | Minor drop |
| 7 | Revathi Ramachandran | 63.8% | 77.7% | 5 | +13.9 | Nondeterminism |
| 8 | Ravi Patron | 13.8% | 13.8% | 2 | 0 | Stable |
| 9 | Alexia Mboulé | 63.8% | 67.0% | 8 | +3.2 | Slight improvement |
| 10 | Daniel Nagy | 46.8% | 52.1% | 5 | +5.3 | Nondeterminism |
| 11 | Generoso Carmando | 92.6% | 94.7% | 9 | +2.1 | Stable |
| 12 | Iulia Tamini | 97.9% | 94.7% | 8 | -3.2 | Minor correction |
| 13 | Abhidipta Kaviraj | 96.8% | 96.8% | 9 | 0 | Stable ✓ |
| 14 | Chris Morosini | 100.0% | 96.8% | 8 | -3.2 | No longer 100% |
| 15 | Patricia Fix | 78.7% | 66.0% | 3 | -12.7 | TARGET HIT |
| 16 | Btissam Aissaoui | 30.9% | 31.9% | 4 | +1.0 | Stable |
| 17 | Guillaume Ledogard | 52.1% | 62.8% | 6 | +10.7 | Nondeterminism |
| 18 | Chaimaa Oummou | 48.9% | 43.6% | 6 | -5.3 | Nondeterminism |
| 19 | Carole Ratsimanohatra | 46.8% | 41.5% | 4 | -5.3 | Minor drop |
| 20 | Mohamed Ali Dhouib | 54.3% | 56.4% | 3 | +2.1 | Not fixed |

## v7 Ranking

| Rank | # | Name | v7 | Eyeball |
|------|---|------|-----|---------|
| 1 | 13 | Abhidipta Kaviraj | 96.8% | 9 |
| 2 | 14 | Chris Morosini | 96.8% | 8 |
| 3 | 5 | Adrien Seret | 95.7% | 7 |
| 4 | 11 | Generoso Carmando | 94.7% | 9 |
| 5 | 12 | Iulia Tamini | 94.7% | 8 |
| 6 | 3 | Daniela Vasilev | 92.6% | 9 |
| 7 | 4 | Yann Baudic | 90.4% | 8 |
| 8 | 6 | Angel Bermudez | 89.4% | 6 |
| 9 | 1 | Connor Galbraith | 86.2% | 7 |
| 10 | 2 | Yonatan Souid | 86.2% | 7 |
| 11 | 7 | Revathi Ramachandran | 77.7% | 5 |
| 12 | 9 | Alexia Mboulé | 67.0% | 8 |
| 13 | 15 | Patricia Fix | 66.0% | 3 |
| 14 | 17 | Guillaume Ledogard | 62.8% | 6 |
| 15 | 20 | Mohamed Ali Dhouib | 56.4% | 3 |
| 16 | 10 | Daniel Nagy | 52.1% | 5 |
| 17 | 18 | Chaimaa Oummou | 43.6% | 6 |
| 18 | 19 | Carole Ratsimanohatra | 41.5% | 4 |
| 19 | 16 | Btissam Aissaoui | 31.9% | 4 |
| 20 | 8 | Ravi Patron | 13.8% | 2 |

## Assessment

### Improvements from v7
1. Patricia Fix (eyeball 3): 78.7% → 66.0%. No longer ranks above most legitimate candidates.
2. Chris Morosini: 100% → 96.8%. More realistic.
3. Iulia Tamini: 97.9% → 94.7%. More realistic.
4. Strong candidates (inbox-3, 11, 13) remained stable.

### Remaining issues
1. inbox-15 (eyeball 3) at 66.0% still ranks above inbox-17 (eyeball 6, 62.8%). But this is a much smaller inversion than v5.
2. inbox-9 (eyeball 8) at 67.0% is still low for an eyeball 8 — sparse resume issue.
3. inbox-20 (eyeball 3) at 56.4% is still high — domain conflation not fully fixed.
4. Nondeterministic swings on inbox-7 (+13.9%) and inbox-17 (+10.7%) obscure the comparison.

### Verdict
v7 is better than v5. The rule reduces inference-based overscoring without regressing strong candidates. Keep the v7 prompt.
