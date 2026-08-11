# Scoring Comparison: v3 (no expansions) vs scoring-v1 (expansion v5)

| # | Name | Eye | v3 | sv1 | Delta | Assessment |
|---|------|-----|-----|-----|-------|------------|
| 1 | Connor — CS Supervisor | 7 | 86.2% | 86.2% | 0 | unchanged |
| 2 | Yonatan — Head of CS | 7 | 81.9% | 86.2% | +4.3 | better (was under) |
| 3 | Daniela — Booking.com TL | 9 | 92.6% | 92.6% | 0 | unchanged |
| 4 | Yann — Tech Support Dir | 8 | 88.3% | 90.4% | +2.1 | better |
| 5 | Adrien — CS Manager | 7 | 94.7% | 94.7% | 0 | unchanged (high for eye=7) |
| 6 | Angel — Shopify CS | 6 | 94.7% | 94.7% | 0 | unchanged (high for eye=6) |
| 7 | Revathi — Payment Lead | 5 | 77.7% | 80.9% | +3.2 | worse (was already high) |
| 8 | Ravi — Sales/Bartender | 2 | 22.3% | 30.9% | +8.6 | worse (should be low) |
| 9 | Alexia — CX PM, 14 agents | 8 | 62.8% | 58.5% | -4.3 | worse (was already under) |
| 10 | Daniel — Disney+ Rep | 5 | 59.6% | 51.1% | -8.5 | maybe better (was high for eye=5) |
| 11 | Generoso — CS Team Leader | 9 | 94.7% | 92.6% | -2.1 | negligible |
| 12 | Iulia — Call Center GM | 8 | 94.7% | 94.7% | 0 | unchanged |
| 13 | Abhidipta — CS Team Mgr | 9 | 92.6% | 96.8% | +4.2 | better |
| 14 | Chris — CX Team Leader | 8 | 100.0% | 97.9% | -2.1 | negligible |
| 15 | Patricia — Exec Asst | 3 | 68.1% | 68.1% | 0 | unchanged (still too high) |
| 16 | Btissam — Client Support | 4 | 35.1% | 24.5% | -10.6 | GOOD — fixed false positives |
| 17 | Guillaume — CS Rep/HR | 6 | 58.5% | 58.5% | 0 | unchanged |
| 18 | Chaimaa — Customer Care | 6 | 48.9% | 45.7% | -3.2 | neutral |
| 19 | Carole — Digital CS Rep | 4 | 55.3% | 48.9% | -6.4 | better (was too high) |
| 20 | Mohamed — IT PM | 3 | 54.3% | 66.0% | +11.7 | WORSE — inflated further |

## Key observations

**Improved:**
- #16 Btissam: -10.6% — v3 review flagged 4 false positives. Expansions helped model discriminate.
- #19 Carole: -6.4% — was scoring too high for eye=4. Moving in right direction.
- #13 Abhidipta: +4.2% — was slightly under for eye=9. Now 96.8%.

**Worsened:**
- #20 Mohamed: +11.7% — eye=3 but scoring 66%. WAY too generous. IT PM, not CS.
- #8 Ravi: +8.6% — eye=2 but scoring 30.9%. Still low-ish but moved wrong direction.
- #9 Alexia: -4.3% — eye=8 but scoring 58.5%. Already too low, got worse.
- #10 Daniel: -8.5% — could be more accurate (eye=5, 51.1% now vs 59.6%).

**Persistent problems (pre-existing):**
- #5 Adrien: eye=7, scoring 94.7% — way too high
- #6 Angel: eye=6, scoring 94.7% — way too high
- #7 Revathi: eye=5, scoring 80.9% — too high
- #15 Patricia: eye=3, scoring 68.1% — way too high
