# Go Backend Engineer -- Suspicious Score Evaluation (v1)

Evaluation of 4 candidates flagged for suspicious scores. Each criterion scored as full_match (FM=6pts T1/4pts T2), partial_match (PM=3pts T1/2pts T2), or not_found (NF=0pts). Max score = 72.

---

## go-11 (Abdulrahman) -- 69.4% (50/72)

**Score breakdown:** 8 FM, 6 PM, 3 NF

**Concern:** Scored very high relative to pool. Check if all FMs are justified.

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Go backend at MinIO but not PaaS-specific. PM is fair. |
| 2 | Kubernetes + Terraform across clouds | T2 | PM | Yes | K8s and Terraform listed in skills, K8s deployment patterns at MinIO, but no multi-cloud. PM is fair. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CI/CD, observability | T2 | PM | Yes | CI/CD and tooling experience but no product/UX collaboration. |
| 5 | Reliability/monitoring/alerting/failover | T2 | PM | Yes | Strong on monitoring/alerting, missing multi-cloud failover. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | Lead title implies mentoring but not explicit. |
| 7 | Strong Go production experience | T1 | FM | Yes | ~2 years at MinIO developing/optimizing Go backend services for distributed object storage handling millions of daily requests. This is genuine production Go at scale. FM is well-justified. |
| 8 | Solid Kubernetes understanding | T1 | FM | **Too generous -- should be PM** | Resume lists K8s skills (deployments, autoscaling, cluster management) and mentions "stateful workload challenges." But the MinIO description says "Collaborated with infrastructure teams on Kubernetes deployment patterns and cluster management strategies" -- this is collaboration/exposure, not hands-on cluster design. No mention of service mesh, networking, or designing cluster architectures. The criterion asks for "solid understanding including cluster design, deployments, autoscaling, service mesh or networking, and stateful vs stateless workloads." Listing skills and collaborating does not demonstrate the depth required for FM on a T1 criterion. |
| 9 | Terraform or IaC | T2 | FM | **Too generous -- should be PM** | Terraform is listed in the skills section, but no role description mentions using Terraform in practice. The criterion says "Experience working with Terraform or a similar IaC tool to define and manage infrastructure." A skills-list mention without any described usage is PM at best ("Infrastructure as code (IaC)" is also listed generically). No project, role, or achievement references Terraform or IaC work. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | FM | Yes | AWS services (EC2, ECS, S3, VPC, IAM) explicitly listed and cloud infrastructure work described at multiple roles. |
| 11 | PaaS understanding | T2 | PM | Yes | No direct PaaS experience. Internal tooling and cloud deployment workflows are adjacent. |
| 12 | CI/CD pipelines, developer tooling | T2 | FM | **Borderline -- defensible** | "Implemented CI/CD pipelines for automated testing and deployment" at Eduvacity. The criterion also mentions "marketplace or cloud provider integrations" -- no marketplace evidence. But CI/CD + developer tooling is enough for FM since the criterion says "some exposure to marketplace" (i.e., marketplace is additive, not required). Keeping FM. |
| 13 | Cloud marketplace experience | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid environments | T2 | PM | **Too generous -- should be NF** | The reasoning says "experience with distributed storage at MinIO involves complex deployments" but this is not multi-cloud or hybrid-cloud work. MinIO is a single distributed storage system. The criterion asks for "multi cloud or hybrid cloud environments or customer facing deployment scenarios." Working on a distributed storage product does not equate to deploying across multiple clouds or managing customer-facing deployments. The resume shows only AWS experience with no evidence of multi-cloud or customer-account deployments. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | FM | **Too generous -- should be PM** | The reasoning cites "distributed systems at MinIO and high-concurrency platforms at Eduvacity." MinIO distributed storage demonstrates HA thinking, and Eduvacity (50K concurrent users) shows concurrency. But neither explicitly demonstrates multi-region or multi-tenant architecture design. The criterion specifically names "multi region, and multi tenant" -- these are distinct architectural patterns (data partitioning, regional failover, tenant isolation) not evidenced in the resume. PM for HA experience without the multi-region/multi-tenant specifics. |
| 16 | Open source / distributed systems | T2 | FM | Yes | MinIO is a major open-source distributed object storage project. Clear match. |
| 17 | Monitoring/observability tools | T2 | FM | Yes | "Designed and implemented comprehensive Prometheus metrics" at MinIO. Explicit and specific. |

