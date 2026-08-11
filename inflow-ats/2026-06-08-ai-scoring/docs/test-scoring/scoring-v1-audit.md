# Scoring v1 Audit: Criterion-Level Diff Analysis

Comparing v3 (no expansions) vs scoring-v1 (with expansion-v5 brainstormed examples).
For each changed criterion: was the change an improvement or a regression against the actual resume text?

---

## Resume #20: Mohamed Ali Dhouib (IT Project Manager)

**Eyeball: 3 | v3: 54.3% | sv1: 66.0% | Delta: +11.7% WORSE**

Resume summary: 10 years as IT project manager. Scrum Master certified. Roles at Econocom (IT PM), Codit Up (IT PM), HPE (support engineer). All work is IT infrastructure/project management. No customer service management experience. Used Salesforce, Excel, PowerPoint. Wrote user guides and ran training sessions for IT project rollouts. Managed support teams at HPE doing hardware/software troubleshooting.

| Criterion | Tier | v3 Score | sv1 Score | Changed? | Correct? | Analysis |
|-----------|------|----------|-----------|----------|----------|----------|
| Develop and implement customer service policies and procedures | tier_2 | not_found | **partial** | YES | **REGRESSION** | sv1 reasoning: "experience in project management and defining operational processes, such as on-boarding/off-boarding workflows." These are IT HR workflows (employee onboarding), not customer service policies. The expansion's partial match "process mapping for operational efficiency" likely triggered this, but Mohamed's process work is IT/HR, not CS. v3 was correct to say not_found. |
| Monitor CS reps' performance and provide ongoing coaching and feedback | tier_2 | not_found | **partial** | YES | **REGRESSION** | sv1 reasoning: "coordinated support teams and project resources." He coordinated IT support teams as a project manager, not as their performance manager. No evidence of coaching or feedback sessions. The expansion's partial match "experience as a team captain or shift lead" may have broadened this too far. v3 was correct. |
| Resolve customer complaints and inquiries | tier_2 | partial | **matched** | YES | **REGRESSION** | sv1 reasoning: "managed escalations and coordinated incident resolution for HPE clients." This was IT infrastructure incident management (hardware/software troubleshooting), not customer complaint resolution. v3's "partial" was already generous. Upgrading to "matched" overstates the relevance. |
| Analyze CS trends and recommend improvements | tier_2 | not_found | **partial** | YES | **REGRESSION** | sv1 reasoning: "prepared and presented KPIs and discussed infrastructure improvements with clients." These were IT production KPIs (infrastructure health, uptime), not customer service trend analysis. The expansion's partial match "business intelligence or data analyst roles" may have triggered this. v3 was correct. |
| Train and onboard new CS representatives | tier_2 | not_found | **partial** | YES | **BORDERLINE** | sv1 reasoning: "experience authoring user guides and facilitating training sessions." True -- he did write user guides and train end-users on IT systems. But training end-users on an IT tool is not training customer service staff. The expansion's partial match "experience in public speaking or seminar facilitation" may have contributed. Generous but defensible as partial. |
| Monitor CS reps' adherence to policies | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Ensure CS reps maintain high service level | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Prepare and analyze CS reports | tier_2 | not_found | **partial** | YES | **REGRESSION** | sv1 reasoning: "experience preparing and presenting production KPIs to clients, but this was technical-focused rather than CS-focused." The model's own reasoning admits the KPIs were technical, yet still gives partial. The expansion's partial match "financial reporting experience" may have broadened this. If it's not CS-focused, it should be not_found. |
| Foster collaboration and teamwork among CS reps | tier_2 | not_found | **partial** | YES | **REGRESSION** | sv1 reasoning: "strong experience in agile facilitation and cross-functional team coordination." The expansion's partial match "scrum master or agile facilitator roles" directly triggered this. But Mohamed's agile facilitation was for IT project teams, not customer service teams. This expansion is too broad -- it matches any scrum master to a CS teamwork criterion. |
| 5+ years in customer service | tier_1 | partial | partial | no | -- | Both agree. Both reasoning is similar (long experience but in IT, not CS). |
| Excellent leadership skills | tier_1 | matched | matched | no | -- | Both agree. Correct -- he led project teams. |
| Excellent organizational skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Strong communication skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Strong problem-solving skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Strong decision-making skills | tier_1 | matched | **partial** | YES | **IMPROVEMENT** | sv1 reasoning: "the context is more technical/IT project-oriented." This downgrade is actually more accurate -- his decision-making was in IT project scoping, not CS escalation authority. v3 was generous. |
| Proficient in MS Office | tier_1 | matched | matched | no | -- | Both agree. Correct -- resume lists Excel and PowerPoint. |
| Handle multiple tasks and prioritize | tier_2 | matched | matched | no | -- | Both agree. Correct. |
| Motivate and mentor CS reps | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Knowledge of CS software and systems | tier_2 | partial | partial | no | -- | Both agree. Both cite Salesforce experience. Reasonable. |
| Communicate using virtual meeting tools | tier_2 | matched | matched | no | -- | Both agree. |

