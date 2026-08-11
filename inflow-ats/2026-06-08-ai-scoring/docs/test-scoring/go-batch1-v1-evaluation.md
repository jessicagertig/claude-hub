# Go Backend Engineer Scoring Evaluation -- Batch 1, v1

Evaluation of AI-generated scoring for 5 candidates against a Backend Engineer (Go) position. Each criterion scored as full_match (FM), partial_match (PM), or not_found (NF).

---

## go-1 (Abhishek) -- 30.6% (22/72)

**Score breakdown:** 2 FM, 5 PM, 10 NF

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Has Go API experience but no PaaS/scheduler. PM is fair. |
| 2 | Kubernetes + Terraform across clouds | T2 | NF | **Questionable** | Resume lists Kubernetes in Technical Skills. The reasoning says "lists Kubernetes in technical skills but provides no evidence of practical work." This is harsh but defensible -- the resume shows Docker Compose orchestration in projects but never uses Kubernetes in any described work. NF is borderline; PM might be fairer given the Master's in Cloud Computing & DevOps. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CLI, CI/CD, observability | T2 | PM | Yes | Has cross-functional collaboration and CI/CD but no CLI/observability. |
| 5 | Reliability/monitoring/alerting/failover | T2 | PM | Yes | Mentions scalability in microservices context but no monitoring tools. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | Participated in code reviews during internship. No mentoring evidence. |
| 7 | Strong Go production experience | T1 | FM | **Questionable -- likely too generous** | The candidate has one internship (May 2025 - Present, ~1 month at scoring time) using Go. The projects are personal/academic. "Strong programming experience in Go for production backend systems" typically implies multiple years. An intern with one month of professional Go experience getting FM on a T1 criterion inflates the score. PM would be more appropriate. |
| 8 | Solid Kubernetes understanding | T1 | NF | **Questionable** | Listed in skills, Master's in Cloud Computing & DevOps. Same concern as #2. NF is defensible since no practical depth shown, but PM could be argued. |
| 9 | Terraform or IaC | T2 | NF | Yes | No mention. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | NF | **Questionable** | Master's in Cloud Computing & DevOps. No hands-on professional experience described. NF is defensible. |
| 11 | PaaS understanding | T2 | NF | Yes | No evidence. |
| 12 | CI/CD pipelines, developer tooling | T2 | PM | Yes | Has CI/CD experience from internship. |
| 13 | Cloud marketplace experience | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid environments | T2 | NF | Yes | No evidence. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | PM | Yes | Has microservices system design but not multi-tenant/multi-region. |
| 16 | Open source / distributed systems | T2 | FM | Yes | Built distributed microservice systems with gRPC, Kafka. Good call. |
| 17 | Monitoring/observability tools | T2 | NF | Yes | No Prometheus/Grafana/ELK mentioned. |

### Issues found

1. **Criterion 7 (Go production experience) -- FM should be PM.** An intern with ~1 month of professional Go experience and personal projects does not constitute "strong programming experience in Go for production backend systems." The reasoning says "professional experience designing and developing RESTful APIs and microservices in Go" but this is a single internship. This is a T1 criterion so the overscoring matters: +6 points that should be +3.
2. **Criterion 2 (Kubernetes + Terraform) -- NF is borderline.** Kubernetes is listed in skills and the candidate has a Master's in Cloud Computing & DevOps. PM might be more appropriate, though NF is defensible since no practical K8s work is described in any role or project.
3. **Criterion 8 (Solid K8s understanding) -- NF is borderline.** Same reasoning as #2.

### Reasoning quality
Reasoning consistently cites specific resume content (internship details, project names, tech stack). Good specificity overall.

**Adjusted score estimate:** If criterion 7 drops to PM: 19/72 = 26.4%. If criteria 2 and 8 are also upgraded to PM: 25/72 = 34.7%.

---

## go-2 (Narendran R) -- 81.9% (59/72)