### Issues found

1. **Criterion 8 (Solid K8s understanding) -- FM should be PM.** Collaboration on K8s deployment patterns and listing K8s skills does not demonstrate the depth (cluster design, service mesh, networking) required for FM on a T1 criterion. Impact: -3 points (6->3).
2. **Criterion 9 (Terraform/IaC) -- FM should be PM.** Terraform appears only in the skills list with no described usage in any role. Impact: -2 points (4->2).
3. **Criterion 14 (Multi-cloud/hybrid) -- PM should be NF.** Working on MinIO's distributed storage is not multi-cloud/hybrid-cloud deployment experience. Impact: -2 points (2->0).
4. **Criterion 15 (HA/multi-region/multi-tenant) -- FM should be PM.** HA/concurrency experience shown but no multi-region or multi-tenant architecture evidence. Impact: -2 points (4->2).

### Assessment

**Current score:** 50/72 = 69.4%
**Adjusted score:** 41/72 = 56.9%
**Verdict: Overscore by ~12.5 percentage points.** The model inflated this candidate by awarding FM for skills-list-only mentions (Terraform, K8s depth) and stretching "distributed storage" to cover multi-cloud and multi-tenant architecture. The core Go experience at MinIO is genuinely strong and correctly scored, but surrounding infrastructure criteria were graded too generously. The candidate is still a solid match -- just not a 69% match.

---

## go-13 (Milan Stankovic) -- 27.8% (20/72)

**Score breakdown:** 2 FM, 4 PM, 11 NF

**Concern:** Scored very low. Check for false negatives.

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Go backend at Vroom and Baltic defense. Not PaaS-specific. PM is fair. |
| 2 | Kubernetes + Terraform across clouds | T2 | NF | Yes | No K8s or Terraform mentioned anywhere. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CLI, CI/CD, observability | T2 | NF | Yes | No evidence of product/UX collaboration, CLI work, or CI/CD. |
| 5 | Reliability/monitoring/alerting/failover | T2 | PM | **Too generous -- should be NF** | The reasoning says "experience with SCADA systems and distributed systems which involve monitoring." SCADA experience was from 2010-2011 (15 years ago) doing embedded monitoring of fire elements in buildings -- this is industrial control, not cloud-native reliability/observability. The resume shows no cloud monitoring, alerting, rollback, or failover experience. The SCADA work is too distant in time and domain to justify PM for this cloud-platform-focused criterion. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | **Too generous -- should be NF** | The reasoning says "extensive tenure as a Software Engineer implies code reviews and team collaboration." Implication from tenure is not evidence. The resume describes no mentoring, no code review participation, and no best practices definition. Every developer participates in code reviews -- the criterion is about whether the candidate can "help define best practices for backend infrastructure, Go services, and cloud deployments," and there is zero evidence of this. |
| 7 | Strong Go production experience | T1 | FM | **Borderline -- defensible but generous** | Go is listed as a skill. At Vroom (Apr 2021 - Jan 2025, ~4 years), Go is listed as a technology. At Baltic defense (Apr 2015 - Jun 2017, ~2 years), Go is listed for game server backend work. However, the Vroom description is extremely thin: "Maintaining and further development of microservices" with Go listed among Java, Kafka, Postgres, Redis. It is unclear whether Go was a primary or secondary language at Vroom. Baltic defense used Go for game server backends alongside Java. The total potential Go experience is substantial (up to ~6 years), but the resume provides almost no detail about what was built in Go specifically. FM is generous but defensible given the multi-year timeline and production context. |
| 8 | Solid Kubernetes understanding | T1 | NF | Yes | Not mentioned. |
| 9 | Terraform or IaC | T2 | NF | Yes | Not mentioned. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | PM | Yes | AWS listed at Vroom and BVNK but no detail on which services managed. PM is fair. |
| 11 | PaaS understanding | T2 | NF | Yes | No evidence. |
| 12 | CI/CD pipelines, developer tooling | T2 | NF | Yes | No mention. |
| 13 | Cloud marketplace experience | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid environments | T2 | NF | Yes | No evidence. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | PM | **Too generous -- should be NF** | The reasoning says "worked on distributed systems at BVNK and Vroom, which generally involves high availability design." The resume descriptions for both roles are one-liners ("Maintaining and further development of microservices"). No system design, HA, multi-region, or multi-tenant work is described. "Working on microservices generally involves HA" is an assumption, not evidence. |
| 16 | Open source / distributed systems | T2 | FM | **Borderline -- defensible but generous** | The reasoning says "explicitly mentions maintaining microservices and distributed systems." The BVNK description says "Maintaining and further development of microservices and distributed systems." The criterion asks for "experience with open source projects or distributed systems." Distributed systems is mentioned, so technically this matches. However, the description is so thin that we cannot verify depth -- "maintaining" a distributed system could mean anything. FM is technically correct based on the text but the evidence is minimal. Keeping FM since the criterion is satisfied by the literal text. |
| 17 | Monitoring/observability tools | T2 | NF | Yes | No Prometheus/Grafana/ELK mentioned. |