**Summary for #20:** 8 criteria changed. 6 regressions (not_found -> partial or partial -> matched where the resume doesn't support it), 1 borderline, 1 improvement. The expansions caused the model to award partial credit for IT project management activities that are not customer service. The scrum master and agile facilitation expansion examples are the worst offenders -- they match any PM to CS teamwork criteria. Net effect: score inflated from 54.3% to 66.0% against an eyeball of 3.

---

## Resume #16: Btissam Aissaoui (Client Support)

**Eyeball: 4 | v3: 35.1% | sv1: 24.5% | Delta: -10.6% BETTER**

Resume summary: 3 years of experience in support roles (self-stated). Roles include: functional consultant for LIMS (lab software), HR/payroll integrator at SD Worx, R&D database engineer at INRA, Neolane marketing software support at Servier, agent de mairie, railway traffic management at DB Schenker, technical support consultant at Argalis (100% remote). Has web design, SEO, Google Analytics skills. Education: Master 2 in Bioinformatics. Says she is patient, organized, calm, autonomous.

| Criterion | Tier | v3 Score | sv1 Score | Changed? | Correct? | Analysis |
|-----------|------|----------|-----------|----------|----------|----------|
| Develop and implement CS policies and procedures | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Monitor CS reps' performance | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Resolve customer complaints and inquiries | tier_2 | **matched** | **partial** | YES | **IMPROVEMENT** | v3 reasoning: "held multiple support and service-related positions, implying experience." sv1 reasoning: "experience in support roles, which typically involve handling inquiries, but does not specify experience with complex complaints or escalations." sv1 is more accurate. Her roles were technical/functional support (LIMS, payroll, database, marketing software), not customer complaint resolution. Downgrade from matched to partial is correct. |
| Analyze CS trends | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Train and onboard new CS reps | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Monitor CS reps' adherence to policies | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Ensure CS reps maintain high service level | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Prepare and analyze CS reports | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Foster collaboration and teamwork | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| 5+ years in customer service | tier_1 | partial | partial | no | -- | Both agree. Both note 3 years stated. Correct. |
| Excellent leadership skills | tier_1 | not_found | not_found | no | -- | Both agree. Correct. |
| Excellent organizational skills | tier_1 | **matched** | **partial** | YES | **IMPROVEMENT** | v3 reasoning: "explicitly mentions being applied in their organization." sv1 reasoning: "mentions being 'applied in my organization' and having experience in data management, which suggests baseline organizational skills." v3 gave matched for a self-description ("appliquee dans mon organisation" = "applied in my organization"). sv1 correctly downgrades -- a soft self-description is partial, not matched. No demonstrated organizational achievements. |
| Strong communication skills | tier_1 | partial | partial | no | -- | Both agree. |
| Strong problem-solving skills | tier_1 | **matched** | **partial** | YES | **IMPROVEMENT** | v3 reasoning: "explicitly states they easily overcome difficulties encountered." sv1 reasoning: "Support and technical roles inherently require problem-solving, and the candidate mentions being able to overcome difficulties." v3 gave matched for a vague self-claim ("je arrive facilement a surmonter les difficultes"). sv1 correctly downgrades to partial -- a soft personality statement is not demonstrated problem-solving. |
| Strong decision-making skills | tier_1 | not_found | not_found | no | -- | Both agree. Correct. |
| Proficient in MS Office | tier_1 | partial | partial | no | -- | Both agree. Both note implied tech literacy from math/informatics background but no explicit Office listing. |
| Handle multiple tasks and prioritize | tier_2 | partial | partial | no | -- | Both agree. |
| Motivate and mentor CS reps | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Knowledge of CS software and systems | tier_2 | **matched** | **partial** | YES | **IMPROVEMENT** | v3 reasoning: "experience with software such as Neolane, LIMS, and various web-marketing/mailing tools." sv1 reasoning: "experience as a functional support consultant for LIMS and other software, demonstrating familiarity with enterprise systems." v3 gave matched for Neolane (marketing automation) and LIMS (lab information management). Neither is customer service software. sv1 correctly downgrades -- enterprise software familiarity is partial, not a match for CS-specific tools like Zendesk/Freshdesk. |
| Communicate using virtual meeting tools | tier_2 | partial | partial | no | -- | Both agree. Both note remote work implies tool usage. |