**Score breakdown:** 12 FM, 3 PM, 2 NF

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Has Go controllers but not full PaaS/scheduler experience. |
| 2 | Kubernetes + Terraform across clouds | T2 | FM | Yes | Extensive K8s + Terraform at Civo, nClouds, Lineten. |
| 3 | Multi-cloud racks/environments | T2 | FM | Yes | Consultant work at nClouds designing multi-tenant AWS EKS platforms. |
| 4 | Collaborate with product/UX teams | T2 | PM | Yes | Strong infra experience but no product/UX collaboration shown. |
| 5 | Reliability/monitoring/alerting/failover | T2 | FM | Yes | SRE roles, Prometheus/Grafana/Thanos, SLOs. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | Senior/consultant role but no explicit mentoring mentioned. |
| 7 | Strong Go production experience | T1 | PM | **Questionable -- possibly too strict** | Resume says "custom Golang controllers" at Lineten for production Kubernetes clusters. The reasoning says "does not provide extensive details on large-scale production backend systems built in Go." The Go usage is real but narrow (K8s controllers, not full backend systems). PM is defensible but could be argued as FM since controllers ARE production Go code managing infrastructure. |
| 8 | Solid K8s understanding | T1 | FM | Yes | Kubestronaut + CKA + CKS + CKAD + KCNA + KCSA. Deep experience. |
| 9 | Terraform or IaC | T2 | FM | Yes | Multi-year Terraform across roles. |
| 10 | Hands-on cloud platforms | T2 | FM | Yes | AWS extensively at nClouds, Alcrowd; Civo cloud at Civo. |
| 11 | PaaS understanding | T2 | FM | Yes | Worked at Civo (a managed K8s/cloud provider). |
| 12 | CI/CD, developer tooling | T2 | FM | Yes | ArgoCD, GitHub Actions, Jenkins-X. |
| 13 | Cloud marketplace | T2 | NF | Yes | No marketplace experience. |
| 14 | Multi-cloud/hybrid, customer-facing | T2 | FM | Yes | Consultant for multiple clients, multi-cloud K8s. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | FM | Yes | Resume explicitly mentions multi-region, multi-tenant, HA. |
| 16 | Open source / distributed systems | T2 | FM | Yes | K8s ecosystem, K3s, extensive distributed systems work. |
| 17 | Monitoring/observability tools | T2 | FM | Yes | Prometheus, Grafana, Thanos, Fluentd, Jaeger, Kiali. |

### Issues found

1. **Criterion 7 (Go production experience) -- PM is borderline.** The candidate built "custom Golang controllers" for production Kubernetes infrastructure. This is production Go code, but it's infrastructure controllers rather than backend API services. PM is technically defensible for the criterion wording ("production backend systems"), since K8s controllers are not typical "backend systems." However, this is a strong candidate being docked on a T1 criterion for a narrow reading.

### Reasoning quality
Reasoning is specific and accurate throughout. Cites roles (Civo, nClouds, Lineten), certifications (Kubestronaut), and specific technologies.

**Assessment: Scoring is accurate. No significant errors.**

---

## go-3 (Kushagra Shukla) -- 51.4% (37/72)

