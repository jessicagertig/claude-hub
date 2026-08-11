# Definitive gpt-4o Nondeterminism Analysis — 5 Runs (v7/v8/v9/v10/v11)

Same prompt, same Call 1 input. All differences are model nondeterminism.

## Per-JD Results

| JD | binary (5 runs) | bin σ | T1% (5 runs) | T1% σ | criteria count (5 runs) | Stable? |
|---|---|---|---|---|---|---|
| Accounting & Field Service System I | 4/4/3/4/4 | 0.4 | 28%/28%/29%/28%/33% | 2.2 | 18/18/17/18/18 | YES |
| AI / Gameplay Programmer (UE5) | 0/2/2/0/2 | 1.1 | 11%/15%/9%/15%/11% | 2.7 | 27/27/34/27/27 | no |
| CART Captioner  | 1/6/5/6/5 | 2.1 | 20%/43%/38%/33%/43% | 9.6 | 10/21/21/21/21 | no |
| DevOps Engineer 运维工程师  | 2/2/2/2/2 | 0.0 | 21%/21%/21%/28%/19% | 3.5 | 19/28/29/25/43 | YES |
| Director of Development | 2/3/7/1/3 | 2.3 | 16%/12%/15%/17%/14% | 1.9 | 32/33/40/36/36 | no |
| Elixir Developer | 0/0/0/0/0 | 0.0 | 29%/29%/29%/29%/14% | 6.7 | 7/7/7/7/7 | no |
| Fire Alarm Installation Technician | 4/4/9/7/10 | 2.8 | 94%/95%/88%/85%/97% | 5.1 | 35/37/33/33/32 | no |
| Fire Alarm Test, Inspect and Servic | 4/9/0/4/4 | 3.2 | 97%/83%/0%/84%/94% | 40.5 | 33/35/0/32/31 | no |
| Senior Software Engineer - Fullstac | 0/0/0/0/0 | 0.0 | 47%/47%/47%/47%/47% | 0.0 | 17/17/17/17/17 | YES |
| Graphic Designer & E-Commerce/Socia | 2/0/6/1/0 | 2.5 | 3%/0%/3%/0%/3% | 1.6 | 86/47/87/76/88 | no |
| Host | 2/3/2/2/2 | 0.4 | 10%/10%/11%/11%/10% | 0.5 | 29/30/28/27/29 | YES |
| Housekeeper – Colorado Springs | 2/3/3/2/4 | 0.8 | 7%/0%/6%/15%/6% | 5.4 | 14/13/18/13/18 | no |
| Housekeeper - Buena Vista | 0/0/0/1/0 | 0.4 | 5%/16%/5%/17%/7% | 6.0 | 20/25/22/29/29 | no |
| Mechanical Engineer | 1/1/1/1/1 | 0.0 | 50%/50%/58%/58%/50% | 4.4 | 12/12/12/12/12 | YES |
| PharmD SaaS Business Strategist | 1/1/1/1/1 | 0.0 | 24%/17%/24%/20%/17% | 3.5 | 25/29/25/30/29 | YES |
| Project Architect | 2/3/3/3/3 | 0.4 | 11%/5%/12%/7%/9% | 2.9 | 18/22/24/15/23 | YES |
| Sales Manager (m/w/d) | 0/0/0/0/0 | 0.0 | 20%/0%/20%/20%/20% | 8.9 | 10/5/10/10/10 | no |
| Software Engineer | Core Protocol | 1/1/1/1/1 | 0.0 | 13%/8%/57%/39%/13% | 21.2 | 23/24/23/28/23 | no |
| Vice President, Service & Operation | 2/2/3/4/2 | 0.9 | 24%/19%/33%/27%/20% | 5.7 | 25/26/33/37/25 | no |
| Video Production Specialist | 2/2/2/2/2 | 0.0 | 26%/26%/24%/24%/24% | 1.1 | 38/38/42/45/42 | YES |

## Aggregate Stats

| Metric | Value |
|---|---|
| Runs | 5 |
| JDs per run | 20 |
| Mean binary σ | 0.86 |
| Median binary σ | 0.4 |
| Max binary σ | 3.2 |
| Mean T1% σ | 6.7 |
| Median T1% σ | 4.0 |
| Max T1% σ | 40.5 |
| Mean criteria count σ | 4.1 |
| Stable JDs (bin σ≤1, T1% σ≤5) | 8/20 (40%) |

## Stability Categories

**Very stable** (bin σ≤0.5, T1% σ≤3): 5/20 (25%)
  - Accounting & Field Service System Implem
  - Senior Software Engineer - Fullstack
  - Host
  - Project Architect
  - Video Production Specialist

**Moderate** (bin σ≤2, T1% σ≤10): 9/20 (45%)
  - AI / Gameplay Programmer (UE5) (bin σ=1.1, T1% σ=2.7)
  - DevOps Engineer 运维工程师  (bin σ=0.0, T1% σ=3.5)
  - Elixir Developer (bin σ=0.0, T1% σ=6.7)
  - Housekeeper – Colorado Springs (bin σ=0.8, T1% σ=5.4)
  - Housekeeper - Buena Vista (bin σ=0.4, T1% σ=6.0)
  - Mechanical Engineer (bin σ=0.0, T1% σ=4.4)
  - PharmD SaaS Business Strategist (bin σ=0.0, T1% σ=3.5)
  - Sales Manager (m/w/d) (bin σ=0.0, T1% σ=8.9)
  - Vice President, Service & Operations (bin σ=0.9, T1% σ=5.7)

**Volatile** (bin σ>2 or T1% σ>10): 6/20 (30%)
  - CART Captioner  (bin σ=2.1, T1% σ=9.6)
  - Director of Development (bin σ=2.3, T1% σ=1.9)
  - Fire Alarm Installation Technician (bin σ=2.8, T1% σ=5.1)
  - Fire Alarm Test, Inspect and Service Tec (bin σ=3.2, T1% σ=40.5)
  - Graphic Designer & E-Commerce/Social Med (bin σ=2.5, T1% σ=1.6)
  - Software Engineer | Core Protocol (bin σ=0.0, T1% σ=21.2)

## Comparison: gpt-4o-mini (3 runs) vs gpt-4o (5 runs)

| Metric | gpt-4o-mini (3 runs) | gpt-4o (5 runs) |
|---|---|---|
| Mean binary σ | 1.99 | 0.86 |
| Median binary σ | — | 0.4 |
| Mean T1% σ | 8.0 | 6.7 |
| Stable JDs | 25% | 40% |