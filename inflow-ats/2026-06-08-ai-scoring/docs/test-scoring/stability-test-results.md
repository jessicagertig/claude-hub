# Stability Test — Comprehensive Analysis

10 runs each job. Full pipeline: Call 1 (gpt-4.1-mini) → Call 2 (Gemini) → Call 2b (Gemini)

## Team Lead

### Criteria stability (normalized text matching)

- 44 unique criteria across all runs
- **14 in ALL 10 runs** (32%) — core criteria are stable
- **23 in 7+ runs** (52%) — majority are mostly stable
- 5 in 3-6 runs
- 16 in 1-2 runs — mostly from decomposition variance and text rephrasing

### The 14 always-present criteria

1. Analyze customer service trends and recommend improvements
2. Develop and implement customer service policies and procedures
3. Ensure CS reps maintain a high level of customer service
4. Foster collaboration and teamwork among CS reps
5. Knowledge of CS software and systems
6. Manual dexterity to operate desktop workstation
7. Minimum of 5+ years of experience in customer service
8. Monitor CS reps' adherence to company policies
9. Monitor CS reps' performance and provide ongoing coaching
10. Oversee day-to-day activities of specific teams
11. Proficient in Microsoft Office Suite
12. Resolve customer complaints and inquiries
13. Sit and use desktop computing workspace equipment
14. Train and onboard new CS reps

### What varies

- "Motivate and mentor" sometimes stays as one criterion, sometimes splits into two (decomposition variance)
- Physical requirements sometimes get slightly different wording
- Soft skills (leadership, organizational, communication, problem-solving, decision-making) present 9-10/10 runs but occasionally get rephrased
- Run 4 is an outlier at 30 criteria (others 24-26) — Call 2 extracted more that run

### Tier consistency

- T1 count: 2-3 across all runs (stable)
- Soft skills at T1: 0 in all 10 runs (self-review working perfectly)
- Key criteria tier assignments:
  - "5+ years": ALWAYS tier_1
  - "Microsoft Office": ALWAYS tier_1
  - "Communication": ALWAYS tier_2
  - "Organizational": ALWAYS tier_2
  - "Problem-solving": ALWAYS tier_2
  - "Leadership": VARIES (tier_1 in some runs, tier_2 in others)

## Go Engineer

### Criteria stability (normalized text matching)

- 73 unique criteria across all runs
- **12 in ALL 10 runs** (16%) — core criteria stable but lower than Team Lead
- **19 in 7+ runs** (26%) — less stable than Team Lead
- 8 in 3-6 runs
- 46 in 1-2 runs — heavy variance from decomposition

### The 12 always-present criteria

1. Design, build, and maintain backend services in Go (PaaS)
2. Excellent communication skills
3. Experience publishing on cloud marketplaces
4. Experience in multi cloud or hybrid cloud environments
5. Experience with Terraform or similar IaC
6. Hands on experience in cloud platforms (AWS/GCP/Azure)
7. Help architect, deploy, maintain multi cloud racks
8. Monitoring and logging tools (Prometheus/Grafana/ELK)
9. Solid understanding of Kubernetes
10. Strong Go production experience
11. System design for HA, multi-region, multi-tenant
12. Work cross functionally

### What varies

- Decomposition is the main source of variance — Go has more compound criteria from the responsibilities section
- "CI/CD pipelines, developer tooling" sometimes kept as one, sometimes split
- "Code reviews, mentor others, best practices" sometimes kept, sometimes split
- Decomposed criteria get different wording each time ("build integrations with cloud providers in Go" vs "using Go" vs "for backend services")
- Criteria count ranges from 21 to 33 — wide range

### Tier consistency

- T1 count: 2-5 across runs (unstable)
- Soft skills at T1: 0 in all 10 runs (self-review working)
- Key criteria tier assignments:
  - "Go (Golang)": ALWAYS tier_1
  - "Kubernetes": ALWAYS tier_1
  - "Terraform": ALWAYS tier_2
  - "Communication": ALWAYS tier_2
  - "Cloud platform": ALWAYS tier_2

## Overall Assessment

### What's stable
- Core criteria extraction — the same ~14 (TL) and ~12 (Go) criteria appear every run
- Soft skills at tier_2 — 0 leaks in 20 runs
- Key tier assignments — Go, K8s, communication, 5+ years always get the same tier

### What's unstable
- Decomposition — which criteria get decomposed and how they're worded varies each run
- Total criteria count — 24-30 (TL), 21-33 (Go)
- T1 count on Go — 2-5 (driven by whether "Required" heading lock applies consistently)

### Root cause
The instability is almost entirely from Call 2b decomposition. Call 2's core extraction is reasonably stable. The decomposition step adds 0-10 criteria depending on the run, with different wording each time.