**Summary for #16:** 4 criteria changed, all improvements. The expansions helped the model discriminate better:
- Stopped giving "matched" for vague self-descriptions ("I'm organized," "I overcome difficulties")
- Stopped giving "matched" for non-CS software (LIMS, Neolane)
- Correctly downgraded technical support to partial for CS complaint resolution
Net effect: score reduced from 35.1% to 24.5%, closer to the eyeball of 4.

---

## Resume #9: Alexia Mboule (CX Project Manager, managed 14 agents)

**Eyeball: 8 | v3: 62.8% | sv1: 58.5% | Delta: -4.3% WORSE (was already underscoring)**

Resume summary: Currently Vendor PM at Cloudkitchens (Jul 2023-present). Previously Support Manager at Cloudkitchens (Mar 2021-Jul 2023) -- managed 14 customer support agents, provided guidance, training, performance evaluations. Before that, Customer Success rep at Cloudkitchens (Jul 2020-Jul 2021), employee #4 in Europe. Before that, SDR at Wavy startup (Mar 2019-Jun 2020). Skills listed: resilience, problem-solving, process improvement, meeting deadlines, leadership, communication, time management. Education: 2-year technical degree from ENACO business school. Languages: French, English, Spanish.

| Criterion | Tier | v3 Score | sv1 Score | Changed? | Correct? | Analysis |
|-----------|------|----------|-----------|----------|----------|----------|
| Develop and implement CS policies and procedures | tier_2 | partial | partial | no | -- | Both agree. Both cite strategy optimization. Reasonable. |
| Monitor CS reps' performance and provide coaching | tier_2 | matched | matched | no | -- | Both agree. Correct -- managed 14 agents with training and performance evaluations. |
| Resolve customer complaints and inquiries | tier_2 | matched | matched | no | -- | Both agree. Correct -- was primary contact for customer issues. |
| Analyze CS trends and recommend improvements | tier_2 | partial | partial | no | -- | Both agree. |
| Train and onboard new CS reps | tier_2 | matched | matched | no | -- | Both agree. Correct -- explicitly provided training. |
| Monitor CS reps' adherence to policies | tier_2 | partial | **not_found** | YES | **REGRESSION** | v3 reasoning: "performance evaluations are mentioned, there is no explicit mention of monitoring adherence to specific company policies." sv1 reasoning: "does not provide evidence of monitoring policy adherence or auditing internal workflows for compliance." v3 gave partial (performance evaluations imply some oversight). sv1 gives not_found. As a Support Manager who did performance evaluations of 14 agents, she almost certainly monitored policy adherence as part of those evaluations. v3's partial was more appropriate. The expansion's full-match examples (audit trails, HIPAA compliance, script compliance) may have set too high a bar. |
| Ensure CS reps maintain high service level | tier_2 | **matched** | **partial** | YES | **REGRESSION** | v3 reasoning: "provided guidance and performance evaluations to maintain service standards." sv1 reasoning: "implied to lead to high service standards, but there is no specific evidence of quality metrics or programs managed." She managed 14 agents with performance evaluations -- this IS ensuring service quality. The expansion's full-match examples (NPS scores, incentive programs, mystery shopper programs) set too high a bar. A support manager doing performance evaluations IS ensuring quality. v3's matched was correct. |
| Prepare and analyze CS reports | tier_2 | not_found | not_found | no | -- | Both agree. |
| Foster collaboration and teamwork | tier_2 | partial | partial | no | -- | Both agree. |
| 5+ years in customer service | tier_1 | partial | partial | no | -- | Both agree. Both note ~5 years but mixed roles. |
| Excellent leadership skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Excellent organizational skills | tier_1 | partial | partial | no | -- | Both agree. |
| Strong communication skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Strong problem-solving skills | tier_1 | matched | matched | no | -- | Both agree. Correct. |
| Strong decision-making skills | tier_1 | partial | partial | no | -- | Both agree. |
| Proficient in MS Office | tier_1 | not_found | not_found | no | -- | Both agree. Correct -- not mentioned. |
| Handle multiple tasks and prioritize | tier_2 | partial | partial | no | -- | Both agree. |
| Motivate and mentor CS reps | tier_2 | matched | matched | no | -- | Both agree. Correct. |
| Knowledge of CS software and systems | tier_2 | partial | **not_found** | YES | **REGRESSION** | v3 reasoning: "working as a customer success representative and support manager, implying use of such systems, but does not name specific software." sv1 reasoning: "does not list any specific customer service software or ticketing platforms." v3's partial was reasonable -- anyone managing 14 CS agents at a tech company (Cloudkitchens) certainly used CS software. sv1's not_found is too strict. The expansion listing specific tools (Zendesk, Salesforce, etc.) may have made the model require named tools. |
| Communicate using virtual meeting tools | tier_2 | not_found | **partial** | YES | **IMPROVEMENT** | v3 reasoning: "does not explicitly mention experience with these specific virtual communication tools." sv1 reasoning: "modern professional background implies use of these tools, but they are not explicitly listed." sv1 is more reasonable -- a CX PM at a tech startup in 2020-present almost certainly uses these tools. The expansion's partial match "experience in distributed or global teams" likely helped. |