**Score breakdown:** 3 FM, 6 PM, 8 NF

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Go APIs at SWIF.AI and Prometheus contributions, but no PaaS/scheduler. |
| 2 | Kubernetes + Terraform across clouds | T2 | PM | **Questionable -- possibly too strict** | Resume lists Kubernetes, Docker, Terraform, and AWS in skills. At SWIF.AI the tech stack explicitly includes "Kubernetes, Docker." However, no detailed narrative of K8s cluster management or Terraform usage. PM is defensible but the skill listing + tech stack mention is real. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CLI, observability | T2 | PM | Yes | Built CLI tool for Prometheus (promtool), improved observability via Wazuh/Elasticsearch. No UX team collaboration. |
| 5 | Reliability/monitoring/alerting/rollback | T2 | PM | Yes | Prometheus, Grafana experience. No failover strategies. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | CNCF open source PRs (code review inherent), but no mentoring. |
| 7 | Strong Go production experience | T1 | FM | **Questionable** | The candidate worked as "Golang Backend Developer" at SWIF.AI (July-Sep 2025, ~3 months) and contributed to Prometheus open source (Sep-Nov 2024, ~2 months). The Prometheus work is significant (merged PRs to a major Go project), but total Go experience is ~5 months. "Strong programming experience" is a stretch for this tenure. However, the Prometheus contributions are high-quality production Go code. FM is borderline -- could argue PM. |
| 8 | Solid K8s understanding | T1 | PM | Yes | Listed in skills and tech stack but no deep K8s narrative. |
| 9 | Terraform or IaC | T2 | PM | **Questionable -- should this be higher?** | Terraform is listed in skills. But no project/role describes Terraform use. PM for a skill-only listing is fair. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | PM | **Questionable** | AWS is listed in skills. No described professional cloud management experience. PM for a skill listing alone is generous -- NF might be more appropriate since "hands-on experience managing services, network, compute, storage, and security" requires more than a skill listing. |
| 11 | PaaS understanding | T2 | NF | Yes | No evidence. |
| 12 | CI/CD, developer tooling | T2 | FM | Yes | Integrated JUnit test results into promtool for CI. GitHub Actions in skills. |
| 13 | Cloud marketplace | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid, customer-facing | T2 | NF | Yes | No evidence. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | PM | Yes | Prometheus TSDB work touches system design but not multi-region/tenant. |
| 16 | Open source / distributed systems | T2 | FM | Yes | CNCF contributor to Prometheus. Clear FM. |
| 17 | Monitoring/observability tools | T2 | FM | Yes | Prometheus, Grafana explicit in skills and experience. |

### Issues found

1. **Criterion 7 (Go production experience) -- FM is borderline.** ~5 months of Go experience total (3 months at SWIF.AI + 2 months Prometheus open source). The Prometheus contributions are high-quality, but "strong programming experience" usually implies more tenure. FM is generous but defensible given the quality of open-source contributions to a major Go project.
2. **Criterion 10 (Hands-on cloud) -- PM may be too generous.** AWS is listed only as a skill with no described hands-on management. The criterion asks for "managing services, network, compute, storage, and security." A skill listing alone might warrant NF.
3. **Inconsistency with go-1 scoring:** go-1 lists Kubernetes in skills and gets NF for criterion 8. go-3 lists Kubernetes in skills and gets PM for criterion 8. The reasoning for go-3 says "limited to general deployment usage" which is slightly more generous but both are essentially skill-list-only. This is inconsistent.

### Reasoning quality
Reasoning cites specific content (Prometheus PRs, SWIF.AI role, Wazuh integration). Good specificity.

**Adjusted score estimate:** If criterion 10 drops to NF: 35/72 = 48.6%.

---

## go-4 (Ganesh Pawar) -- 54.2% (39/72)