### Issues found

1. **Criterion 5 (Reliability/monitoring/alerting) -- PM should be NF.** 15-year-old SCADA monitoring experience is not relevant to cloud-platform reliability. Impact: -2 points (2->0).
2. **Criterion 6 (Code reviews/mentoring) -- PM should be NF.** No evidence beyond "tenure implies it." Impact: -2 points (2->0).
3. **Criterion 15 (HA/multi-region/multi-tenant) -- PM should be NF.** One-liner microservices descriptions do not evidence system design for HA/multi-region/multi-tenant. Impact: -2 points (2->0).

### Assessment

**Current score:** 20/72 = 27.8%
**Adjusted score:** 14/72 = 19.4%
**Verdict: Slightly overscored, not underscored.** Contrary to the concern about false negatives, this candidate has 3 false positives (PMs given without evidence). There are no false negatives -- the NFs are all correctly assigned. The low score accurately reflects a resume that lists Go and microservices/distributed systems as technologies but provides almost no detail about what was actually built, designed, or achieved. The resume is unusually thin on descriptions for a 15-year career. The real score should be even lower at ~19%.

---

## go-14 (Ohm Patel) -- 38.9% (28/72)

**Score breakdown:** 3 FM, 6 PM, 8 NF

**Concern:** Scored higher than expected. Check for false positives.

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | PM | Yes | Go backend at Solid I (founding engineer). Not PaaS-specific but clear backend Go. |
| 2 | Kubernetes + Terraform across clouds | T2 | NF | Yes | No mention of K8s or Terraform. |
| 3 | Multi-cloud racks/environments | T2 | NF | Yes | No evidence. |
| 4 | Collaborate with product/UX, CI/CD, observability | T2 | PM | **Too generous -- should be NF** | The reasoning says "collaborated with cross-functional teams to deliver features, but these were user-facing product features rather than developer-focused tools." The criterion specifically asks for developer-facing feature delivery (CLI, CI/CD, observability, marketplace). The candidate delivered user-facing product features (ads, food delivery, fintech). This is a different audience entirely. Cross-functional collaboration on product features does not match collaboration on developer tooling. |
| 5 | Reliability/monitoring/alerting/failover | T2 | PM | Yes | Uptime metrics (99.03%, 99.16% at Deliveroo), scaling work. Missing alerting/rollback/failover specifics. PM is fair. |
| 6 | Code reviews/mentoring/best practices | T2 | PM | **Borderline -- defensible** | Founding Engineer and Lead roles imply leadership. The reasoning correctly notes no explicit evidence. PM is generous but the leadership titles are real. Keeping PM. |
| 7 | Strong Go production experience | T1 | FM | **Too generous -- should be PM** | The reasoning says "lists Go in their tech stack for Solid I and demonstrates extensive experience with high-scale backend systems in other roles." The problem: only Solid I lists Go explicitly ("Tech stack used: Go, Typescript, Postgres, SQS, QLDB, AWS"). The "extensive experience with high-scale backend systems in other roles" was NOT in Go -- Reddit was Python/gRPC/Thrift, Deliveroo used Kafka/Snowflake (no language specified), Coinbase does not specify language. The resume shows Go at exactly one role (Solid I, ~15 months as a founding engineer at an early-stage startup). "Strong programming experience in Go for production backend systems" requires more than 15 months at a startup. PM is more appropriate. |
| 8 | Solid Kubernetes understanding | T1 | NF | Yes | Not mentioned. |
| 9 | Terraform or IaC | T2 | NF | Yes | Not mentioned. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | PM | Yes | AWS listed at Solid I with specific services (SQS, QLDB). No detailed service management described. |
| 11 | PaaS understanding | T2 | NF | Yes | No evidence. |
| 12 | CI/CD pipelines, developer tooling | T2 | PM | **Too generous -- should be NF** | The reasoning says "experience with system integration and pipeline work (e.g., Ad delivery pipeline)." An Ad delivery pipeline is a data/content pipeline, not a CI/CD pipeline. The criterion asks for "CI/CD pipelines, developer tooling, and some exposure to marketplace or cloud provider integrations." The candidate has zero CI/CD, zero developer tooling, zero marketplace integration evidence. Calling a product ad pipeline "pipeline work" to justify PM on a CI/CD criterion is a false positive. |
| 13 | Cloud marketplace experience | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid environments | T2 | PM | **Too generous -- should be NF** | The reasoning says "Experience with Deliveroo's integrations involved complex external interactions, though not explicitly multi-cloud architecture." Integrating with McDonald's POS systems via Kafka is application integration, not multi-cloud/hybrid-cloud deployment. The criterion asks about "multi cloud or hybrid cloud environments or customer facing deployment scenarios." Restaurant POS integration is not cloud deployment into customer accounts. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | FM | **Borderline -- defensible** | The resume shows genuinely impressive scale: Deliveroo order systems (95K orders/day, 99.03% uptime), Coinbase node scaling (4x transaction load), Reddit ad pipeline (25M products). This demonstrates HA design. Multi-region is not explicitly stated but Deliveroo operated worldwide (UK, global McDonald's). Multi-tenant is not explicitly stated. FM is generous but the scale evidence is strong. Keeping FM but noting it is at the upper bound. |
| 16 | Open source / distributed systems | T2 | FM | Yes | YourStorage built on IPFS (open source/decentralized), Coinbase blockchain infrastructure. Both are distributed systems. Clear match. |
| 17 | Monitoring/observability tools | T2 | NF | Yes | No specific tools mentioned. |