**Summary for #9:** 4 criteria changed. 3 regressions, 1 improvement. The expansions hurt Alexia because:
- The high-bar full-match examples (NPS programs, mystery shoppers, audit trails) caused the model to downgrade things a Support Manager of 14 agents clearly does
- The specific tool listing made the model require named software when her role obviously used CS tools
- Net effect: score dropped from 62.8% to 58.5% on a candidate who should score around 80% (eyeball=8). The expansions made an already-too-low score worse.

---

## Resume #8: Ravi Patron (Sales/Bartender)

**Eyeball: 2 | v3: 22.3% | sv1: 30.9% | Delta: +8.6% WORSE (should be very low)**

Resume summary: 28 years old. Entrepreneurship creating a cosmetics brand (Nov 2021-Mar 2024). Sales rep at Longchamp (Jul-Nov 2022, 4 months). Sales rep at Dior (Jul 2021-Jun 2022, 11 months). Bartender at multiple luxury hotels and restaurants (2017-2020). Receptionist at events via temp agencies (2014-2021). Private English teacher (2013-2021). Education: tailoring school. Languages: French native, English fluent, Italian and Spanish academic. No technical skills, no management experience, no CS software knowledge.

| Criterion | Tier | v3 Score | sv1 Score | Changed? | Correct? | Analysis |
|-----------|------|----------|-----------|----------|----------|----------|
| Develop and implement CS policies | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Monitor CS reps' performance | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Resolve customer complaints and inquiries | tier_2 | partial | partial | no | -- | Both agree. Both cite customer relationship roles. Partial is already generous for luxury retail sales. |
| Analyze CS trends | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Train and onboard new CS reps | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Monitor CS reps' adherence to policies | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Ensure CS reps maintain high service level | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Prepare and analyze CS reports | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Foster collaboration and teamwork | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| 5+ years in customer service | tier_1 | partial | **matched** | YES | **REGRESSION** | v3 reasoning: "varied experience including sales and reception, but unclear if it totals 5+ years of dedicated customer service." sv1 reasoning: "over 5 years of diverse experience in customer-facing roles including sales representative at Dior/Longchamp and extensive experience in luxury hospitality and receptionist roles." sv1 is wrong. Ravi's customer-facing time: Longchamp 4 months + Dior 11 months + bartending stints totaling ~18 months + temp receptionist gigs. These are sales and hospitality, not customer service. And they're fragmented short stints. The expansion's partial match "inside sales roles that involve service components" and "front-desk or receptionist roles with heavy phone volume" likely inflated this from partial to matched. This is a tier_1 criterion, so the inflation has outsized impact. |
| Excellent leadership skills | tier_1 | not_found | not_found | no | -- | Both agree. Correct. |
| Excellent organizational skills | tier_1 | partial | partial | no | -- | Both agree. |
| Strong communication skills | tier_1 | matched | matched | no | -- | Both agree. Defensible -- fluent in English, luxury sales/hospitality roles. |
| Strong problem-solving skills | tier_1 | partial | partial | no | -- | Both agree. |
| Strong decision-making skills | tier_1 | not_found | **partial** | YES | **REGRESSION** | v3 reasoning: "No clear evidence of decision-making authority or impact." sv1 reasoning: "Entrepreneurship implies the ability to make business decisions, though evidence of specific customer service decision-making is limited." The expansion may have triggered on entrepreneurship. Creating a cosmetics brand does involve decisions, but this criterion is about customer service decision-making (escalations, refunds, staffing). v3 was correct to say not_found. |
| Proficient in MS Office | tier_1 | not_found | not_found | no | -- | Both agree. Correct. |
| Handle multiple tasks and prioritize | tier_2 | partial | **matched** | YES | **REGRESSION** | v3 reasoning: "Hospitality and sales roles typically require multitasking, though it is not explicitly documented." sv1 reasoning: "Work history includes high-volume roles in hospitality and retail, which require multitasking and prioritization." The expansion's full-match example "experience in high-volume retail or fast-paced hospitality" directly triggered this upgrade. But bartending and luxury retail sales are not the same as managing a CS queue. v3's partial was already generous. |
| Motivate and mentor CS reps | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Knowledge of CS software | tier_2 | not_found | not_found | no | -- | Both agree. Correct. |
| Communicate using virtual meeting tools | tier_2 | partial | partial | no | -- | Both agree. Both generous already. |

