# Criteria Effectiveness Analysis

## Team Lead, Customer Support (82 resumes scored, 20 criteria)

### Low Discrimination (>80% FM — nearly everyone matches)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| Strong communication skills | T1 | 91% | 9% | 0% |
| Handle multiple tasks and prioritize | T2 | 85% | 15% | 0% |

These criteria are almost universal — even wrong-domain candidates (exec assistants, IT PMs) match them. They inflate scores without helping rank.

### Strong Discrimination (<35% FM)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| Monitor reps' adherence to policies | T2 | 24% | 40% | 35% |
| Foster collaboration and teamwork | T2 | 29% | 48% | 23% |
| Develop and implement CS policies | T2 | 32% | 39% | 29% |
| Strong decision-making skills | T1 | 32% | 60% | 9% |

These criteria separate experienced CS leaders from everyone else.

### Good Discrimination (40-70% FM)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| 5+ years customer service | T1 | 70% | 18% | 12% |
| Leadership skills | T1 | 70% | 12% | 18% |
| Monitor performance, coaching | T2 | 60% | 13% | 27% |
| Train and onboard new reps | T2 | 46% | 29% | 24% |
| Prepare/analyze CS reports | T2 | 46% | 28% | 26% |

### Impact on wrong-domain overscoring
Patricia Fix (exec assistant, eyeball 3) scores 66% partly because low-discrimination criteria (communication, multitasking, organizational, problem-solving) give her 4 × FM at tier_1 weights. If those criteria had 50% discrimination, her score would drop ~10 points.

---

## Backend Engineer Go (502 resumes scored, 17 criteria)

### Low Discrimination (>70% FM)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| Strong Go production experience | T1 | 80% | 14% | 6% |

Everyone applying to a Go job has Go experience. This is a gatekeeper, not a differentiator.

### Too Niche (>50% NF — most candidates can't match)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| Cloud marketplace experience | T2 | 1% | 2% | 97% |
| Multi-cloud racks and environments | T2 | 2% | 23% | 76% |
| PaaS understanding | T2 | 7% | 31% | 62% |
| Terraform or IaC | T2 | 24% | 14% | 62% |
| Multi-cloud/hybrid environments | T2 | 15% | 35% | 50% |

These are legitimate Convox requirements, but they pull every candidate's score down because they're so niche. The 97% NF on "cloud marketplace" means this criterion contributes nothing to ranking.

### Best Differentiators (30-55% FM, good spread)
| Criterion | Tier | FM% | PM% | NF% |
|-----------|------|-----|-----|-----|
| CI/CD, developer tooling | T2 | 55% | 33% | 12% |
| Cloud platforms (AWS/GCP/Azure) | T2 | 53% | 33% | 13% |
| Monitoring/logging tools | T2 | 42% | 24% | 34% |
| Code reviews, mentoring | T2 | 31% | 50% | 19% |

### Impact on score distribution
The mean Go score is 48.6% partly because 5 criteria have >50% NF rate. With cloud marketplace (97% NF, worth 4 points) effectively contributing 0 points for 97% of candidates, the theoretical max is reduced for almost everyone.

---

## Suggested candidate tiers (for hiring workflow)

### Team Lead
| Tier | Score Range | Count | Description |
|------|------------|-------|-------------|
| A — Strong match | 85%+ | 30 (37%) | Direct CS leadership experience, evidence-rich |
| B — Good match | 70-85% | 21 (26%) | Relevant experience, some gaps |
| C — Partial match | 50-70% | 13 (16%) | Transferable skills, domain gaps |
| D — Weak match | <50% | 18 (22%) | Wrong domain or junior |

### Go Engineer
| Tier | Score Range | Count | Description |
|------|------------|-------|-------------|
| A — Strong match | 75%+ | 68 (14%) | Go + infrastructure/PaaS experience |
| B — Good match | 55-75% | 120 (24%) | Go + some infrastructure experience |
| C — Partial match | 35-55% | 201 (40%) | Go engineer, limited infrastructure |
| D — Weak match | <35% | 113 (23%) | Wrong stack or very junior |
