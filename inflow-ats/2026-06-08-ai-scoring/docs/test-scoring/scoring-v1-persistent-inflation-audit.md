# Scoring v1 Persistent Inflation Audit

These candidates scored the same in v3 (no expansions) and scoring-v1 (with expansions), meaning the inflation is in the base scoring logic, not the expansion system.

---

## #5 Adrien Seret -- eyeball=7, AI=94.7%

AI gave 18 matched, 2 partial, 0 not_found. That is absurdly generous for an eyeball-7.

Adrien is a legitimate CS professional with real supervisory experience (Uniqlo outsourced CS oversight, Disney team supervisor at Sitel). However, his actual management scope was narrow -- he supervised an outsourced agency's output and a small team at a call center. His most recent role (Smart Global Governance) is Customer Success, which is a different discipline from Customer Support/Service. He is also based in France with a French CS background -- no US market experience.

| # | Criterion | AI Score | Justified? | What resume actually says |
|---|-----------|----------|------------|--------------------------|
| 1 | Develop and implement CS policies and procedures | matched | INFLATED -- should be partial | Resume says "Create internal Customer Success processes" at Smart Global Governance. This is Customer Success (account management/retention), not Customer Service (support). At Uniqlo he "constantly reviewed Customer Services workflows and templates" -- but reviewing existing workflows is not the same as developing and implementing policies. He adapted existing processes, not built them from scratch. partial at best. |
| 2 | Monitor CS reps' performance and provide coaching | matched | Justified | At Uniqlo: "Review C-Sat and CS agents performance and provide feedback and methods for improvement." At Sitel/Disney: "Provide individual feedback to each agent and methods for improvement." Direct evidence. |
| 3 | Resolve customer complaints efficiently | matched | Justified | At Smart Global Governance: "Provide technical support, coordinate escalations, guarantee rapid and satisfactory resolution." At LiveSmart: "Handle all queries & communication, from B2B to B2C." Direct evidence across multiple roles. |
| 4 | Analyze CS trends and recommend improvements | matched | Justified | At Uniqlo: created Excel dashboard for Top Contact Drivers, reported KPIs, reported on NPS and C-Sat, defined action plans. Clear, specific evidence. |
| 5 | Train and onboard new CS reps | matched | INFLATED -- should be partial | At Sitel/Disney: "Help to recruit and interview new agents" and at Uniqlo: "Help to prepare capacity plan and training material." The word "help" in both cases means he assisted with training, not that he owned or designed training programs. At Smart Global Governance: "plan initial and regular training depending on the client's needs" -- this is training clients on the product, not training CS reps. partial. |
| 6 | Monitor CS reps' adherence to policies | matched | INFLATED -- should be partial | At Uniqlo: "daily analysis on quality assurance, checking through CS agent's work, flagging any errors." This is quality checking work output, which is adjacent to adherence monitoring, but QA of ticket responses is not the same as monitoring adherence to company policies and procedures. It is close enough for partial but the AI reasoning ("conducted daily quality assurance by checking agent work, flagging errors, and ensuring adherence to established workflows") adds "ensuring adherence to established workflows" which is not a phrase from the resume. |
| 7 | Ensure CS reps maintain high service level | matched | Justified | At Sitel/Disney: "Monitor calls, emails, and social media to ensure that the team provides excellent customer service." At Uniqlo: quality monitoring, calibration meetings. Direct evidence. |
| 8 | Prepare and analyze CS reports | matched | Justified | At Uniqlo: "Creation of an Excel dashboard to track Top Contact Drivers," "Report on KPIs to E-com on a weekly basis," monthly reports on contact drivers, NPS, C-Sat. Extensive specific evidence. |
| 9 | Foster collaboration and teamwork | partial | Justified | AI correctly flagged limited evidence. Resume shows cross-team communication but no team-building programs. |
| 10 | 5+ years CS experience | matched | Justified | Uniqlo (3y7m) + Sitel/Disney (1y8m) = 5y3m in actual CS roles. Smart Global Governance and LiveSmart are Customer Success, a different function, but the core CS roles alone meet the threshold. |
| 11 | Excellent leadership skills | matched | INFLATED -- should be partial | His actual leadership: Team Supervisor at Sitel (quality monitoring role), and oversight of an outsourced agency at Uniqlo (he was not managing direct reports -- he was the liaison reviewing the agency's work). At Smart Global Governance he is "Manager of the Customer Success team" but the resume does not state team size. The word "excellent" is a high bar; he has some supervisory experience but not strong evidence of strategic leadership. partial is more accurate. |
| 12 | Excellent organizational skills | matched | Justified | Managing complex tracking across Trello, Monday.com, coordinating between head office/warehouse/outsourced CS, managing onboarding projects. Reasonable inference. |
| 13 | Strong communication skills | matched | Justified | Multilingual (French/English fluent), drafted help articles, created templates, presented to international stakeholders. Reasonable. |
| 14 | Strong problem-solving skills | matched | INFLATED -- should be partial | AI says "explicitly identifies a proactive approach to problem-solving." This comes from the summary blurb ("proactive approach to problem solving"), which is a self-description, not evidence. The resume shows no specific problem-solving examples beyond handling escalations, which is standard CS work. A self-description in a summary statement is not evidence of a skill. partial. |
| 15 | Strong decision-making skills | partial | Justified | AI correctly flagged no specific decision-making evidence. |
| 16 | Proficient in Microsoft Office Suite | matched | Justified | Resume explicitly states "advanced in Microsoft & Google suites" and lists "Microsoft 365 (Word, Excel, Powerpoint, Outlook, Teams)" in Skills, plus built Excel dashboards. Clear evidence. |
| 17 | Handle multiple tasks and prioritize | matched | Justified | Implicit from managing multiple concurrent responsibilities across roles. Reasonable inference. |
| 18 | Motivate and mentor CS reps | matched | INFLATED -- should be partial | AI says "provided individual coaching, feedback, and methods for improvement." The actual resume text at Sitel is "Provide individual feedback to each agent and methods for improvement." Feedback is part of mentoring, but "motivate" has no evidence -- the resume never describes motivating or inspiring team members. And the feedback was in a quality monitoring context, not a mentorship context. partial. |
| 19 | Knowledge of CS software | matched | Justified | Explicitly lists: SAP, Oracle, Intercom, Salesforce, Zendesk, Zoho in Skills section. Clear evidence. |
| 20 | Virtual communication tools | matched | Justified | Lists Slack, Teams, and has experience in international remote/distributed teams. Clear evidence. |

**Summary for #5:** 5 false-positive "matched" scores that should be "partial." Corrected score would drop from 18 matched / 2 partial to 13 matched / 7 partial. Using the scoring formula (matched=full weight, partial=half, not_found=0), this would bring the score down meaningfully -- still a decent candidate but not 94.7%.

**Root cause patterns:**
- Treating self-descriptions in summary blurbs as evidence of skills (problem-solving)
- Conflating Customer Success (account management) with Customer Service (support) -- these are different functions
- Upgrading "helped with" to "owned and did" (training)
- Adding phrases not in the resume to strengthen reasoning (adherence monitoring)
- Scoring "motivate and mentor" as matched when only feedback evidence exists

---

## #6 Angel Bermudez -- eyeball=6, AI=94.7%

AI gave 18 matched, 2 partial, 0 not_found. Same inflated score as #5.

Angel has a mixed background: IT Helpdesk (current), CS Supervisor at a Shopify app company (PageFly), Social Media Manager for a crypto exchange (Poloniex), and Senior IT Support at a Venezuelan TV company. His CS supervisor role was for a SaaS page builder app, not traditional customer service. His current role is IT helpdesk. He is heavily technical-support-oriented, not customer-service-oriented.

| # | Criterion | AI Score | Justified? | What resume actually says |
|---|-----------|----------|------------|--------------------------|
| 1 | Develop and implement CS policies and procedures | matched | INFLATED -- should be partial | AI reasoning: "contributing to the improvement of IT support processes and documentation, as well as implementing structured troubleshooting protocols and social media strategies." The IT support process improvement is IT helpdesk, not customer service. The "structured troubleshooting protocols" are IT troubleshooting for hardware/software. The "social media strategies" were for Poloniex's social media presence, not CS policies. None of this is developing customer service policies. partial at best (IT process improvement is tangentially related). |
| 2 | Monitor CS reps' performance and provide coaching | matched | BORDERLINE -- weak matched | At PageFly: "Analyze statistics and other data to determine the level of customer service performance achieved by the team and provided them with the resources needed to reach their goals." This does reference performance monitoring and providing resources. The evidence is thin (one bullet point, one role) but it exists. Weak matched is defensible. |
| 3 | Resolve customer complaints efficiently | matched | INFLATED -- should be partial | AI reasoning: "handling technical escalations and improving incident resolution times." The escalations are IT support escalations (hardware/software issues at Littelfuse), not customer complaints. At PageFly he solved "technical issues with CSS, JS & Liquid" -- this is product technical support, not complaint resolution. IT troubleshooting and product tech support are different from handling customer complaints. partial. |
| 4 | Analyze CS trends and recommend improvements | matched | INFLATED -- should be partial | AI reasoning: "analyzing statistics and performance data to determine service levels" (PageFly) and "Google Analytics to track campaign effectiveness" (Poloniex social media). The PageFly reference is legitimate but thin. The Google Analytics work was for social media campaign tracking, not customer service trend analysis. Mixing social media analytics with CS trend analysis is a stretch. partial. |
| 5 | Train and onboard new CS reps | matched | Justified | At PageFly: "designing and conducting new hire training, remedial training, and new process training." Direct, explicit evidence. |
| 6 | Monitor CS reps' adherence to policies | partial | Justified | AI correctly scored this as partial with appropriate reasoning. |
| 7 | Ensure CS reps maintain high service level | matched | BORDERLINE -- weak matched | At PageFly: managed a team, earned "best support operator for 15 months in a row." The award was for his own personal performance (5-star reviews he received), not for his team's performance. AI reasoning conflates his personal award with team quality management. However, managing a CS team inherently involves ensuring service quality. Weak matched. |
| 8 | Prepare and analyze CS reports | matched | INFLATED -- should be partial | AI reasoning: "reporting on campaign effectiveness and analyzing support statistics." The campaign reporting was social media at Poloniex, not CS reports. The "support statistics" reference is from PageFly but the resume does not say he prepared reports -- it says he analyzed statistics. "Analyzing statistics" in a supervisor role is different from "preparing and analyzing customer service reports" as a deliverable. partial. |
| 9 | Foster collaboration and teamwork | matched | INFLATED -- should be partial | AI reasoning: "led a 'support squad' initiative and managed cross-functional projects." The "support squad" was a Twitter support initiative at Poloniex (a social media response team), not fostering collaboration among customer service representatives. The "cross-functional projects" are at Littelfuse IT. Neither is evidence of fostering teamwork among CS reps. partial. |
| 10 | 5+ years CS experience | matched | INFLATED -- should be partial | AI says "over 9 years across customer service, technical support, and IT helpdesk roles." But: Littelfuse (2023-present) = IT Helpdesk. PageFly (2020-2023) = CS Supervisor (legitimate CS). Poloniex (2020-2022) = Social Media Manager (not CS). Antorcha TV (2012-2018) = Senior IT Support (not CS). The only actual customer service role is PageFly at ~2.5 years. IT helpdesk and IT support are different from customer service. Adding up IT support time to hit 5+ years is a category error. partial. |
| 11 | Excellent leadership skills | matched | BORDERLINE -- weak matched | Supervised a team at PageFly. Managed 5 IT technicians at Antorcha TV. Led a Twitter support squad at Poloniex. He has leadership experience, though the scope is modest. Acceptable as weak matched. |
| 12 | Excellent organizational skills | matched | INFLATED -- should be partial | AI reasoning: "managed complex ticketing systems, balanced multiple technical projects." Managing a ticketing system is using a tool, not demonstrating organizational skills. Balancing projects is generic. There is no specific evidence of organizational excellence -- no project management achievements, no process organization examples beyond basic job duties. partial. |
| 13 | Strong communication skills | matched | Justified | Content creation experience, technical documentation, live chat and phone support, multilingual (Spanish/English at minimum). Reasonable evidence across multiple roles. |
| 14 | Strong problem-solving skills | matched | Justified | Troubleshooting CSS/JS/Liquid issues, resolving IT hardware/software problems, implementing structured troubleshooting protocols. Technical problem-solving is well-documented. |
| 15 | Strong decision-making skills | matched | INFLATED -- should be partial | AI reasoning: "implemented strategic initiatives for support and social media, requiring autonomous decision-making." This is inference, not evidence. Implementing a social media strategy does not specifically demonstrate decision-making skills. The resume lists no examples of making significant decisions. partial. |
| 16 | Proficient in Microsoft Office Suite | partial | Justified | AI correctly scored this as partial. Resume mentions "Computer Literacy" in skills but does not list Microsoft Office specifically. |
| 17 | Handle multiple tasks and prioritize | matched | Justified | Managing ticketing, live chat, and cross-functional projects simultaneously. Reasonable inference from the role descriptions. |
| 18 | Motivate and mentor CS reps | matched | INFLATED -- should be partial | AI reasoning: "provided resources to help their team reach goals and led initiatives that improved satisfaction ratings." The "provided resources" is from PageFly (one bullet point). "Led initiatives that improved satisfaction ratings" refers to his Twitter support squad at Poloniex, which improved customer satisfaction through social media response, not by mentoring CS reps. No specific mentoring or motivation examples exist. partial. |
| 19 | Knowledge of CS software | matched | INFLATED -- should be partial | AI reasoning: "experience with Hootsuite, ticketing systems, and analytics tools." Hootsuite is a social media management tool, not CS software. "Ticketing systems" are mentioned generically but no specific CS platforms (Zendesk, Salesforce, Intercom, etc.) are listed. Google Analytics is web analytics, not CS software. The resume shows no evidence of using actual customer service software. partial. |
| 20 | Virtual communication tools | matched | INFLATED -- should be partial | AI reasoning: "worked extensively in remote roles utilizing various digital communication and collaboration tools." The resume says the roles were remote, but it never names any communication tools (no Slack, no Google Meet, no Teams, no Zoom). Working remotely is not evidence of proficiency with specific virtual communication tools. The criterion specifically names email, Google Meet, and Slack. partial. |

**Summary for #6:** 10 false-positive "matched" scores that should be "partial." Corrected score would drop from 18 matched / 2 partial to 8 matched / 12 partial. This is a dramatic overscoring. With proper scoring, Angel would be in the ~55-60% range, much closer to the eyeball score of 6.

**Root cause patterns:**
- Conflating IT support/helpdesk with customer service -- these are different job functions
- Conflating social media management with customer service
- Treating "worked remotely" as evidence of virtual communication tool proficiency
- Crediting social media tools (Hootsuite, Google Analytics) as customer service software
- Counting years in IT support toward "5+ years CS experience"
- Inferring skills from job titles rather than requiring specific evidence
- Accepting one thin bullet point as "matched" when the criterion implies substantial experience

---

## #15 Patricia Fix -- eyeball=3, AI=68.1%

AI gave 7 matched, 12 partial, 1 not_found. The partials are the main concern here -- many should be not_found. And several "matched" are unjustified.

Patricia is an Executive Assistant/Office Manager with zero customer service experience. Her career: Office Manager at a golf academy, B2B Services Manager at a knife company, freelance Project Manager, Commercial Instructor at Volvo Brazil, Legal Administrative Analyst at Volvo Brazil, Executive Assistant at Volvo Brazil. None of these are customer service roles.

| # | Criterion | AI Score | Justified? | What resume actually says |
|---|-----------|----------|------------|--------------------------|
| 1 | Develop and implement CS policies and procedures | partial | INFLATED -- should be not_found | AI reasoning: "experience in administrative restructuring and Lean management implementation." Administrative restructuring and Lean management are operations/process improvement, not customer service policy development. These are entirely different domains. There is zero connection to CS policies. not_found. |
| 2 | Monitor CS reps' performance and provide coaching | partial | INFLATED -- should be not_found | AI reasoning: "managed a sales team and developed training programs." She trained a sales team at a knife company ("Developed and delivered training programs for the sales team"). Sales team training has nothing to do with monitoring customer service representatives. not_found. |
| 3 | Resolve customer complaints efficiently | partial | INFLATED -- should be not_found | AI reasoning: "experience in client relations and resolving problems efficiently." The "client relations" is B2B services management and B2C billing at a golf academy. The "resolving problems efficiently" comes from her Executive Assistant role at Volvo ("Resolved problems efficiently and adapted to new challenges quickly") -- this is generic executive assistant problem-solving, not customer complaint resolution. not_found. |
| 4 | Analyze CS trends and recommend improvements | partial | INFLATED -- should be not_found | AI reasoning: "created KPIs and dashboards for performance analysis, but the focus was on administrative and commercial metrics." The AI itself acknowledges these are not CS metrics! KPIs for financial analysis at Volvo's legal department are not customer service trends. not_found. |
| 5 | Train and onboard new CS reps | partial | INFLATED -- should be not_found | AI reasoning: "developed training programs for a sales team, which is related." Training a sales team at a knife company is not related to onboarding customer service representatives. Different function, different skills, different context. not_found. |
| 6 | Monitor CS reps' adherence to policies | not_found | Justified | Correctly scored. |
| 7 | Ensure CS reps maintain high service level | partial | INFLATED -- should be not_found | AI reasoning: "certification in Customer Experience Fundamentals and experience enhancing client journeys." A certification from "Tracksale University" is a short online course, not work experience. "Enhanced client experiences throughout their journey" is one bullet at Volvo under Commercial Instructor -- this is sales/commercial client management, not managing CS staff quality. not_found. |
| 8 | Prepare and analyze CS reports | partial | INFLATED -- should be not_found | AI reasoning: "proficient at creating KPIs and dashboards, though these were generally for financial or administrative reporting." Again, the AI itself notes these are financial/administrative, not CS. Financial dashboards at Volvo's legal department are not customer service reports. not_found. |
| 9 | Foster collaboration and teamwork among CS reps | partial | INFLATED -- should be not_found | AI reasoning: "managed teams and provided operational support, which implies collaborative leadership." Managing daily team operations at a golf academy does not imply fostering collaboration among CS reps. She never managed CS reps. not_found. |
| 10 | 5+ years CS experience | partial | INFLATED -- should be not_found | AI reasoning: "14 years of professional experience with significant client relations and administrative support roles, but not exclusively in customer service roles." Not "not exclusively" -- she has ZERO customer service roles. Executive Assistant, Office Manager, Legal Administrative Analyst, Commercial Instructor, B2B Services Manager, Project Manager -- none of these are customer service. Having "client relations" as part of an administrative job does not count as customer service experience. not_found. |
| 11 | Excellent leadership skills | matched | INFLATED -- should be partial | AI reasoning: "roles as Office Manager, Project Manager, and team trainer, supported by Lean leadership certifications." Office Manager at a golf academy and freelance Project Manager are modest leadership roles. The Lean leadership course is from Volvo Group University (corporate training). These show some management responsibility but not "excellent leadership" -- she was not leading large teams or driving strategic initiatives. partial. |
| 12 | Excellent organizational skills | matched | Justified | 14 years as an Executive Assistant/Office Manager inherently requires organizational skills. Project management, budget control, coordinating administrative operations. This is the core of her career. Reasonable. |
| 13 | Strong communication skills | matched | BORDERLINE -- weak matched | Multilingual (Portuguese native, English fluent, French fluent) is genuine evidence. Social media management requires communication. Executive support to VPs and directors requires communication. The evidence is indirect but multilingual + executive support is reasonable. Weak matched. |
| 14 | Strong problem-solving skills | matched | INFLATED -- should be partial | AI reasoning: "explicitly notes her success in resolving problems efficiently and implementing process optimizations through Lean management." The "resolved problems efficiently" is one generic bullet under Executive Assistant. Lean management is process optimization methodology, not problem-solving skill evidence. A single generic bullet is not strong evidence. partial. |
| 15 | Strong decision-making skills | partial | Justified | AI correctly identified weak evidence. |
| 16 | Proficient in Microsoft Office Suite | matched | INFLATED -- should be partial | AI reasoning: "It is standard for an Executive Assistant and Office Manager of 14 years to be highly proficient in these tools, and her dashboard/KPI creation confirms Excel proficiency." This is INFERENCE, not evidence. The resume never mentions Microsoft Office, Word, Excel, or PowerPoint anywhere. "It is standard for" is assuming a skill based on a job title. The criterion asks for proficiency, which requires evidence, not assumptions about what is "standard." The dashboard creation could be in any tool. partial at best (reasonable inference from career type, but no explicit evidence). |
| 17 | Handle multiple tasks and prioritize | matched | BORDERLINE -- weak matched | Managing social media, administrative structure, and financial dashboards simultaneously is reasonable evidence of multitasking, though it describes what any office manager does. Weak matched. |
| 18 | Motivate and mentor CS reps | partial | INFLATED -- should be not_found | AI reasoning: "experience training and assisting teams, but not specifically in mentoring CS staff." She trained a sales team at a knife company. She has never worked with CS staff. not_found. |
| 19 | Knowledge of CS software | partial | INFLATED -- should be not_found | AI reasoning: "uses social media tools and has a Customer Experience certification, but does not list specific CS ticketing or CRM software." Social media tools are not CS software. A short certification is not knowledge of CS systems. The resume lists zero CS software. not_found. |
| 20 | Virtual communication tools | matched | INFLATED -- should be partial | AI reasoning: "experience as a remote Project Manager and extensive multilingual administrative background confirms her ability to use virtual communication tools effectively." Working remotely does not confirm proficiency with specific tools. The resume never mentions email platforms, Google Meet, Slack, Zoom, Teams, or any virtual meeting tool. The criterion specifically names these tools. partial. |

**Summary for #15:** 4 false-positive "matched" (should be partial or not_found), 10 false-positive "partial" (should be not_found). Corrected score: 3 matched, 4 partial, 13 not_found. Using standard scoring, this would put Patricia around 20-25%, consistent with the eyeball score of 3.

**Root cause patterns:**
- Scoring "partial" for skills from entirely different job functions (sales training counted toward CS training, financial KPIs counted toward CS reports)
- Assuming skills based on job titles ("standard for an Executive Assistant" = proficiency assumed without evidence)
- Counting any "client" interaction as customer service experience
- Treating online certificates and micro-courses as evidence of practical skill
- "Working remotely" treated as evidence of virtual communication tool proficiency
- Failing to distinguish between customer service as a profession and any job that involves interacting with people

---

## Cross-Candidate Inflation Patterns

These patterns appear across all three candidates and point to systemic prompt issues:

### 1. Job-function conflation
The AI treats IT support, Customer Success, social media management, executive assistance, B2B sales, and customer service as interchangeable. They are not. A criterion about "customer service" should require actual customer service work, not tangentially related roles.

### 2. Inference from job titles instead of requiring evidence
The AI infers skills from what a job title "would typically require" rather than what the resume actually states. Examples: assuming an Executive Assistant knows Microsoft Office, assuming a remote worker uses virtual meeting tools, assuming a supervisor motivates people.

### 3. Self-descriptions treated as evidence
Summary/objective statements ("proactive approach to problem solving") are treated as matched evidence of the skill. These are claims, not evidence. Skills criteria should require demonstrated examples, not self-descriptions.

### 4. "Partial" used when "not_found" is correct
When someone has done something in a completely different domain (training a sales team at a knife company), the AI gives "partial" credit toward a CS criterion. partial should mean "some relevant evidence but not enough for matched." Zero CS relevance should be not_found.

### 5. Remote work = virtual tools proficiency
All three candidates got credit for virtual communication tools partly or wholly based on "worked remotely." Remote work is a setting, not a skill. The criterion asks about specific tools.

### 6. Social media management = customer service
Social media strategy, content creation, and community management on Twitter/Facebook are treated as customer service experience. These are marketing/brand management functions.

### 7. IT support = customer service
Troubleshooting hardware/software issues, managing IT tickets, and network analysis are treated as customer service. IT support is a different function with different skills, different tools, and different customer interactions.

### Scoring impact estimates

| Candidate | AI Score | Corrected Score (est.) | Eyeball | False Positive Matches |
|-----------|----------|----------------------|---------|----------------------|
| #5 Adrien Seret | 94.7% | ~75-80% | 7 (70%) | 5 of 18 matched |
| #6 Angel Bermudez | 94.7% | ~50-55% | 6 (60%) | 10 of 18 matched |
| #15 Patricia Fix | 68.1% | ~20-25% | 3 (30%) | 4 of 7 matched + 10 of 12 partial |

### Prompt fix recommendations

1. **Require explicit evidence, not inference.** The prompt should instruct: "Score matched only when the resume contains specific, stated evidence. Do not infer skills from job titles, industry norms, or what a role typically requires."

2. **Define job-function boundaries.** The prompt should state: "Customer service means roles focused on handling customer inquiries, complaints, and support. IT support/helpdesk, customer success/account management, social media management, executive assistance, and sales are distinct functions. Do not count experience in these as customer service experience unless the resume explicitly describes customer service duties."

3. **Distinguish partial from not_found.** The prompt should state: "Score partial only when the resume shows evidence in a closely related context (e.g., training CS-adjacent staff, managing a support-adjacent team). Score not_found when the evidence is from an entirely different function (e.g., sales team training does not count toward CS training)."

4. **Disqualify self-descriptions.** The prompt should state: "Summary statements, self-descriptions, and objective clauses (e.g., 'proactive problem solver') are not evidence of skills. Require specific examples from work experience."

5. **Require named tools for tool-proficiency criteria.** The prompt should state: "For criteria about specific tools or software, score matched only if the resume names the tools. Working remotely does not evidence virtual tool proficiency. Being an Office Manager does not evidence Microsoft Office proficiency."
