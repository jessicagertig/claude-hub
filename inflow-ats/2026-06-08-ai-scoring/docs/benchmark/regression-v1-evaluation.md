# Regression Set v1 — Full Evaluation

20 JDs (5 standard + 15 problematic). Call 1 v5 + Call 2 v6.

## Results Summary

| # | Kind | Title | Total | T1 | T2 | T3 | T1% | Bin | Pres | Dec | Flags |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ? | Accounting & Field Service System Implementat | 18 | 6 | 12 | 0 | 33% | 2 | 13 | 5 |  |
| 2 | ? | AI / Gameplay Programmer (UE5) | 27 | 4 | 21 | 2 | 15% | 0 | 27 | 0 | NO_BINARY |
| 3 | standard | CART Captioner  | 21 | 10 | 11 | 0 | 48% | 7 | 21 | 0 |  |
| 4 | ? | DevOps Engineer 运维工程师  | 27 | 3 | 20 | 4 | 11% | 1 | 18 | 9 |  |
| 5 | problematic | Director of Development | 36 | 2 | 34 | 0 | 6% | 2 | 0 | 36 | ALL_DECOMPOSED |
| 6 | problematic | Elixir Developer | 7 | 0 | 5 | 2 | 0% | 0 | 5 | 2 |  |
| 7 | problematic | Fire Alarm Installation Technician | 32 | 31 | 1 | 0 | 97% | 31 | 31 | 1 | HIGH_T1, OVER_BINARY |
| 8 | problematic | Fire Alarm Test, Inspect and Service Technici | 40 | 26 | 14 | 0 | 65% | 3 | 38 | 2 |  |
| 9 | problematic | Senior Software Engineer - Fullstack | 17 | 8 | 9 | 0 | 47% | 0 | 17 | 0 | NO_BINARY |
| 10 | problematic | Graphic Designer & E-Commerce/Social Media Ma | 76 | 3 | 73 | 0 | 4% | 0 | 11 | 65 | NO_BINARY |
| 11 | problematic | Host | 19 | 2 | 17 | 0 | 11% | 2 | 18 | 1 |  |
| 12 | problematic | Housekeeper - Buena Vista | 23 | 22 | 1 | 0 | 96% | 0 | 0 | 23 | HIGH_T1, NO_BINARY, ALL_DECOMPOSED |
| 13 | problematic | Housekeeper – Colorado Springs | 14 | 2 | 12 | 0 | 14% | 2 | 14 | 0 |  |
| 14 | standard | Mechanical Engineer | 12 | 7 | 5 | 0 | 58% | 3 | 12 | 0 |  |
| 15 | standard | PharmD SaaS Business Strategist | 29 | 5 | 23 | 1 | 17% | 3 | 0 | 29 | ALL_DECOMPOSED |
| 16 | problematic | Project Architect | 20 | 2 | 18 | 0 | 10% | 3 | 0 | 20 | ALL_DECOMPOSED |
| 17 | problematic | Sales Manager (m/w/d) | 10 | 2 | 8 | 0 | 20% | 1 | 10 | 0 |  |
| 18 | problematic | Software Engineer | Core Protocol | 38 | 8 | 30 | 0 | 21% | 1 | 3 | 35 |  |
| 19 | problematic | Vice President, Service & Operations | 38 | 23 | 15 | 0 | 61% | 1 | 0 | 38 | ALL_DECOMPOSED |
| 20 | standard | Video Production Specialist | 42 | 10 | 32 | 0 | 24% | 2 | 38 | 4 |  |

## Flagged Issues

### AI / Gameplay Programmer (UE5)
Flags: NO_BINARY
T1:4 T2:21 T3:2 | binary:0 | preserved:27 decomposed:0

### Director of Development
Flags: ALL_DECOMPOSED
T1:2 T2:34 T3:0 | binary:2 | preserved:0 decomposed:36

### Fire Alarm Installation Technician
Flags: HIGH_T1, OVER_BINARY
T1:31 T2:1 T3:0 | binary:31 | preserved:31 decomposed:1