**Summary for #8:** 3 criteria changed, all regressions. The most damaging:
- "5+ years in customer service" went from partial to matched (tier_1!) because the expansion examples include "inside sales" and "receptionist roles." Bartending and 4-month luxury retail stints should not count as 5+ years of customer service.
- "Handle multiple tasks" went partial -> matched because the expansion explicitly lists "fast-paced hospitality" as a full match. This maps bartending directly to a CS multitasking criterion.
- "Decision-making" went not_found -> partial because the expansion caught his entrepreneurship.
Net effect: score inflated from 22.3% to 30.9% on a candidate who should score around 20% (eyeball=2).

---

## Cross-Resume Findings

### Expansion patterns that caused regressions

1. **"Scrum master or agile facilitator roles" as partial for "Foster collaboration among CS reps"** -- This matches any PM/scrum master to a CS teamwork criterion regardless of the team type. Mohamed's agile facilitation was for IT project teams. **Fix: add "in a customer service or support context" qualifier.**

2. **"Inside sales roles that involve service components" and "front-desk or receptionist roles" as partial for "5+ years in customer service"** -- This inflated Ravi's fragmented hospitality/sales stints into a full match. **Fix: these should specify duration thresholds or note they count only when the role's primary function is service.**

3. **"Experience in high-volume retail or fast-paced hospitality" as full match for "Handle multiple tasks"** -- This maps bartending directly to CS multitasking. **Fix: move to partial match, or qualify "in a customer service context."**

4. **Specific tool listings in expansions raising the bar too high** -- For "Knowledge of CS software," listing Zendesk/Salesforce/Freshdesk made the model require named tools, penalizing Alexia who obviously used CS tools as a Support Manager of 14 agents but didn't list them. **Fix: add a note that management of CS teams implies tool usage even if not named.**

5. **High-bar full-match examples setting implicit thresholds** -- For "Ensure CS reps maintain high service level," examples like NPS programs and mystery shoppers made the model downgrade a Support Manager doing performance evaluations. **Fix: add a simpler full-match example like "conducted regular performance reviews of direct reports in a service role."**

### Expansion patterns that helped

1. **Btissam's false positives were correctly fixed** -- The expansions helped the model distinguish between "self-claims" (I'm organized) vs demonstrated organizational skill, and between "enterprise software" vs "CS software." This discrimination is valuable.

2. **Virtual communication tools for modern roles** -- Alexia correctly got partial for virtual tools (modern tech startup implies usage). The expansion's "experience in distributed or global teams" helped.

### Net assessment

The expansions are a net negative as currently written. They inflate weak candidates more than they help strong ones:
- Mohamed (#20): +11.7% inflation (BAD)
- Ravi (#8): +8.6% inflation (BAD)
- Alexia (#9): -4.3% further deflation (BAD -- she was already too low)
- Btissam (#16): -10.6% deflation (GOOD -- false positives fixed)

Score of 1 good, 3 bad across the 4 most-changed resumes. The core problem: expansions that list adjacent-domain activities (agile facilitation, hospitality, sales) as partial or full matches allow the model to award credit for non-CS experience in CS-specific criteria.