### Issues found

1. **Criterion 7 (Strong Go production experience) -- FM should be PM.** Go confirmed at only one role (Solid I, ~15 months). Other high-scale experience was in different languages. Impact: -3 points (6->3).
2. **Criterion 4 (Collaborate product/UX, developer tooling) -- PM should be NF.** Cross-functional collaboration on user-facing products is not developer tooling collaboration. Impact: -2 points (2->0).
3. **Criterion 12 (CI/CD pipelines, developer tooling) -- PM should be NF.** Ad delivery pipeline is not CI/CD. No developer tooling evidence. Impact: -2 points (2->0).
4. **Criterion 14 (Multi-cloud/hybrid) -- PM should be NF.** Restaurant POS integration is not multi-cloud deployment. Impact: -2 points (2->0).

### Assessment

**Current score:** 28/72 = 38.9%
**Adjusted score:** 19/72 = 26.4%
**Verdict: Overscore by ~12.5 percentage points.** The model committed multiple false positives: inflating Go experience from one startup role to FM, conflating product ad pipelines with CI/CD, and treating restaurant POS integration as multi-cloud deployment. The candidate has impressive backend engineering experience at scale (Reddit, Deliveroo, Coinbase) but very little of it is in Go or in the infrastructure/platform engineering domain this role requires. True score is closer to 26%.

---

## go-18 (William Morris) -- 58.3% (42/72)

**Score breakdown:** 6 FM, 6 PM, 5 NF

**Concern:** Scored surprisingly high. Check if all FMs are justified -- candidate may have strong cloud/infra resume that inflates score despite no Go.

### Criterion-by-criterion review