**Score breakdown:** 4 FM, 9 PM, 4 NF

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Extensive Go backend (Patching Management System with Mux, Gin, Chi), but no PaaS. |
| 2 | Kubernetes + Terraform across clouds | T2 | PM | **Possibly too strict** | Resume explicitly lists "Cloud & DevOps: AWS (ECS, S3, Lambda), OpenShift, Kubernetes, Docker." OpenShift is Kubernetes-based. Deployed applications onto OpenShift. No Terraform, but has Ansible. Multi-cloud: "AWS, Azure, and GCP" in profile. The reasoning says "no mention of Terraform" but there IS Kubernetes experience through OpenShift deployments. Could argue FM for the K8s half at least. |
| 3 | Multi-cloud racks/environments | T2 | NF | **Questionable** | Profile says "AWS, Azure, and GCP" experience. Work at NTT Data (Citi Group) likely involves enterprise multi-environment setups. eShipz work is customer-facing. But no explicit multi-cloud architecture described. NF is defensible. |
| 4 | Collaborate with product/UX, CLI, CI/CD, observability | T2 | PM | Yes | Strong CI/CD (Jenkins, Harness, Tekton) and observability (Splunk). No UX team collaboration or CLI work. |
| 5 | Reliability/monitoring/alerting/rollback | T2 | PM | **Possibly too strict** | Resume describes: Splunk logging for "performance monitoring and rapid issue resolution," "system responsiveness and stability under pressure," proactive bug fixing for "stability, reliability, and maintainability." Has monitoring (Splunk, Prometheus, Grafana in skills), automated deployments via Harness/Tekton (implies rollback capability). No multi-cloud failover. This is close to FM -- the candidate has monitoring, logging, and deployment automation. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | Senior role but no explicit mentoring/best practices. |
| 7 | Strong Go production experience | T1 | FM | Yes | Golang (Mux, Gin, Chi) for the enterprise Patching Management System at Citi Group. Concurrency features for high-volume loads. 4+ years at NTT Data. Clear FM. |
| 8 | Solid K8s understanding | T1 | PM | **Possibly too strict** | Deployed production applications on OpenShift (which is Kubernetes). "Orchestrated the successful deployment of the application onto OpenShift, ensuring a scalable, resilient, and efficiently containerized environment." Lists Kubernetes explicitly in skills alongside OpenShift. PM may undervalue this -- OpenShift IS Kubernetes with enterprise features. The reasoning says "does not demonstrate deep knowledge of cluster design or service mesh" which is fair, but this is closer to FM than NF. PM is defensible. |
| 9 | Terraform or IaC | T2 | PM | Yes | Ansible is an automation/IaC tool. Built custom SDK for Ansible Automation Platform. No Terraform. PM for "similar IaC tool" is correct. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | FM | Yes | "AWS (ECS, S3, Lambda)" explicit. OpenShift deployments. IBM S3 storage. |
| 11 | PaaS understanding | T2 | NF | **Questionable** | OpenShift is essentially a PaaS that abstracts infrastructure for developers while giving control. The candidate deployed production applications on OpenShift and understands containerized deployment workflows. This demonstrates practical PaaS usage. PM might be more appropriate. |
| 12 | CI/CD, developer tooling | T2 | FM | Yes | Jenkins, Harness, Tekton pipelines. Custom Ansible SDK. |
| 13 | Cloud marketplace | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid, customer-facing | T2 | PM | Yes | Works for NTT Data serving Citi Group (customer-facing). Lists AWS, Azure, GCP. But no explicit multi-cloud architecture. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | PM | Yes | Distributed microservices, high-volume systems. No multi-region/tenant. |
| 16 | Open source / distributed systems | T2 | PM | **Possibly too strict** | "Leading strategic migrations from monolithic systems to modern, distributed microservices-based applications." Kafka and TIBCO for event-driven architecture. This IS distributed systems experience. The reasoning says "mentions leading migrations to distributed microservices-based applications, but does not provide evidence of involvement in open-source projects." The criterion is "open source projects OR distributed systems" -- the OR is key. Distributed systems experience alone should satisfy this. FM would be more appropriate. |
| 17 | Monitoring/observability tools | T2 | FM | Yes | Splunk, Prometheus, Grafana explicitly listed. Splunk integration described in detail. |

### Issues found

1. **Criterion 16 (Open source OR distributed systems) -- PM should be FM.** The criterion says "open source projects **or** distributed systems." The candidate has clear distributed systems experience (Kafka, TIBCO, microservices migrations). The model scored PM because no open-source involvement, but the "or" means distributed systems alone qualifies. This is a false negative. +2 points (PM->FM).
2. **Criterion 11 (PaaS understanding) -- NF should be PM.** OpenShift is a PaaS/container platform. The candidate deployed and managed production applications on OpenShift. This demonstrates practical understanding of platform abstraction even if not explicitly stated as PaaS knowledge. +2 points (NF->PM).
3. **Criterion 5 (Reliability/monitoring/alerting) -- PM is borderline.** Splunk monitoring integration, Prometheus/Grafana in skills, automated deployment pipelines (Harness/Tekton). Missing only multi-cloud failover from the criterion list. Could argue FM.
4. **Criterion 8 (Solid K8s understanding) -- PM is defensible but conservative.** OpenShift IS Kubernetes. Deployed production apps on it. But no cluster design or service mesh depth shown.

