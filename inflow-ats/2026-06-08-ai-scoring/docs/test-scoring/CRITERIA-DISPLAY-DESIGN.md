# User-Facing Criteria Match Display — Design

## What it looks like

For each criterion extracted from the JD, show the candidate's match status:

```
CRITERIA MATCH                                        14/23 matched

✓  Go programming experience                         Strong
   4 years production Go at Tekion, enterprise-scale services

✓  Kubernetes                                         Strong  
   Managed OpenShift clusters, deployments, autoscaling

~  Terraform or similar IaC                           Partial
   Uses Ansible and Tekton for IaC — no Terraform specifically

✓  Cloud platforms (AWS/GCP/Azure)                    Strong
   AWS (ECS, S3, Lambda), multi-service deployment experience

✗  PaaS product understanding                         Not found
   No PaaS or developer platform experience mentioned

✓  CI/CD pipelines                                    Strong
   Jenkins, Tekton, Harness — built and maintained pipelines

~  System design for HA/multi-region                  Partial
   Designed for high availability but single-region only

✗  Cloud marketplace experience                       Not found
   No marketplace publishing or integration experience
```

## Data needed per criterion

```json
{
  "criterion_text": "Experience working with Terraform or similar IaC",
  "user_label": "Terraform or similar IaC",
  "score": "partial_match",
  "evidence": "Uses Ansible and Tekton for infrastructure automation — no Terraform specifically",
  "tier": "tier_1",
  "strength_label": "Partial"
}
```

### Fields

- `user_label`: Short, recruiter-friendly name for the criterion. Generated from criterion_text but simplified.
- `score`: full_match / partial_match / not_found (from Call 4)
- `evidence`: One sentence explaining WHY this score was given, referencing the candidate's resume.
- `tier`: tier_1 / tier_2 / tier_3 (from criteria extraction — determines display order and importance)
- `strength_label`: "Strong" / "Partial" / "Not found" (human-readable score)

## Display sections

Group criteria by tier for display:

**Required Skills** (tier_1) — shown first, most prominent
**Preferred Skills** (tier_2) — shown second
**Bonus Skills** (tier_3) — shown last, de-emphasized

Within each section, sort: full_match first, then partial_match, then not_found.

## How to generate the display data

### Option A: Extend Call 4 (scoring prompt)

Add `user_label` and `evidence` to the scoring schema. The scoring model already reads the resume and criteria — it can generate user-friendly text at the same time.

Pro: One API call, no extra cost.
Con: Adding output fields may degrade scoring accuracy. The prompt is already complex.

### Option B: Separate display generation call

After scoring, run a new call that takes:
- Criteria list with scores
- Resume text
- Output: user_label + evidence per criterion

Pro: Scoring quality preserved.
Con: Extra API call per candidate.

### Option C: Generate user_label at extraction time, evidence at scoring time

- During criteria extraction (Call 2), also generate a `user_label` for each criterion
- During scoring (Call 4), also generate `evidence` for each criterion

Pro: Distributes the work. user_label is per-JD (generated once), evidence is per-candidate.
Con: Two prompts need modification.

### Recommendation

**Option C** is the best balance:
- `user_label` generated once per JD during Call 2 (add to schema)
- `evidence` generated per candidate during Call 4 (add to schema)
- No extra API calls
- Each field is generated in the context where the model has the most relevant information

## Integration with summary display

The new UI layout for a candidate:

```
┌─────────────────────────────────────────────────┐
│ AI candidate summary                            │
│                                                 │
│ Backend Developer with 9.5 Years Experience     │
│ in High-Performance Systems                     │
│                                                 │
│ [Summary text]                                  │
│                                                 │
│ ┌─── Fit for this role ────────────────────┐   │
│ │ [role_analysis text]                      │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ ┌─── Criteria Match (14/23) ───────────────┐   │
│ │ REQUIRED                                  │   │
│ │ ✓ Go programming — Strong                │   │
│ │ ✓ Kubernetes — Strong                    │   │
│ │ ~ Terraform — Partial                    │   │
│ │ ✗ PaaS understanding — Not found         │   │
│ │                                           │   │
│ │ PREFERRED                                 │   │
│ │ ✓ CI/CD pipelines — Strong               │   │
│ │ ~ System design — Partial                │   │
│ │                                           │   │
│ │ BONUS                                     │   │
│ │ ✗ Cloud marketplace — Not found          │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ ┌─── Notable Achievements ─────────────────┐   │
│ │ • [standout accomplishment 1]             │   │
│ │ • [standout accomplishment 2]             │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ ┌─── Gaps to Probe ────────────────────────┐   │
│ │ [gaps text]                               │   │
│ └───────────────────────────────────────────┘   │
│                                                 │
│ [Show details] → Work Experience, Education...  │
└─────────────────────────────────────────────────┘
```

## Schema changes needed

### Call 2 (criteria extraction) — add user_label

```ruby
properties: {
  text: { type: 'string' },
  user_label: { type: 'string' },  # NEW
  tier: { ... },
  # ... rest unchanged
}
```

Prompt addition: "user_label: a short, recruiter-friendly label for this criterion (under 40 characters). Simplify jargon. Example: 'Experience working with Terraform or a similar IaC tool' → 'Terraform or similar IaC'"

### Call 4 (scoring) — add evidence

```ruby
properties: {
  criterion_text: { type: 'string' },
  score: { ... },
  reasoning: { type: 'string' },
  evidence: { type: 'string' },  # NEW
  # ... rest unchanged
}
```

Prompt addition: "evidence: one sentence for a recruiter explaining why you gave this score. Reference specific details from the resume. Keep it factual and under 100 characters."

## What the frontend receives

The serializer exposes a new `scoring` key alongside existing summary fields:

```json
{
  "headline": "Backend Developer with 9.5 Years Experience...",
  "summaryText": "...",
  "roleAnalysis": "...",
  "applicableExperience": "...",
  "gaps": "...",
  "scoring": {
    "percentage": 64.6,
    "matched": 14,
    "total": 23,
    "criteria": [
      {
        "userLabel": "Go programming",
        "score": "full_match",
        "strengthLabel": "Strong",
        "evidence": "4 years production Go at Tekion",
        "tier": "tier_1",
        "tierLabel": "Required"
      }
    ]
  }
}
```