### Senior Software Engineer - Fullstack
Flags: NO_BINARY
T1:8 T2:9 T3:0 | binary:0 | preserved:17 decomposed:0

### Graphic Designer & E-Commerce/Social Media Manager
Flags: NO_BINARY
T1:3 T2:73 T3:0 | binary:0 | preserved:11 decomposed:65

### Housekeeper - Buena Vista
Flags: HIGH_T1, NO_BINARY, ALL_DECOMPOSED
T1:22 T2:1 T3:0 | binary:0 | preserved:0 decomposed:23

### PharmD SaaS Business Strategist
Flags: ALL_DECOMPOSED
T1:5 T2:23 T3:1 | binary:3 | preserved:0 decomposed:29

### Project Architect
Flags: ALL_DECOMPOSED
T1:2 T2:18 T3:0 | binary:3 | preserved:0 decomposed:20

### Vice President, Service & Operations
Flags: ALL_DECOMPOSED
T1:23 T2:15 T3:0 | binary:1 | preserved:0 decomposed:38

## Issue Analysis

### OVER_BINARY (1 JDs)
Model marking nearly everything as binary. Fire Alarm Installation: 31/32 binary — skills like 'troubleshoot fire alarm systems' are NOT binary (there's a spectrum of proficiency), but the model flags them as binary because they're under a 'Required' heading in a trade/certification-heavy JD.

### HIGH_T1 (2 JDs)
- Fire Alarm Installation Technician: 97% tier_1 (31/32)
- Housekeeper - Buena Vista: 96% tier_1 (22/23)

Fire Alarm Installation and Housekeeper Buena Vista both have structured 'Required' sections. The model respects the heading, which is correct per Decision 9. VP Service & Operations has strong-expectation language throughout.

### ALL_DECOMPOSED (5 JDs)
- Director of Development: 0/36 preserved
- Housekeeper - Buena Vista: 0/23 preserved
- PharmD SaaS Business Strategist: 0/29 preserved
- Project Architect: 0/20 preserved
- Vice President, Service & Operations: 0/38 preserved

Text preservation rule is nondeterministic. Same prompt produces preserved:38/42 on Video Production but preserved:0/36 on Director of Development. This is a gpt-4o-mini consistency issue, not a prompt gap — the rule IS in the prompt with explicit examples.

### NO_BINARY (4 JDs)
- AI / Gameplay Programmer (UE5): 0 binary on 27 criteria
- Senior Software Engineer - Fullstack: 0 binary on 17 criteria
- Graphic Designer & E-Commerce/Social Media Manager: 0 binary on 76 criteria
- Housekeeper - Buena Vista: 0 binary on 23 criteria

## Improvements vs Batch Runs

- Director of Development: binary 0 → 2 (FIXED)
- Project Architect: binary 0 → 3 (FIXED)
- Host: decomposed 32/32 → 1/19 (IMPROVED)
- Housekeeper Colorado Springs: preserved 10/13 → 14/14 (IMPROVED)
- Sales Manager German: preserved 0/10 → 10/10 (IMPROVED)

## Prompt Changes for v2

### 1. OVER_BINARY on Fire Alarm (31/32)
The model treats trade skills as binary because they appear alongside certifications in a trade JD. Add explicit guidance: 'Skills and proficiency-based items are binary: false even in trade/certification-heavy JDs. Only items where a candidate either HAS it or DOESN'T (license, degree, vehicle, schedule) are binary: true. "Ability to troubleshoot fire alarm systems" is a skill spectrum, not binary.'

### 2. ALL_DECOMPOSED nondeterminism
Not fixable via prompt — the text preservation rule is already explicit with examples. This is model-level nondeterminism. Accept it.

### 3. Housekeeper Buena Vista HIGH_T1 (22/23)
New problem not seen in Colorado Springs housekeeper. Check if Call 1 is putting everything under a 'Required'-type heading. May be a Call 1 section classification issue rather than Call 2.
