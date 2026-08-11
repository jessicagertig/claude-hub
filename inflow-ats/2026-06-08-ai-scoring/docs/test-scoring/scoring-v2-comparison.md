# Scoring Comparison: v3 vs sv1 (exp-v5) vs sv2 (exp-v6)

v3 = no expansions | sv1 = expansion v5 (broad) | sv2 = expansion v6 (no cross-domain)

| # | Name | Eye | v3 | sv1 | sv2 | sv2 vs v3 | Assessment |
|---|------|-----|-----|-----|-----|-----------|------------|
| 1 | Connor — CS Supervisor | 7 | 86.2% | 86.2% | 86.2% | 0 | stable |
| 2 | Yonatan — Head of CS | 7 | 81.9% | 86.2% | 86.2% | +4.3 | improved |
| 3 | Daniela — Booking.com TL | 9 | 92.6% | 92.6% | 92.6% | 0 | stable |
| 4 | Yann — Tech Support Dir | 8 | 88.3% | 90.4% | 90.4% | +2.1 | improved |
| 5 | Adrien — CS Manager | 7 | 94.7% | 94.7% | 97.9% | +3.2 | WORSE (persistent inflation) |
| 6 | Angel — Shopify CS | 6 | 94.7% | 94.7% | 91.5% | -3.2 | slightly better |
| 7 | Revathi — Payment Lead | 5 | 77.7% | 80.9% | 74.5% | -3.2 | better |
| 8 | Ravi — Sales/Bartender | 2 | 22.3% | 30.9% | 12.8% | -9.5 | MUCH BETTER — fixed sv1 regression |
| 9 | Alexia — CX PM | 8 | 62.8% | 58.5% | 64.9% | +2.1 | better — fixed sv1 regression |
| 10 | Daniel — Disney+ Rep | 5 | 59.6% | 51.1% | 50.0% | -9.6 | lower (eye=5, could be more accurate) |
| 11 | Generoso — CS Team Leader | 9 | 94.7% | 92.6% | 93.6% | -1.1 | negligible |
| 12 | Iulia — Call Center GM | 8 | 94.7% | 94.7% | 96.8% | +2.1 | stable |
| 13 | Abhidipta — CS Team Mgr | 9 | 92.6% | 96.8% | 92.6% | 0 | back to v3 level |
| 14 | Chris — CX Team Leader | 8 | 100.0% | 97.9% | 95.7% | -4.3 | slightly lower |
| 15 | Patricia — Exec Asst | 3 | 68.1% | 68.1% | 71.3% | +3.2 | WORSE (persistent inflation) |
| 16 | Btissam — Client Support | 4 | 35.1% | 24.5% | 21.3% | -13.8 | BEST RESULT — false positives fixed |
| 17 | Guillaume — CS Rep/HR | 6 | 58.5% | 58.5% | 59.6% | +1.1 | stable |
| 18 | Chaimaa — Customer Care | 6 | 48.9% | 45.7% | 48.9% | 0 | stable |
| 19 | Carole — Digital CS Rep | 4 | 55.3% | 48.9% | 46.8% | -8.5 | better |
| 20 | Mohamed — IT PM | 3 | 54.3% | 66.0% | 77.7% | +23.4 | MUCH WORSE — needs investigation |

## Summary

### Fixed by exp-v6 (vs sv1 with exp-v5):
- **Ravi** (#8): 30.9% → 12.8% — cross-domain inflation eliminated
- **Alexia** (#9): 58.5% → 64.9% — no longer penalized by high-bar examples
- **Btissam** (#16): 24.5% → 21.3% — false positives further reduced

### Worsened:
- **Mohamed** (#20): 66.0% → 77.7% — ANOMALOUS. May be nondeterminism (23% swing is huge). Needs investigation.

### Persistent (not expansion-related):
- **Adrien** (#5): 94-98% vs eye=7 — base scoring problem
- **Angel** (#6): 91-95% vs eye=6 — base scoring problem
- **Patricia** (#15): 68-71% vs eye=3 — base scoring problem

### Nondeterminism caveat
All scoring runs use gemini-3.1-flash-lite with no temperature control. Individual criterion scores can flip between runs. The Mohamed anomaly (+23%) is likely partly nondeterminism, but warrants investigation.