### Reasoning quality
Reasoning is specific and cites technologies (Mux, Gin, Chi, Splunk, OpenShift, Tekton). Good quality overall. The main issue is the OR-logic miss on criterion 16 and undervaluing OpenShift as Kubernetes/PaaS.

**Adjusted score estimate:** If criterion 16 goes to FM and criterion 11 goes to PM: 43/72 = 59.7%.

---

## go-5 (Nishant) -- 30.6% (22/72)

**Score breakdown:** 2 FM, 5 PM, 10 NF

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | ETL pipeline, API middleware, load balancer in Go. No PaaS. |
| 2 | Kubernetes + Terraform across clouds | T2 | NF | **Questionable** | Resume mentions Docker in skills. Also "Exploring: Rust, Juju (Canonical orchestration)" and "Contributed to a Go-based NDA project using Canonical Juju for distributed PostgreSQL clustering." Juju is an orchestration tool (similar conceptual space to K8s for application deployment). However, no Kubernetes or Terraform. NF is defensible -- Juju is not K8s, and Docker alone doesn't meet this criterion. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CLI, CI/CD, observability | T2 | PM | Yes | Built DebForge CLI tool. No UX team or CI/CD pipeline work. |
| 5 | Reliability/monitoring/alerting/rollback | T2 | PM | **Possibly too generous** | The reasoning says "experience with security (RBAC) and performance (load balancer benchmarking)." The criterion asks for monitoring, logging, alerting, rollback, failover. The candidate has none of these. RBAC is access control, not reliability monitoring. Load balancer benchmarking is performance testing, not operational monitoring. NF might be more appropriate. |
| 6 | Code reviews/mentoring/best practices | T2 | NF | Yes | No evidence. |
| 7 | Strong Go production experience | T1 | FM | **Questionable** | The candidate's Go experience: internship (Jan-Apr 2025, 4 months) + full-time (May 2025-Present, ~1 month). Total ~5 months, mostly at a single company (Udyansh). Projects include ETL pipeline (1K daily events), EagleOwl web app, BalancerX load balancer. The ETL pipeline and Go backend work is real, but "strong programming experience in Go for production backend systems" is generous for ~5 months at one company. Comparable to go-1 and go-3 who also got FM with limited tenure. PM might be more appropriate for all three. |
| 8 | Solid K8s understanding | T1 | NF | Yes | No Kubernetes experience. |
| 9 | Terraform or IaC | T2 | PM | Yes | Ansible listed in skills. "Similar IaC tool" applies. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | NF | Yes | No cloud platform management described. Google OAuth is not cloud infrastructure. |
| 11 | PaaS understanding | T2 | NF | Yes | No evidence. |
| 12 | CI/CD, developer tooling | T2 | PM | **Possibly too generous** | The reasoning says "experience with developer tooling (DebForge CLI) and basic deployment guides." DebForge is a Debian package builder -- it's a dev tool but not CI/CD or cloud integrations. Deployment guides are documentation, not pipeline work. NF might be more appropriate for the CI/CD part, though developer tooling is present via DebForge. PM is borderline. |
| 13 | Cloud marketplace | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid, customer-facing | T2 | NF | Yes | No evidence. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | PM | Yes | Load balancer and distributed ETL show system design. No multi-region/tenant. |
| 16 | Open source / distributed systems | T2 | FM | Yes | Distributed Go ETL pipeline, open-source tool contributions. |
| 17 | Monitoring/observability tools | T2 | NF | Yes | No Prometheus/Grafana/ELK. |

### Issues found

