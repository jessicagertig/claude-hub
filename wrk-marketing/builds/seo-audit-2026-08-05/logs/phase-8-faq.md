# Phase 8 — FAQ page

Branch `seo-phase-8-faq` in `/Users/jessica/wrk/wrk-corp/wrk-marketing`. Nothing committed, nothing pushed, no branch created.

Not in the auditor's spec. Built for objection handling, and to set the format the `/compare/*` FAQ can fill in later.

## Files touched

| File | Change |
|---|---|
| `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/faq.js` | New. 16 questions, `<h2>` + `<p>`, FAQPage JSON-LD |
| `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/footer.js` | Added `/faq` as "FAQ" in the Resources column, above Changelog |
| `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/sitemap.xml.js` | Added `"faq"` to `staticRoutes` (the file lists routes, it does not enumerate them) |

## Structure

Analogs read before writing: `pages/about.js`, `pages/pricing.js`, `pages/changelog.js`, plus `pages/terms.js` and `components/basicPage.js` (the site's only other long-prose `<h2>` + `<p>` page).

Composition matches `pages/changelog.js` exactly — `<SEO>`, `<JsonLd>`, `<Header>`, one `<Section>` (which supplies `Container` itself), `<Start />`, then `const Styled = {}` at the bottom with `const t = props.theme` in each. Two styled components only: `Styled.Questions` (the 40rem column, the width `components/basicPage.js` uses for body copy) and `Styled.Item` (h2/p rules lifted from `BasicPage_Content` and `ChangelogPost_PostContent`). Jessica restyles from here.

No accordion. Plain `<h2>` + `<p>`, server-rendered — `curl` of the page returns every answer in the HTML, so there is nothing for a crawler to miss and nothing that depends on JavaScript.

`faqs` is a module-level array of `{ question, answer }`, where `answer` is an array of paragraphs. Both the visible markup and the JSON-LD are built from that one array, so they cannot drift.

## FAQPage JSON-LD

`<JsonLd id="faq-page" schema={faqSchema} />`, using the existing `components/jsonLd.js`.

`id` collision check — every id in the repo: `organization` and `website` (`pages/_app.js`), `software-application` (`components/softwareApplicationJsonLd.js`), `pricing-product` (`pages/pricing.js`), `article` and `breadcrumb` (`pages/blog/[slug].js`), `industry-service` and `industry-breadcrumb` (`components/industryJsonLd.js`). `faq-page` is unused.

This is the first FAQPage on the site and the first page that renders a visible Q&A. Verified against the live dev render: all 16 `Question.name` values appear verbatim as visible `<h2>` text, and every `acceptedAnswer` paragraph appears verbatim in the DOM. Page-level `<h2>` count is 21 = 16 questions + 4 footer column headings + the `Start` heading.

## Copy written for the page (not in the draft)

Three strings the page structurally needs. Each is re-voiced from an existing surface, nothing added:

- **`pageTitle`** — `Polymer FAQ - Questions About the ATS and Job Board` (51 chars, `noBrandSuffix`). Pattern taken from the sibling pages: `Polymer Changelog - What's New in the ATS`, `Polymer Pricing - Simple ATS Plans from $124/mo`. "ATS" and "job board" from `web/public/llms.txt:3`.
- **`metaDescription`** — `Answers about Polymer: plans and pricing, the free trial, candidate data export, team permissions, integrations, and how Plato AI scores applications.` (150 chars). Each clause names a question that is on the page; "Plato AI scores applications" is `llms.txt:3` / `components/plato/platoDescription.js:28-29`.
- **`Header` title + description** — title `Frequently asked questions`; description `Answers about Polymer, an applicant tracking system with an instant branded job board and Plato, an AI reviewer that scores every application against your own job criteria.` That is `web/public/llms.txt:3` with its first clause replaced by "Answers about Polymer".

## Shipped questions

### 1. What is Polymer, and who is it for?
Objection: is this a job board, an ATS, or an AI tool, and is it built for a company our size?
- `web/components/home/intro.js:25-28` — "Polymer is a powerful applicant tracking system that streamlines the hiring process. Publish roles, manage applicants, and make decisions all in one platform."
- `web/public/llms.txt:3` — "an applicant tracking system with an instant branded job board and Plato, an AI reviewer that scores every application against your own job criteria"
- `web/components/home/toolkit.js:13-14` — branded company job board
- `web/components/home/brands.js:32` — "The hiring platform trusted by modern, high-growth teams" (the draft cited :18; the string is at :32, the array entry is at :18)
- `web/pages/pricing.js:217`, `:221`, `:255-256`, `:262` — Scale caps, "If you require more than 50 published jobs, custom integrations, or specialized workflows" → `mailto:support@polymer.co`

### 2. How much does Polymer cost?
Objection: price against a cheaper competitor, and the fear that the listed number is not the real number.
- `web/pages/pricing.js:26-29` — the `prices` object
- `web/pages/pricing.js:50`, `:74` — `priceCurrency: "USD"`
- `web/pages/pricing.js:108`, `:114-115` — Monthly/Annual toggle, "2 months free!"
- `web/pages/pricing.js:125`, `:165`, `:204` — plan names
- `web/pages/terms.js:173-175` — "You must pay for paid Service Plans in United States Dollars. They do not include tax. You will pay any tax."

### 3. Are features held back on the cheaper plans?
Objection: the thing I actually need is gated behind the expensive tier, so the advertised entry price is fiction.
- `web/pages/pricing.js:270`, `:272` — "All plans include everything you need" / "Every Polymer plan comes with our complete feature set—no limitations, no compromises"
- `web/pages/pricing.js:138`, `:142`, `:146`, `:150` — Starter 5/5/50, all features included
- `web/pages/pricing.js:178`, `:182`, `:186`, `:190` — Growth 20/20/100
- `web/pages/pricing.js:217`, `:221`, `:225`, `:229` — Scale 50/50/150
- `web/pages/pricing.js:302` — "Unlimited candidates"

### 4. Is there a free trial, and do we have to enter a card just to look?
Objection: the trial clock starts the moment I sign up, before I have had a chance to set anything up, and I have to hand over a card to find out.
- `web/pages/pricing.js:246-248` — "You'll have unlimited time to explore Polymer and a 14-day free trial when you publish your first job."
- https://help.polymer.co/en/articles/5729632-start-your-free-trial — "create jobs, set up your job board, add team members, and preview how your job board and jobs will look before ever providing any payment information"
- `web/components/home/ready.js:39-41` — "Click publish to start your 14-day free trial and take your job post public."
- https://help.polymer.co/en/articles/4442191-starting-a-subscription-and-publishing-your-job — "Once you add a payment method you won't be charged unless you publish a job(s)."

### 5. Can we cancel, and can we get a refund?
Objection: auto-renew trap — I will be locked into a year and there will be no way out and no money back.
- `web/pages/terms.js:180-184` — "You may cancel at any time through your account settings. This stops billing at the end of your current billing period while maintaining access with limitations. To completely cancel and delete your account, contact us at support@polymer.co."
- `web/pages/terms.js:161` — "All paid subscriptions automatically renew until you cancel them."
- `web/pages/terms.js:166-172` — the 7-day refund window
- Changelog, August 22, 2024, "Improved Billing UI & UX" — billing details and invoices remain accessible after cancelling

Note: the approved draft's answer text does not state the 7-day refund window even though the sources list it, and the question asks about refunds. Shipped verbatim as approved. Flagging it as the one place a reader's question is not fully answered by the answer — sourced text for it exists at `web/pages/terms.js:166-172` if you want it added.

### 6. Can we get our candidate data out?
Objection: lock-in — if this does not work out, my candidate history is trapped in someone else's system.
- Changelog, March 11, 2025, "Organization Data Export"
- https://help.polymer.co/en/articles/8793293-export-candidates-for-a-job-to-a-csv-file — per-job CSV columns
- Changelog, May 15, 2025, "CSV Export – Date Moved to Stage"
- `web/pages/terms.js:85-88` — "export your data as needed"

### 7. We already have candidates collected somewhere else. Do we start from zero?
Objection: switching cost — moving means abandoning the pipeline I already have.
- Changelog, September 5, 2022, "Bulk candidate import" — "enabling you to easily import candidates that you may have collected outside of Polymer"
- `web/pages/features.js:255` — "Easily import candidates via CSV from sources outside of Polymer."
- https://help.polymer.co/en/articles/4568425-manually-adding-a-candidate — contact information, links, source, desired compensation, resume by file picker or drag-and-drop

### 8. What does Plato do, and can we see why it scored a candidate the way it did?
Objection: AI screening is a black box that will silently bury good people.
- `web/components/plato/platoDescription.js:28-29` — "Plato AI reviews every application against your role's criteria, scores the fit, and shows its reasoning — so you start with your best candidates."
- `web/components/plato/platoFeatures.js:26`, `:31`, `:39`, `:47` — core/preferred/bonus, "works through them one by one, with the reasoning behind every call", and the three evidence verdicts
- `web/components/plato/platoScoringDetail.js:42-46`, `:58-62`, `:99-100` — per-criterion reasoning, "Scoring detail" panel
- `web/components/plato/platoFilter.js:53`, `:55`, `:59` and `web/components/plato/fitStars.js:23-29` — "Every candidate scored. Filter by fit and review your strongest first.", "Five fit levels", the five named bands
- `web/components/plato/platoFilterDropdown.js:19`, `:44` and `platoFilterCard.js:74` — "Filter by fit", "Clear filters", "hidden by filters"
- `web/components/plato/platoCandidateRecord.js:31-37`, `:90-96` and `platoHeroCard.js:25` — Plato as a section inside the candidate record, "Generated by Plato"
- `web/components/plato/platoVideo.js:8` and `web/images/plato-video-still.png` — "Now in beta" on the video title card

### 9. Does Plato see candidates' names and personal details?
Objection: feeding applicants' personal data into an AI is a legal and reputational risk I do not want to take.
- `web/components/plato/platoPrivacy.js:33`, `:35-37` — "Anonymized before it's scored" / "Personal details like name, location and email are removed before a candidate is sent for scoring and analysis, so the assessment stays focused on the work."
- `web/components/plato/platoFeatures.js:17` — "Turn on auto-reviews for any role, and Plato starts working the instant a candidate hits your inbox — checking role fit, relevant experience, skills, and gaps."
- `web/public/llms.txt:10` — "anonymizes candidate details before scoring"

### 10. Can we control who on the team sees what?
Objection: everyone on the account will be able to see every candidate, every salary answer, and every private comment.
- https://help.polymer.co/en/articles/4442398-setting-team-member-user-roles — Owner, Admin, Member, Interviewer permission lists
- https://help.polymer.co/en/articles/4568585-assigning-a-hiring-team-to-a-job — "By default, a user with the role of Member does not have access to any jobs."
- Changelog, September 2, 2020, "Hiring teams" — Members see only assigned jobs and only get notifications for them
- https://help.polymer.co/en/articles/8910345-request-a-review — Interviewer scope
- Changelog, October 22, 2024, "Custom Questions – Admin Only Visibility" and "Compensation Privacy Setting"
- https://help.polymer.co/en/articles/4450433-an-overview-of-candidate-management — private notes visible only to you

### 11. Will we have to change our hiring process to fit Polymer?
Objection: the tool will impose its own process and we will spend months bending our hiring around it.
- https://help.polymer.co/en/articles/5013806-customizing-the-hiring-stages-for-a-job — seven default stages, "edit your hiring stages to support any workflow", Inbox/Hired/Archived fixed, cannot delete a stage with candidates in it, job setup editable after publication
- Changelog, November 20, 2020, "Custom hiring stages" — "You can remove, add, sort, and rename hiring stages."
- `web/pages/features.js:240` — "Create custom candidate groupings that reflect your ideal hiring process."

### 12. Do we still have to email candidates from our own inboxes?
Objection: candidate conversations will scatter across personal inboxes, two of us will email the same person, and automated mail will fire when I do not expect it.
- https://help.polymer.co/en/articles/4442592-messaging-candidates — delivery to the applied-with address, the "Candidate" label in the messages feed, hiring-team visibility
- https://help.polymer.co/en/articles/4475485-using-message-templates — the six placeholders, organization-wide visibility
- https://help.polymer.co/en/articles/10122505-hiring-stage-message-automations — one automation per stage, "once" or "every time", the lightning bolt icon
- Changelog, April 21, 2025, "Skip Hiring Stage Automations"
- `web/pages/features.js:266`, `:276` — send and receive from within Polymer, bulk messaging to a hiring stage

### 13. Can the job board live on our own domain, or inside the site we already have?
Objection: candidates will get bounced to a third-party branded page, and we will have to rebuild or abandon the careers page we already paid for.
- https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain — jobs.polymer.co default, CNAME + `_acme-challenge` TXT, automatic validation and SSL, existing links keep working
- Changelog, May 24, 2023, "Embedded job board" and June 6, 2021, "Job board custom domains"
- https://help.polymer.co/en/articles/4428575-have-your-job-posts-appear-on-your-webflow-site — Webflow CMS sync
- `web/components/jobBoard/basics.js:34-40` and `web/pages/features.js:65` — "build your own front-end using our developer API"

### 14. What does Polymer integrate with, and does any of it cost extra?
Objection: the sticker price is not the real price — distribution and the integrations we need will be billed as add-ons.
- https://help.polymer.co/en/collections/2542626-integrations — the complete list of eight
- https://help.polymer.co/en/articles/4436181-have-your-job-posts-appear-in-google-jobs — on by default
- https://help.polymer.co/en/articles/8828635-post-your-jobs-to-linkedin — "no additional cost", LinkedIn Limited Listings
- https://help.polymer.co/en/articles/9415910-post-your-jobs-to-x-hiring — free, per-job External Listings opt-out, candidate-pool guidance
- https://help.polymer.co/en/articles/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace and https://help.polymer.co/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server
- https://help.polymer.co/en/articles/6218084-trigger-automated-workflows-in-zapier — the three triggers
- Changelog, November 18, 2025, "WhatJobs Job Board Integration" and https://www.polymer.co/blog/post-jobs-with-whatjobs-across-500-partners
- https://www.polymer.co/blog/post-to-we-work-remotely-6m-professionals-in-seconds

### 15. How do we handle a candidate who asks us to delete their data?
Objection: privacy requests will land on us and there will be no way to honour them or prove we did.
- https://help.polymer.co/en/articles/6122360-how-candidates-can-request-data-deletion — "To manage your data click here", company-specific
- https://help.polymer.co/en/articles/6126305-completing-a-candidate-s-request-for-data-deletion — owner notification, Admin-only completion, full deletion scope, irreversible, archived remnant, "Anonymized candidate", confirmation email

### 16. How long does setup actually take, and do we have to talk to sales?
Objection: implementation is the hidden cost — a demo call, an onboarding project, and weeks before anything is live.
- `web/components/home/ready.js:56-61`, `:34-35`, `:39-41` — "No annoying sales calls. No jumping through hoops.", "All that's required is a title and description.", the 14-day trial at publish
- `web/components/jobBoard/other.js:32-34` — "Your job board is created automatically as soon as you sign up."
- `web/components/candidateManagement/basics.js:11-14` — "Default hiring stages, application form settings, and message templates are ready to go."
- https://help.polymer.co/en/collections/2544541-quick-start-guide — the self-serve path
- https://help.polymer.co/en/articles/4440453-creating-your-first-job-post — preview at any time

## Rejected — did not ship

15 questions were dropped for lack of a source. Full reasoning is in the approved draft; the short form:

SOC 2 / pen test / uptime SLA / breach window; SSO/SAML and 2FA; what a Plato AI credit buys and what happens when they run out; AI training data and model provider; Plato bias auditing and accuracy; whether Plato ever rejects or advances on its own; turning Plato off, re-running, or overriding a score; what happens the day the 14-day trial ends; exceeding a plan's job or user cap mid-subscription; whether a hidden job still bills or counts against the cap; whether Interviewers consume a seat; invoicing/ACH/PO and the card processor; DPA and EU data residency; competitor price comparisons; whether there is a free plan.

Two of these are decisions rather than gaps and are worth a look:

- **Is there a free plan?** The changelog announced "Publish One Job for Free" on September 23, 2025 and a 2025 blog post repeats it, but `web/pages/pricing.js` has no free plan — its lowest tier is Starter. Either the pricing page or the changelog is stale. Needs your call before any free-plan answer ships anywhere on the site.
- **What happens when the trial ends?** The only help-centre sentence covering that moment describes per-job billing ("our per job pricing model will start billing for any jobs still published at that time"), which contradicts the three-tier pricing the live page sells. That help article needs updating regardless of the FAQ.

## Verification

- `next lint --file pages/faq.js --file components/footer.js --file pages/sitemap.xml.js` — no warnings or errors.
- `next dev` + `curl http://localhost:3987/faq` — HTTP 200, full answer text present in the server-rendered HTML (so it reads with JavaScript off).
- Script check against that HTML: FAQPage parses, 16 `mainEntity` entries, every `Question.name` matches a visible `<h2>` verbatim, every `acceptedAnswer` paragraph appears verbatim in the DOM, `<h2>` count 21 (16 + 4 footer + 1 `Start`), meta description 150 chars, canonical and `og:url` both `https://www.polymer.co/faq`.
- `curl http://localhost:3987/sitemap.xml` — `<loc>https://www.polymer.co/faq</loc>` present, alphabetically between changelog and features.
- Dev server stopped afterwards.

`next build` fails on `./images/clt.jpg` from `pages/about.js` with `TypeError: Failed to parse URL from .../squoosh/mozjpeg/mozjpeg_node_dec.wasm` — Next 12's squoosh image pipeline against Node 20. Pre-existing, unrelated to this change, and it reproduces without the FAQ page in the tree.
