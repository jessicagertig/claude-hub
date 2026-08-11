# Sensitivity & Criterion Discrimination Analysis

## Universal Pattern (observed across 3 job types)

Criteria fall into 3 bands:

| Band | FM Rate | NF Rate | Examples | Discrimination |
|------|---------|---------|----------|---------------|
| Too generic | >80% | <5% | Communication skills, Python, analytical skills | None — everyone matches |
| Sweet spot | 30-60% | 10-35% | SQL pipelines, K8s, CS team management | Strong — separates qualified from unqualified |
| Too niche | <15% | >50% | Cloud marketplace, supply/demand balance | Floor effect — almost nobody matches |

## Sensitivity Test: Removing Low-Discrimination Criteria

Tested on Team Lead (20 benchmarked resumes): removed "Strong communication skills" (91% FM) and "Handle multiple tasks" (85% FM).

**Result: Zero impact on rank correlation.** Spearman ρ stays at 0.826 exactly. Low-discrimination criteria affect all candidates equally, so they don't distort relative rankings.

However, they DO inflate absolute scores — a wrong-domain candidate (exec assistant) scores 66% partly because generic criteria give her free points. Removing them drops her to 62%, but the relative ranking doesn't change.

## Implication for Product

For the scoring pipeline, the absolute percentage matters more than pure ranking (it determines which tier a candidate falls into). Two options:

1. **Keep all criteria, use relative thresholds** — define tier boundaries per job based on the score distribution (e.g., top 20% = Tier A)
2. **Weight criteria by discrimination** — criteria with 80%+ FM rate get reduced weight since they don't contribute information

Option 1 is simpler and works with the current pipeline. Option 2 would require a discrimination pre-pass.

## Criterion Discrimination by Job

### Team Lead (20 criteria, 82 resumes)

**Low disc (>80% FM):**
- Strong communication skills (T1): 91% FM
- Handle multiple tasks (T2): 85% FM

**Best discriminators:**
- Monitor reps' adherence to policies (T2): 24% FM, 35% NF
- Foster collaboration (T2): 29% FM, 23% NF
- Develop/implement CS policies (T2): 32% FM, 29% NF

### Go Engineer (17 criteria, 502 resumes)

**Low disc (>70% FM):**
- Strong Go production experience (T1): 80% FM

**Too niche (>50% NF):**
- Cloud marketplace (T2): 97% NF
- Multi-cloud racks (T2): 76% NF
- PaaS understanding (T2): 62% NF
- Terraform/IaC (T2): 62% NF

**Best discriminators:**
- CI/CD, developer tooling (T2): 55% FM, 12% NF
- Cloud platforms (T2): 53% FM, 13% NF
- Monitoring tools (T2): 42% FM, 34% NF

### Data Analyst (28 criteria, 192 resumes)

**Low disc (>80% FM):**
- Python/data programming (T2): 96% FM
- Quantitative background (T2): 93% FM
- Exploratory analysis (T2): 84% FM
- Strong analytical skills (T1): 81% FM

**Too niche (>40% NF):**
- Supply/demand balance frameworks (T2): 83% NF
- Environmental awareness/mobility (T2): 48% NF
- Define/track new business lines (T2): 44% NF

**Best discriminators:**
- SQL queries/large datasets (T1): 57% FM
- Cross-functional recommendations (T2): 52% FM
- Processing pipelines (T2): 51% FM
- 3-5 years Data/BI experience (T2): 23% FM, 27% NF