| # | Criterion (abbreviated) | Tier | Given | Correct? | Notes |
|---|---|---|---|---|---|
| 1 | Backend services in Go / PaaS / APIs / scheduler | T2 | NF | Yes | No Go experience. Correctly scored. |
| 2 | Kubernetes + Terraform across clouds | T2 | PM | Yes | K8s experience (AKS + Helm + Istio) but no Terraform by name, only "infrastructure as code." No multi-cloud K8s. PM is fair. |
| 3 | Multi-cloud racks/environments | T2 | PM | **Too generous -- should be NF** | The reasoning says "experience deploying applications in cloud environments (Azure, AWS)." Having both Azure and AWS in your skill set does not mean you've architected multi-cloud deployments or managed customer-facing deployment environments. The Azure experience is deep (described in work history), but AWS is only in the skills list. The criterion asks about architecting/deploying/maintaining multi-cloud racks and environments -- this candidate deployed on Azure. Listing AWS as a skill is not multi-cloud rack management. |
| 4 | Collaborate with product/UX, CI/CD, observability | T2 | PM | Yes | CI/CD automation (Azure DevOps, GitHub Actions) and "collaborated with compliance, design, and product teams." PM is fair. |
| 5 | Reliability/monitoring/alerting/failover | T2 | FM | **Too generous -- should be PM** | The reasoning cites "telemetry-driven rollback, CI/CD automation, and implementing security/logging/monitoring." The resume says "telemetry-driven rollback" which is one element. But the criterion asks for monitoring + logging + alerting + rollback + multi-cloud failover. There is no evidence of alerting systems, no monitoring tool implementation (Prometheus/Grafana/etc.), and no multi-cloud failover strategies. "Real-time analytics dashboards" is application-level analytics, not platform monitoring. PM for partial coverage (rollback, general security/logging). |
| 6 | Code reviews/mentoring/best practices | T2 | PM | Yes | Senior SWE role implies code reviews and mentoring but not explicitly stated for Go/infra. |
| 7 | Strong Go production experience | T1 | NF | Yes | No Go anywhere on resume. Correctly scored. |
| 8 | Solid Kubernetes understanding | T1 | FM | **Borderline -- defensible** | "Migrating monolithic .NET Framework apps into microservices on Azure Kubernetes Service (AKS) with Helm and Istio, reducing latency by 30%." Also at AT&T: "Built distributed microservices with Docker and Kubernetes, leveraging Istio/Linkerd." This demonstrates deployments, service mesh (Istio, Linkerd), and migration to K8s. Missing: autoscaling, cluster design from scratch, stateful vs stateless workload discussion. But the depth shown (Helm charts, service mesh, production migrations) is substantial. FM is at the generous end but defensible. Keeping FM. |
| 9 | Terraform or IaC | T2 | PM | Yes | "Implementing infrastructure as code" but no specific tool named. PM is fair. |
| 10 | Hands-on cloud (AWS/GCP/Azure) | T2 | FM | Yes | Extensive Azure experience described across Microsoft role. AWS certified. FM is justified. |
| 11 | PaaS understanding | T2 | PM | Yes | Work with microservices, containers, CI/CD shows platform-level thinking but no direct PaaS product experience. |
| 12 | CI/CD pipelines, developer tooling | T2 | FM | Yes | "Automated CI/CD pipelines with Azure DevOps and GitHub Actions, implementing infrastructure as code, gated deployments, and telemetry-driven rollback." Specific tools, specific practices. FM is well-justified. |
| 13 | Cloud marketplace experience | T2 | NF | Yes | No evidence. |
| 14 | Multi-cloud/hybrid environments | T2 | PM | **Too generous -- should be NF** | Same issue as criterion 3. The reasoning says "primary experience is focused on Azure and internal/subscriber-facing services rather than multi-cloud infrastructure." If it is focused on Azure and NOT multi-cloud, that is NF, not PM. Building customer-facing digital platforms for AT&T subscribers is not "customer facing deployment scenarios" in the infrastructure sense (deploying into customer cloud accounts). The criterion is about multi-cloud/hybrid infrastructure deployment, not serving end users. |
| 15 | System design: HA, multi-region, multi-tenant | T2 | FM | **Too generous -- should be PM** | The reasoning cites "database sharding, microservices, and distributed messaging, typical of high-availability architectures." These are good indicators of HA design. But "typical of" is an inference, and the resume never describes multi-region or multi-tenant architecture. Database sharding is a scaling technique, not inherently multi-region. Kafka event streaming is distributed but not described in a multi-region context. PM for HA indicators without explicit multi-region/multi-tenant evidence. |
| 16 | Open source / distributed systems | T2 | FM | **Borderline -- defensible** | "Built distributed microservices with Docker and Kubernetes." The criterion asks for "open source projects OR distributed systems." The candidate built distributed systems. No open source contribution is evidenced, but the OR clause means distributed systems alone qualifies. FM is justified by the text, though the distributed systems are application-level (microservices) rather than infrastructure-level. Keeping FM. |
| 17 | Monitoring/observability tools | T2 | PM | Yes | "Real-time analytics and monitoring" mentioned but no specific tools (Prometheus, Grafana, ELK). PM is fair. |