1. **Criterion 7 (Go production experience) -- FM is generous.** ~5 months total Go experience at one company. The ETL pipeline and projects are real Go work, but the criterion says "strong programming experience" which implies depth and tenure. Same issue as go-1 and go-3. PM would be more appropriate.
2. **Criterion 5 (Reliability/monitoring) -- PM may be too generous.** RBAC and load balancer benchmarking do not address the criterion's specific asks (monitoring, logging, alerting, rollback, failover). NF might be more appropriate.
3. **Criterion 12 (CI/CD, developer tooling) -- PM is borderline.** DebForge is developer tooling (Debian package builder), which partly satisfies this. But no CI/CD pipeline experience. The criterion asks for both. PM is generous but defensible for the developer tooling half.

### Reasoning quality
Reasoning cites specific projects (DebForge, ETL pipeline, EagleOwl, BalancerX). Good specificity. The main issue is leniency on criterion 7 (FM for limited tenure) and inconsistency between this and other resumes.

**Adjusted score estimate:** If criterion 7 drops to PM and criterion 5 drops to NF: 17/72 = 23.6%.

---

## Cross-Resume Consistency Issues

### 1. Go production experience (T1) -- inconsistent FM threshold

All three junior candidates (go-1, go-3, go-5) received FM for "Strong programming experience in Go for production backend systems" despite having limited tenure:

| Candidate | Go tenure | FM justified? |
|---|---|---|
| go-1 (Abhishek) | ~1 month internship | No -- too generous |
| go-3 (Kushagra) | ~5 months (3 mo job + 2 mo Prometheus OSS) | Borderline -- Prometheus contributions are high quality |
| go-4 (Ganesh) | 4+ years at NTT Data | Yes -- clear FM |
| go-5 (Nishant) | ~5 months at one company | No -- too generous |

go-1 especially should not be FM -- one month of intern-level Go is not "strong production experience."

### 2. Kubernetes skill listing -- inconsistent treatment

| Candidate | K8s evidence | Score for K8s criterion | Consistent? |
|---|---|---|---|
| go-1 | Listed in skills only | NF | - |
| go-3 | Listed in skills + tech stack | PM | Inconsistent with go-1 |
| go-4 | OpenShift (=K8s) deployments, K8s in skills | PM | Consistent |
| go-5 | Not listed | NF | Consistent |

go-1 and go-3 have similar K8s evidence (skill listing) but received different scores.

### 3. "OR" criteria not properly handled

Criterion 16 says "open source projects **or** distributed systems." go-4 was scored PM because no open-source involvement, despite having clear distributed systems experience (Kafka, TIBCO, microservices). The model treated this as requiring BOTH instead of EITHER.

### 4. OpenShift undervalued as Kubernetes/PaaS

go-4 deployed production applications on OpenShift (which is Red Hat's Kubernetes distribution and a PaaS). The model did not fully credit this as Kubernetes experience (PM instead of closer to FM) or PaaS understanding (NF instead of PM).

---

## Summary of Recommended Score Adjustments

| Candidate | Current | Key adjustments | Estimated corrected |
|---|---|---|---|
| go-1 | 30.6% | Criterion 7 FM->PM (-3 pts) | ~26% |
| go-2 | 81.9% | No significant errors | ~82% |
| go-3 | 51.4% | Criterion 10 PM->NF (-2 pts); criterion 7 borderline | ~49% |
| go-4 | 54.2% | Criterion 16 PM->FM (+2), criterion 11 NF->PM (+2) | ~60% |
| go-5 | 30.6% | Criterion 7 FM->PM (-3), criterion 5 PM->NF (-2) | ~24% |

### Overall model tendencies

1. **Too generous on "Strong Go experience" for junior candidates.** The model awards FM to candidates with a few months of Go experience. This T1 criterion (6 pts for FM) has outsized impact on scores.
2. **Too strict on Kubernetes for candidates with OpenShift.** OpenShift IS Kubernetes. Production OpenShift deployment should count as Kubernetes experience.
3. **OR-logic failures.** When a criterion says "X or Y," the model sometimes requires both.
4. **Skill-listing inconsistency.** Sometimes a technology listed in skills without project evidence gets PM, sometimes NF. There is no consistent rule.
5. **Reasoning quality is generally good.** Most scores cite specific resume content. The errors are in judgment calls (thresholds, OR logic) rather than hallucinations or missed content.
