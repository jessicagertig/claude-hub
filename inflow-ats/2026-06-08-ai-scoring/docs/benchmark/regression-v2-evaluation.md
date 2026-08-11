# Regression v1 vs v2 Comparison

Change in v2: Added explicit guidance that skills/proficiency items are ALWAYS binary: false, even in trade/certification-heavy JDs.

| JD | Kind | v1 bin | v2 bin | Δ bin | v1 T1% | v2 T1% | v1 pres | v2 pres |
|---|---|---|---|---|---|---|---|---|
| Accounting & Field Service System Implem | ? | 2 | 3 | +1 | 33% | 41% | 13/18 | 17/17 |
| AI / Gameplay Programmer (UE5) | ? | 0 | 0 | = | 15% | 14% | 27/27 | 28/28 |
| CART Captioner  | stand | 7 | 6 | -1 | 48% | 48% | 21/21 | 21/21 |
| DevOps Engineer 运维工程师  | ? | 1 | 2 | +1 | 11% | 11% | 18/27 | 15/19 |
| Director of Development | probl | 2 | 2 | = | 6% | 5% | 0/36 | 0/39 |
| Elixir Developer | probl | 0 | 0 | = | 0% | 0% | 5/7 | 4/7 |
| Fire Alarm Installation Technician | probl | 31 | 7 | -24 ⚠️ | 97% | 97% | 31/32 | 31/32 |
| Fire Alarm Test, Inspect and Service Tec | probl | 3 | 3 | = | 65% | 94% | 38/40 | 21/31 |
| Senior Software Engineer - Fullstack | probl | 0 | 0 | = | 47% | 12% | 17/17 | 17/17 |
| Graphic Designer & E-Commerce/Social Med | probl | 0 | 0 | = | 4% | 2% | 11/76 | 62/83 |
| Host | probl | 2 | 0 | -2 ⚠️ | 11% | 10% | 18/19 | 17/31 |
| Housekeeper – Colorado Springs | probl | 2 | 3 | +1 | 14% | 15% | 14/14 | 8/13 |
| Housekeeper - Buena Vista | probl | 0 | 0 | = | 96% | 13% | 0/23 | 23/23 |
| Mechanical Engineer | stand | 3 | 1 | -2 ⚠️ | 58% | 42% | 12/12 | 12/12 |
| PharmD SaaS Business Strategist | stand | 3 | 1 | -2 ⚠️ | 17% | 21% | 0/29 | 14/28 |
| Project Architect | probl | 3 | 0 | -3 ⚠️ | 10% | 4% | 0/20 | 23/23 |
| Sales Manager (m/w/d) | probl | 1 | 1 | = | 20% | 20% | 10/10 | 10/10 |
| Software Engineer | Core Protocol | probl | 1 | 1 | = | 21% | 11% | 3/38 | 4/28 |
| Vice President, Service & Operations | probl | 1 | 1 | = | 61% | 50% | 0/38 | 0/36 |
| Video Production Specialist | stand | 2 | 3 | +1 | 24% | 24% | 38/42 | 32/42 |

**Total binary: v1=64 → v2=34 (Δ -30)**

## Improvements

## Regressions
- Fire Alarm Installation Technician: binary 31 → 7 ⚠️
- Host: binary 2 → 0 ⚠️
- Mechanical Engineer: binary 3 → 1 ⚠️
- PharmD SaaS Business Strategist: binary 3 → 1 ⚠️
- Project Architect: binary 3 → 0 ⚠️

## VP Service & Operations tier improvement
v1: T1:23 T2:15 (61% T1)
v2: T1:18 T2:18 (50% T1)

## Verdict
Fire Alarm Installation binary: 31 → 7 (target fix)
Net binary change: -30 (-30)
Regressions: 5