### Issues found

1. **Criterion 3 (Multi-cloud racks/environments) -- PM should be NF.** Azure experience + AWS in skills list is not multi-cloud rack architecture. Impact: -2 points (2->0).
2. **Criterion 5 (Reliability/monitoring/alerting/failover) -- FM should be PM.** Has rollback and general security/logging but missing alerting, monitoring tools, and multi-cloud failover. Impact: -2 points (4->2).
3. **Criterion 14 (Multi-cloud/hybrid) -- PM should be NF.** Single-cloud (Azure) experience. AT&T subscriber platforms are not customer-facing infrastructure deployments. Impact: -2 points (2->0).
4. **Criterion 15 (HA/multi-region/multi-tenant) -- FM should be PM.** HA indicators present but no multi-region or multi-tenant evidence. Impact: -2 points (4->2).

### Assessment

**Current score:** 42/72 = 58.3%
**Adjusted score:** 34/72 = 47.2%
**Verdict: Overscore by ~11 percentage points.** The candidate has a legitimately strong cloud infrastructure resume (K8s with service mesh, extensive Azure, CI/CD automation) which is correctly captured. However, the model inflated the score in two ways: (1) treating Azure-primary experience as multi-cloud for criteria 3 and 14, and (2) inferring multi-region/multi-tenant architecture from general scaling patterns. The adjusted 47% still reflects a candidate with genuine infrastructure depth -- just not one with Go experience (which is the T1 requirement for this role).

**Key observation:** This candidate scores 0 on the T1 Go criterion (#7, worth 6 pts) and still reaches 58%. The scoring system allows strong infrastructure experience to compensate substantially for missing the primary language requirement. At the adjusted 47%, the missing Go still allows a score higher than some candidates who have Go but lack infrastructure depth.

---

## Cross-candidate summary

| Candidate | Current | Adjusted | Delta | Direction |
|---|---|---|---|---|
| go-11 (Abdulrahman) | 69.4% | 56.9% | -12.5 | Overscored |
| go-13 (Milan) | 27.8% | 19.4% | -8.4 | Overscored (not underscored) |
| go-14 (Ohm Patel) | 38.9% | 26.4% | -12.5 | Overscored |
| go-18 (William Morris) | 58.3% | 47.2% | -11.1 | Overscored |

### Systematic patterns observed

1. **Skills-list inflation (criteria 8, 9 on go-11).** Listing a technology in a skills section without describing its use in any role is treated as FM. This is a recurring model tendency -- skills lists should cap at PM unless corroborated by role descriptions.

2. **Multi-cloud/multi-region/multi-tenant overreach (criteria 3, 14, 15 across all candidates).** The model consistently stretches single-cloud experience, application-level integrations, and general scaling work to cover multi-cloud and multi-tenant criteria. This pattern appeared on 3 of 4 candidates:
   - go-11: MinIO distributed storage treated as multi-cloud
   - go-14: Deliveroo restaurant POS integration treated as multi-cloud
   - go-18: Azure + AWS-skills-list treated as multi-cloud

3. **Pipeline type confusion (criterion 12 on go-14).** An ad delivery pipeline was conflated with CI/CD pipelines. "Pipeline" is a generic term; the criterion specifically means build/deploy automation pipelines.

4. **Tenure-implies-skills fallacy (criteria 5, 6 on go-13).** Long tenure is used as evidence for code reviews, mentoring, and monitoring experience, despite no explicit evidence. This inflates thin resumes.

5. **Go experience inflation (criterion 7 on go-14).** Go at one startup role (~15 months) was scored FM for "strong production Go experience." The model cited the candidate's other roles (Reddit, Deliveroo) as supporting evidence, but those roles used different languages.
