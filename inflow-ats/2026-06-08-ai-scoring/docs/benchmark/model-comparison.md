# Model Comparison: gpt-4o-mini vs gpt-4o — Call 2 Criteria Extraction

Same prompt (v6 original). Same Call 1 input (v5).
gpt-4o-mini: 3 runs (v4/v5/v6). gpt-4o: 2 runs (v7/v8).

## Per-JD Comparison

| JD | mini bin (3 runs) | mini σ | 4o bin (2 runs) | 4o σ | mini T1% (3 runs) | mini σ | 4o T1% (2 runs) | 4o σ |
|---|---|---|---|---|---|---|---|---|
| Accounting & Field Service System I | 4/2/5 | 1.5 | 4/4 | 0.0 | 33%/28%/28% | 2.9 | 28%/28% | 0.0 |
| AI / Gameplay Programmer (UE5) | 0/0/0 | 0.0 | 0/2 | 1.4 | 15%/17%/15% | 1.2 | 11%/15% | 2.8 |
| CART Captioner  | 1/4/1 | 1.7 | 1/6 | 3.5 | 20%/38%/20% | 10.4 | 20%/43% | 16.3 |
| DevOps Engineer 运维工程师  | 1/2/1 | 0.6 | 2/2 | 0.0 | 39%/7%/32% | 16.8 | 21%/21% | 0.0 |
| Director of Development | 3/3/5 | 1.2 | 2/3 | 0.7 | 9%/21%/11% | 6.4 | 16%/12% | 2.8 |
| Elixir Developer | 0/0/0 | 0.0 | 0/0 | 0.0 | 14%/0%/0% | 8.1 | 29%/29% | 0.0 |
| Fire Alarm Installation Technician | 30/24/7 | 11.9 | 4/4 | 0.0 | 97%/97%/97% | 0.0 | 94%/95% | 0.7 |
| Fire Alarm Test, Inspect and Servic | 5/5/29 | 13.9 | 4/9 | 3.5 | 84%/97%/94% | 6.8 | 97%/83% | 9.9 |
| Senior Software Engineer - Fullstac | 0/1/0 | 0.6 | 0/0 | 0.0 | 47%/53%/47% | 3.5 | 47%/47% | 0.0 |
| Graphic Designer & E-Commerce/Socia | 0/1/1 | 0.6 | 2/0 | 1.4 | 0%/4%/7% | 3.5 | 3%/0% | 2.1 |
| Host | 0/0/2 | 1.2 | 2/3 | 0.7 | 10%/9%/6% | 2.1 | 10%/10% | 0.0 |
| Housekeeper – Colorado Springs | 2/2/3 | 0.6 | 2/3 | 0.7 | 10%/11%/15% | 2.6 | 7%/0% | 4.9 |
| Housekeeper - Buena Vista | 0/0/0 | 0.0 | 0/0 | 0.0 | 17%/0%/78% | 41.0 | 5%/16% | 7.8 |
| Mechanical Engineer | 4/6/6 | 1.2 | 1/1 | 0.0 | 33%/50%/50% | 9.8 | 50%/50% | 0.0 |
| PharmD SaaS Business Strategist | 3/5/3 | 1.2 | 1/1 | 0.0 | 25%/19%/24% | 3.2 | 24%/17% | 4.9 |
| Project Architect | 4/0/0 | 2.3 | 2/3 | 0.7 | 8%/8%/5% | 1.7 | 11%/5% | 4.2 |
| Sales Manager (m/w/d) | 1/1/1 | 0.0 | 0/0 | 0.0 | 20%/20%/20% | 0.0 | 20%/0% | 14.1 |
| Software Engineer | Core Protocol | 1/1/1 | 0.0 | 1/1 | 0.0 | 26%/12%/9% | 9.1 | 13%/8% | 3.5 |
| Vice President, Service & Operation | 1/0/1 | 0.6 | 2/2 | 0.0 | 32%/83%/83% | 29.4 | 24%/19% | 3.5 |
| Video Production Specialist | 2/3/3 | 0.6 | 2/2 | 0.0 | 24%/23%/24% | 0.6 | 26%/26% | 0.0 |

## Aggregate Nondeterminism

| Metric | gpt-4o-mini (3 runs) | gpt-4o (2 runs) |
|---|---|---|
| Mean binary σ | 1.99 | 0.63 |
| Max binary σ | 13.9 | 3.5 |
| Mean T1% σ | 8.0 | 3.9 |
| Max T1% σ | 41.0 | 16.3 |
| JDs with bin σ > 2 | 3 | 2 |
| JDs with T1% σ > 10 | 4 | 2 |

## Tier 3 Usage
- gpt-4o-mini total T3 across runs: 7/7/7
- gpt-4o total T3 across runs: 21/13

## Text Preservation
- gpt-4o-mini avg preservation rate: 62.0%
- gpt-4o avg preservation rate: 74.1%

## Worst Offenders: mini vs 4o

**Fire Alarm Install**
- Binary: mini [30, 24, 7] → 4o [4, 4]
- T1%: mini [97, 97, 97] → 4o [94, 95]

**Fire Alarm Test**
- Binary: mini [5, 5, 29] → 4o [4, 9]
- T1%: mini [84, 97, 94] → 4o [97, 83]

**VP Service & Ops**
- Binary: mini [1, 0, 1] → 4o [2, 2]
- T1%: mini [32, 83, 83] → 4o [24, 19]

**Housekeeper BV**
- Binary: mini [0, 0, 0] → 4o [0, 0]
- T1%: mini [17, 0, 78] → 4o [5, 16]

**Director of Dev**
- Binary: mini [3, 3, 5] → 4o [2, 3]
- T1%: mini [9, 21, 11] → 4o [16, 12]

## Conclusion

**gpt-4o is more stable.** Binary σ: 1.99 → 0.63. T1% σ: 8.0 → 3.9.

## Recommendation

Based on this data:
- **Call 1 (section decomposition)**: keep gpt-4o-mini — it's stable and cheap
- **Call 2 (criteria extraction)**: use gpt-4o if binary σ 0.63 < 1.99 and T1% σ 3.9 < 8.0, otherwise keep mini with 3x majority vote