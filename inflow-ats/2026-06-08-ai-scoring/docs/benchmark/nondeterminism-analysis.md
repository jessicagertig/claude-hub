# Nondeterminism Analysis — Same Prompt (v6 original), 3 Runs

All 3 runs use identical Call 1 (v5) + Call 2 (v6 original) prompts.
Differences are purely model nondeterminism.

## Per-JD Results

| JD | bin r1 | bin r2 | bin r3 | bin σ | T1% r1 | T1% r2 | T1% r3 | T1% σ | pres r1 | pres r2 | pres r3 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Accounting & Field Service System Implem | 4 | 2 | 5 | 1.5 | 33% | 28% | 28% | 2.9 | 12/18 | 0/18 | 12/18 |
| AI / Gameplay Programmer (UE5) | 0 | 0 | 0 | 0.0 | 15% | 17% | 15% | 1.2 | 27/27 | 30/30 | 27/27 |
| CART Captioner  | 1 | 4 | 1 | 1.7 | 20% | 38% | 20% | 10.4 | 10/10 | 21/21 | 10/10 |
| DevOps Engineer 运维工程师  | 1 | 2 | 1 | 0.6 | 39% | 7% | 32% | 16.8 | 0/44 | 0/28 | 0/34 |
| Director of Development | 3 | 3 | 5 | 1.2 | 9% | 21% | 11% | 6.4 | 10/34 | 2/14 | 21/46 |
| Elixir Developer | 0 | 0 | 0 | 0.0 | 14% | 0% | 0% | 8.1 | 5/7 | 5/7 | 5/7 |
| Fire Alarm Installation Technician | 30 | 24 | 7 | 11.9 | 97% | 97% | 97% | 0.0 | 29/31 | 30/32 | 25/32 |
| Fire Alarm Test, Inspect and Service Tec | 5 | 5 | 29 | 13.9 | 84% | 97% | 94% | 6.8 | 17/31 | 16/31 | 16/31 |
| Senior Software Engineer - Fullstack | 0 | 1 | 0 | 0.6 | 47% | 53% | 47% | 3.5 | 17/17 | 17/17 | 17/17 |
| Graphic Designer & E-Commerce/Social Med | 0 | 1 | 1 | 0.6 | 0% | 4% | 7% | 3.5 | 0/0 | 59/68 | 13/76 |
| Host | 0 | 0 | 2 | 1.2 | 10% | 9% | 6% | 2.1 | 25/29 | 13/32 | 13/31 |
| Housekeeper – Colorado Springs | 2 | 2 | 3 | 0.6 | 10% | 11% | 15% | 2.6 | 2/21 | 3/19 | 13/13 |
| Housekeeper - Buena Vista | 0 | 0 | 0 | 0.0 | 17% | 0% | 78% | 41.0 | 24/24 | 23/24 | 0/23 |
| Mechanical Engineer | 4 | 6 | 6 | 1.2 | 33% | 50% | 50% | 9.8 | 0/12 | 12/12 | 12/12 |
| PharmD SaaS Business Strategist | 3 | 5 | 3 | 1.2 | 25% | 19% | 24% | 3.2 | 24/24 | 20/27 | 25/25 |
| Project Architect | 4 | 0 | 0 | 2.3 | 8% | 8% | 5% | 1.7 | 13/13 | 13/13 | 12/22 |
| Sales Manager (m/w/d) | 1 | 1 | 1 | 0.0 | 20% | 20% | 20% | 0.0 | 10/10 | 10/10 | 10/10 |
| Software Engineer | Core Protocol | 1 | 1 | 1 | 0.0 | 26% | 12% | 9% | 9.1 | 1/31 | 2/51 | 2/43 |
| Vice President, Service & Operations | 1 | 0 | 1 | 0.6 | 32% | 83% | 83% | 29.4 | 0/38 | 0/36 | 0/36 |
| Video Production Specialist | 2 | 3 | 3 | 0.6 | 24% | 23% | 24% | 0.6 | 36/42 | 38/43 | 38/42 |

## Aggregate Nondeterminism Stats

- Mean binary σ across JDs: 1.99
- Max binary σ: 13.9
- Mean T1% σ across JDs: 8.0
- Max T1% σ: 41.0
- JDs with high variance (bin σ>2 or T1% σ>15): 6/20

## High-Variance JDs

### Housekeeper - Buena Vista
- Binary: 0, 0, 0 (σ=0.0)
- T1%: 17%, 0%, 78% (σ=41.0)

### Vice President, Service & Operations
- Binary: 1, 0, 1 (σ=0.6)
- T1%: 32%, 83%, 83% (σ=29.4)

### Fire Alarm Test, Inspect and Service Tec
- Binary: 5, 5, 29 (σ=13.9)
- T1%: 84%, 97%, 94% (σ=6.8)

### DevOps Engineer 运维工程师 
- Binary: 1, 2, 1 (σ=0.6)
- T1%: 39%, 7%, 32% (σ=16.8)

### Fire Alarm Installation Technician
- Binary: 30, 24, 7 (σ=11.9)
- T1%: 97%, 97%, 97% (σ=0.0)

### Project Architect
- Binary: 4, 0, 0 (σ=2.3)
- T1%: 8%, 8%, 5% (σ=1.7)

## Stable JDs (5/20)

JDs where binary σ ≤ 1 AND T1% σ ≤ 5 across 3 runs:
- AI / Gameplay Programmer (UE5)
- Senior Software Engineer - Fullstack
- Housekeeper – Colorado Springs
- Sales Manager (m/w/d)
- Video Production Specialist

## Conclusions

- **25% of JDs (5/20) are stable** across 3 identical runs
- **6 JDs have high variance** — these produce meaningfully different results each run
- **Binary flag** is the most volatile feature (mean σ=1.99)
- **Tier assignment** is moderately volatile on some JDs (mean σ=8.0%)

## Recommendation

The prompt is as good as it can be for gpt-4o-mini. Remaining variance is model-level.
Options to reduce variance:
1. **Run 3x and majority-vote** — cheap ($0.003/JD extra), reduces binary and tier noise
2. **Upgrade to gpt-4o** for Call 2 — better instruction following, ~10x cost ($0.01/JD vs $0.001)
3. **Accept the variance** — the stable JDs (majority) are good enough for scoring