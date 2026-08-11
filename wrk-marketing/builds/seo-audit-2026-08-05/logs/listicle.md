# Listicle rebuild – `/blog/best-applicant-tracking-software`

Instruction: `/Users/jessica/claude-hub/wrk-marketing/_in-progress/seo-content-refresh/listicle-comparison-table.md`
Draft patched: `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` (project `a6d1clb1`, dataset `production`)
Rev after patch: `guLb7mLdCgNrjUoWfCBLGX`. Content grew from 134 to 150 blocks.
Published document `fcfc319d-8b14-46d0-aef5-fc1fdd751060` untouched: still rev `LK25dP7vICeIYdOu8ZrX7Z`,
`_updatedAt` 2023-02-15T21:03:54Z, 134 blocks, no `updatedDate`.

Fields set: `content` (whole array rebuilt in place) and `updatedDate` = 2026-08-06. Author left as
`author-jessica-gertig`. `pageTitle`, `metaDescription`, `slug`, `publishDate`, `featureImage` untouched.

## How the table was rendered

`studio/schemas/blogPost.js` `content` array accepts `{ type: 'table' }`, supplied by
`sanity-plugin-another-table` (`studio/package.json`), whose row type is `tableRow`
(`studio/config/another-table.json`). The frontend renderer is `TableRenderer` in
`web/pages/blog/[slug].js` lines 247-268: it reads `value.rows`, treats `rows[0].cells` as the `<thead>`
row and `rows.slice(1)` as the body, keys each `<tr>` off `row._key`, and renders each cell as a bare
text node.

So the block written is a real Portable Text table:

```
{ _type: 'table', _key: <hex>, rows: [ { _type: 'tableRow', _key: <hex>, cells: [<string> x7] } x8 ] }
```

Two consequences of `cells` being plain strings, not Portable Text:

- The instruction's `**Tracker**` / `**Polymer**` markers are markdown emphasis in the spec document.
  They cannot be marks in a cell, and shipping them literally would print asterisks on the page, so the
  tool column carries plain `Tracker`, `Polymer`, and so on.
- `Styled.Table` in `web/pages/blog/[slug].js` (lines 703-754) already handles a seven-column table: at
  `columns >= 5` it sets `min-width: columns * 132px` and `overflow-x: auto`, so the table scrolls
  horizontally on a phone instead of being crushed. Nothing new was needed for the width.

Placement: immediately after the section intro under the H2 `7 of the best applicant tracking software
solutions for small businesses`, introduced by one line, `Here is how they compare at a glance:`.

Row order shipped exactly as approved, verified by assertion in the patch script:
`Tool | Tracker | Polymer | Breezy | Recooty | JazzHR | Zoho Recruit | Lever`.

## Cells changed because the vendor's own site contradicted the instruction

| Vendor | Cell | Instruction | Shipped |
|---|---|---|---|
| Tracker | Pricing available on website | No, custom quote | Yes, monthly |
| Tracker | How pricing works | Quote only, sales-led | Per user, per month |
| Tracker | Further job board customization | No | Customizable embed. Custom sites via API. |
| Breezy | Further job board customization | No | Embeddable widget with custom CSS. Custom sites via API. |
| JazzHR | Pricing available on website | Annual only | Yes, monthly and annual |
| JazzHR | Further job board customization | As an add-on service | Embeddable jobs widget with custom styling. Career Page Services add-on. |

Tracker publishes per-user monthly prices on `tracker-rms.com/plans/` under the heading "Simple,
Transparent Pricing for Recruitment Agencies", and documents a free single-line-of-HTML job publishing
embed with field selection, ordering, filters and a `theme` parameter that takes the customer's own
stylesheet URL (`academy.tracker-rms.com/Home/Lesson/346`), plus a general-availability Open API.
Breezy publishes its embed widget on `breezy.hr/attract` ("Further customization is available with
CSS") and a public developer API. JazzHR's pricing page publishes monthly figures behind a toggle with
working direct-checkout links, and its jobs widgets take custom CSS
(`help.jazzhr.com/s/article/Integrate-JazzHR-with-your-Career-Page-Website`).

Recooty's flagged LinkedIn cell verified as `Yes` and stayed: `recooty.com/integrations` states
"Employers can now post jobs on LinkedIn via Recooty".

Three prose-level corrections that were not cells:

- Breezy niche job board count: instruction said "approximately 40", the vendor's own tables count 44
  (18 diversity and inclusion, 12 industry, 9 remote, 5 veterans). Shipped 44.
- JazzHR prices: instruction had Hero $75/mo annual, Plus $269, Pro $420. The pricing page publishes
  Hero $1,000/yr, Plus $3,480/yr, Pro $5,508/yr, and monthly Hero $110, Plus $350, Pro $549. Shipped
  the vendor's figures.
- Recooty AI credits: instruction had 2,000 (Starter) and 5,000 (Standard). The plan cards and the
  Compare Plans grid both say 500/month. Shipped 500 for Starter; Standard's allowance was described as
  stepping up with the headcount band rather than pinned to a number, because $149 is the 1-20 band price.
- Zoho AI Assessments: instruction said October 2025, the What's New page lists it under September 2025.
  Shipped September 2025.

## Claims left out because they came back unconfirmed

Left out entirely rather than softened, per the instruction.

- **Polymer, one credit per completed Plato review.** Credits appear on Polymer surfaces only as a
  monthly plan allowance (50/100/150). The consumption rate is published nowhere Polymer owns. The entry
  says "a monthly allowance of Plato AI credits" and states no rate.
- **Polymer, Plato outputs "key skills" and "standout accomplishments" as named sections.** Zero hits
  across `polymer.co/plato`, the FAQ, the changelog, developer docs and all 35 help centre articles. The
  entry uses Polymer's own wording, "role fit, relevant experience, skills, and gaps".
- **Polymer, anonymization also removes phone and links.** Polymer states "name, location and email".
  The entry names those three only.
- **Polymer, bulk messaging and LinkedIn on a free trial need a verification request.** Nothing on any
  Polymer surface establishes the requirement or that it is a verification step rather than a plan gate.
  Omitted; the trial paragraph says nothing about it.
- **Polymer, "full CSS styling control" on the job board embed.** Polymer's own strongest wording is
  "apply your own custom styles". Shipped that wording; the table cell stayed "Customizable embed".
- **JazzHR audit trails.** No JazzHR page claims an audit trail feature; the only "audit" hits are the
  CSA CAIQ control domain name and Schellman described as an auditor. The compliance paragraph runs on
  the EEOC/OFCCP/VEVRAA/Section 503 reports and the ISO 27001 and SOC 2 Type 2 attestations instead.
- **Tracker, Jobs+ is paid.** The Jobs+ page calls it "a supplemental service" and names no price.
  Shipped "supplemental service" with no pricing claim.
- **Tracker, the Launch tier price.** The plan card says $79/user/month and the FAQ on the same page
  says $95/user/month, with no correction. No Launch price shipped; the entry says only that Launch
  covers up to five recruiters. Core's $99/user/month is unambiguous and did ship.
- **Zoho, CSS control is gated to higher tiers.** Zoho documents CSS editors for embedded job listings
  with no edition note. The prose states the CSS without a tier. The table cell "Yes, on higher tiers"
  stands on the tier gating Zoho does publish: logo customization on Standard and up, subdomain mapping
  on Professional and up.
- **Zoho, per-plan availability of Sourcing Bot, Screening Bot and AI Assessments.** Not published.
  The entry states Zia is provided at no extra cost, which Zoho does say, and names AI candidate
  matching as listed in the Enterprise plan's feature set, which the pricing page does show.
- **Zoho, bulk status changes as a distinct named action.** Only mass email and mass update are vendor
  documented. Shipped those two.
- **Lever, the bulk action toolbar is available across all packages.** The article's "Available for"
  table has no Packages row. Shipped the four roles it does name and no package claim.
- **Lever, AI Interview Companion packaging.** No Lever page states it. Shipped Employ Interview
  Intelligence as an add-on, which `lever.co/ai-features` does list under Add-Ons.
- **Lever, "fully branded experience".** `lever.co/lever-job-site/` is a 404 and the phrase is on no
  live Lever page. Replaced with the help centre's live branding controls: logos in multiple sizes and
  button colour by menu or hex code.
- **Lever, hosted Job Site supports values/mission/benefits content.** Those are Career Site Builder
  widgets, and Career Site Builder is a paid add-on. Written that way.

## Polymer screenshot

Alt text on the block keyed `276d5a80a186` changed from
`Screenshot of WRK Applicant Tracking Software Candidate Messaging Page` to
`Screenshot of Polymer Applicant Tracking Software Candidate Messaging Page`.

**The filename cannot be fixed by a patch and is still wrong.** The asset is
`image-d7a4e54a32909bd5d66a3ee66c6b042b559b627d-1999x1247-png`, whose `originalFilename` is
`wrk-applicant-tracking-software-candidate-messaging-page.png`, served at
`https://cdn.sanity.io/images/a6d1clb1/production/d7a4e54a32909bd5d66a3ee66c6b042b559b627d-1999x1247.png`.
Changing it means re-uploading the image as a new asset and repointing the block's `asset._ref`, which
is outside a patch and was not done.

Three further images elsewhere in the article carry "WRK" in their alt text and were left alone as
outside the entries this task covers:

- `dfc8bbe70435` – "Screenshot of Adding Additional Hiring Stage in WRK Applicant tracking software"
- `a3ad898d95ee` – "Screenshot of Adding New Member on WRK Applicant Tracking Software"
- `26cb8e0f52b1` – "Screenshot of Job Ad created using WRK Application Tracking Software"

## The Polymer collaboration bullet

Written to the roles-not-seats pattern used on the seven industry pages
(`web/pages/industries/*.js`, e.g. "Invite everyone - founders, engineers, advisors. With user roles and
custom permissions..."). The seat count is gone. Shipped text:

> **Collaborate with team members.** Add user roles and job assignments to create a collaborative hiring
> process with your team. Owners and Admins run the account and see every job, Members work the jobs
> they are added to, and Interviewers weigh in on a single candidate through a review request, so you
> can bring in a specialist for one hire. Share applicant profiles, send messages, leave scored reviews
> against your own review templates, and add private notes all within the platform.

Role names are Polymer's own, from `web/pages/faq.js` line 82: "The roles are Owner, Admin, Member and
Interviewer."

## Entry changes

Entry order and section rhythm unchanged; entry content replaced. The table's row order is deliberately
different from the entry order and both were preserved as given.

1. **Polymer** – angle heading's third element rewritten from "flexible pricing" to "plans that include
   every feature", which is what the current subscription model is. Six feature bullets: customizable
   job boards, job distribution, third-party integrations, AI candidate reviews, candidate messaging,
   collaborate with team members. Distribution bullet leads with LinkedIn as instructed and is followed
   immediately by the other-integrations bullet. Per-job pricing and prorated credits gone.
2. **Breezy** – angle replaced outright: "Best for accessing a pre-existing candidate pool" became
   "Best for paid niche job board integrations". The candidate-database paragraphs (the millions of job
   seekers claim and the Boolean search worked example) were deleted; that feature does not exist, and
   the one Breezy feature that ever offered an external profile database, Talent Search, is 404 on their
   help centre and absent from the pricing page's add-on list. Not mentioned, per the instruction: job
   posting approval timing, Indeed, and distribution counts. The 44 is a count of the paid niche
   catalogue, which the instruction's own angle line calls for; the free auto-distribution count was
   left out.
3. **JazzHR** – new entry, replaces SpringRecruit entirely. Knockout questions and screening automation
   are not mentioned, per the instruction. Talent Fit spelled as two words, which is JazzHR's own
   spelling throughout their help centre; the one-word form appears on jazzhr.com only inside a customer
   testimonial. The $9-per-additional-job figure was left out: it is real but lives only on
   `jazzhr.com/rbo-pricing`, a staffing-firm page that also prices Hero at $1,788/yr and caps Plus at 30
   active jobs, so quoting it beside the main page's $1,000/yr Hero would splice two different price
   sheets.
4. **Tracker** – angle kept. The two closing paragraphs about the platform taking a while to get your
   head around and not being able to go live today were removed as negative claims. Pricing rewritten
   from quote-only to the published per-user monthly prices.
5. **Recooty** – angle kept. Described as a hosted careers page with branding customization and
   explicitly not called a no-code builder, even though "Careers Page Builder (No Code)" is Recooty's
   own label on the plan cards. Bulk candidate actions stated specifically as Standard and up. The two
   sentences about limits to its customizable features and not being able to edit hiring pipeline steps
   were removed as negative claims. The widget is now sourced to `recooty.com/features/job-widget-tool`
   rather than the customer showcase.
6. **Zoho Recruit** – angle kept. No job limits printed anywhere in the entry, per the instruction. The
   free plan is described by what it covers (candidate management, email management, interview
   scheduling); the instruction's "no AI, no integrations, no resume parsing" was not shipped, both
   because negative claims are barred and because the plan comparison table lists Zapier as available on
   Free. The learning-curve paragraph was removed as a negative claim.
7. **Lever** – angle replaced outright with "Best for teams planning to scale into high-volume hiring".
   Lever is not framed as a small-business tool anywhere in the entry. The closing paragraph about room
   for improvement in job description formatting and only integrating with LinkedIn and Indeed was
   removed as a negative claim. "Custom sites via API" was not expanded beyond the cell.

## Blocks changed outside the entries

The instruction says to remove all references to per-job pricing and prorated credits; two live outside
the seven entries and were rewritten.

- Step 2 of the five-step ATS walkthrough said "other systems (like Polymer) only charge per job posting
  when it goes live". Now describes setting the job, job board and hiring stages up first and starting a
  free trial on publish.
- The "Do you want a system that's customizable?" bullet in Step 2 of the how-to-choose section said
  "and still only pay per job posting". Now ends "and every plan carries the complete feature set".

One em-dash survived outside the entries, in the Step 4 paragraph ("Probably not for long—especially
if..."), and was replaced with a comma. The patch script asserts zero em-dashes and zero en-dashes
across the whole document before it will commit.

## Verification run before commit

The patch script refuses to write unless all of these hold: draft exists and still carries
`author-jessica-gertig`; the pre-patch content is 134 blocks with the Polymer H3 at index 31, the last
Lever paragraph at index 92 and an H2 at index 93; no em-dash or en-dash anywhere in the result; no
unparsed `**` markers; no HTML entities; no "WRK" inside the rewritten entries; no "SpringRecruit"; no
match for per-job pricing, prorated or "per job posting"; exactly one table block, 8 rows by 7 columns,
in the approved row order; the same H3 count as before; and all block keys unique.

## Loose ends for Jessica, not fixed here

Polymer surfaces that contradict the article's now-current claims. A reader who checks will hit these:

- `help.polymer.co/en/articles/5729632-start-your-free-trial` still ends "our per job pricing model will
  start billing for any jobs still published at that time", and still says you can publish as many jobs
  as you like during the trial, which conflicts with the 5/20/50 published-job caps.
- `help.polymer.co/en/articles/4442191-starting-a-subscription-and-publishing-your-job` says "you'll see
  an overview of our per-job pricing model".
- `web/pages/features/jobboard.js` line 14 ships "Pay only for active jobs. Sign up free today." in the
  meta description and og:description.
- `polymer.co/changelog`, September 23 2025 entry, announces a free plan: "Polymer now offers a free plan
  that lets you publish one job at no cost." The pricing page has three paid plans and no free tier.
- `polymer.co/changelog`, August 12 2025 entry, says "Scale plan users can now remove Polymer branding
  from their job board entirely", while the pricing page lists white-label options as included on all
  plans.

Two unrelated defects noticed in blocks left untouched:

- Block keyed `775a09ac1dd4` (Step 2 intro) renders "identifying the features youactuallyneed" - the
  spans around the emphasised word have lost their spaces.
- Block keyed `e4df5521f622` (Step 2, third-party tools bullet) links to
  `https://www.wrk.xyz/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers`, the
  retired domain.

No JazzHR screenshot exists in the asset library, so entry 3 is the one entry without an image. Every
other entry kept its existing screenshot, key and asset unchanged.

---

## Adversarial-checker fixes (round 1)

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`, rev `guLb7mLdCgNrjUoWfCBLGX` -> `kJ3OpIOJnJS2LKJpQpkC5d`.
13 surgical `set` paths on the existing draft, guarded with `ifRevisionId`. Published document untouched.
Doc-wide em-dash count after the patch: 0.

### BLOCKER 1 - negative claim, block `8ff4dbef9d68` (index 12)
Was: "Some ATS systems ask for payment before you can build anything; other systems (like Polymer) let you
set up the job, the job board, and your hiring stages first and start a free trial when you publish."
Now: "With Polymer, you can set up the job, the job board, and your hiring stages first, and a free trial
starts when you publish."
The comparative is gone; the sentence states only what Polymer does.

### HIGH 2 - implied competitor feature gating, block `040d5dd6826f` (index 125)
Dropped the writer-added clause "and every plan carries the complete feature set". The bullet now ends
"In Polymer's case, you can customize your job boards, application forms, and your internal dashboards."
The preceding sentence "This sometimes means more expensive plans" is pre-existing published text and was
left alone.

### BLOCKER 3 - Breezy invented counts, block `a9ab7b0f2a28` (index 49)
Was: "Forty-four of them are aimed at a specific audience: 18 diversity and inclusion boards, 12 industry
boards, nine remote work boards, and five veterans boards."
Now: "Many of them are aimed at a specific audience, among them diversity and inclusion boards, industry
boards, remote work boards, and veterans boards."
I enumerated breezy.hr/integrations myself and got Diversity & Inclusion 19, Industry 19, Remote 9,
Veterans 4 - a third set of numbers, agreeing with neither the draft nor either checker enumeration, and
summing to 51. The page states no total anywhere. Because three independent counts of the same page
disagree, I dropped the arithmetic entirely rather than substituting the instruction's "approximately 40",
which my count also fails to support. The entry's angle (paid niche job boards) survives without it.

### HIGH 4 - Tracker careers rows, block `912bb13eda10` (index 72)
Was: "the plans page lists a branded careers page with full application and registration handling syncing
directly from Tracker, and career site integration with one-click publish on all four tiers."
Now: "the plans page lists a client job board with full application and registration handling on the Core,
Professional, and Enterprise plans, and career site integration with one-click publish on all four tiers."
Uses Tracker's own row label, splits the two rows onto their correct tiers, and drops "syncing directly
from Tracker", which appears in neither row.

### HIGH 5 - Zoho 20%, block `eebc01d37cb6` (index 98)
Was: "Monthly billing runs 20% higher at every tier."
Now: "The pricing page advertises saving up to 16% by paying yearly."
Zoho's own published comparative, in Zoho's own direction of framing.

### HIGH 6 + HIGH 8 - JazzHR bulk actions, block `b026bb937f14` (index 60)
Was: "Bulk actions come with the Plus and Pro plans and cover status changes, email, adding candidates to
an additional job, resume downloads, and texting." / "Accounts come with 500 bulk emails as standard, and
JazzHR raises that on request."
Now: "Bulk actions cover email, reject, status change, and moving candidates between jobs, and are
available to Super Admins, Recruiting Admins, and Super Users." / "JazzHR raises the bulk email limit on
request."
Action list and role restriction now match the instruction verbatim (line 84). The unverifiable plan
gating, "resume downloads", "texting" and the 500 figure are gone. The middle sentence about which roles
can send across multiple jobs was not flagged and was left in place.

### HIGH 7 - Lever date, block `a0bff5e5c354` (index 100)
Dropped "As of May 2026". Now: "It ships as one package, the Lever AI-Powered Hiring Platform."

### BLOCKER 9 - table, JazzHR "Pricing available on website"
Was "Yes, monthly and annual". Now "Annual pricing published".
I re-fetched https://www.jazzhr.com/pricing/ myself. It serves only "$1,000/yr billed annually",
"$3,480/yr billed annually", "$5,508/yr billed annually"; the label next to the toggle is "Save up to 24%
by paying yearly"; no monthly per-month dollar figure appears; all three checkout URLs are
`.../offers2/<Plan> Plan - Annual - Direct`. The checker's evidence reproduces exactly and the writer's
does not.
On the value: the instruction contradicts itself, with the approved table saying "Annual only" (line 16)
and line 82 saying "In the table this is 'Annual pricing published.'" I shipped line 82's value because it
is the instruction's explicit statement about what goes in the table, and because "Annual only" states
what JazzHR lacks, which line 25 forbids. **This is Jessica's call to confirm.**

### HIGH 10 - table, JazzHR "Further job board customization"
Was "Embeddable jobs widget with custom styling. Career Page Services add-on." Now "As an add-on service",
the instruction's approved value. The cell was not on the instruction's correctable list (lines 34-36) and
line 26 forbids expanding a cell.

### Adjacent fix, not separately listed: block `2b9840aa01ef` (index 62), JazzHR pricing prose
BLOCKER 9's disproven evidence was materialised in the prose as well: "Pricing is published both ways...
Switch to monthly and Hero is $110, Plus is $350, and Pro is $549 a month, each with a direct checkout
link." My own fetch shows no monthly figures and annual-only checkout links. Left alone it would have
contradicted the corrected table cell in the same article and published three dollar figures the vendor
page does not serve. Now: "The pricing page publishes annual rates: Hero is $1,000 a year, Plus is $3,480,
and Pro is $5,508, each with a direct checkout link, and the page advertises saving up to 24% by paying
yearly." The annual figures and the 24% both reproduce on the live page. The "Hero starts at three job
postings a month" sentence was not flagged and is unchanged.

### HIGH 11 - Polymer distribution, block `e6ae8ef1fdeb` (index 38)
Was: "Publish a job once and send it to LinkedIn, Google Jobs, X Hiring, We Work Remotely, and WhatJobs."
Now: "Publish a job once and it goes out to LinkedIn, Google Jobs, and X Hiring once you enable and
configure them. We Work Remotely and WhatJobs are paid placements you buy inside Polymer when you want the
extra reach."
Splits on the same axis `web/pages/features.js` splits on: "Automatic posting" ("Your jobs appear across
major platforms once you enable and configure them") versus "Expanded reach" ("Paid placements and custom
options"). All five channels are still named, LinkedIn still first, per instruction line 111.

### HIGH 12 - Plato credits vary by plan, block `79debf39cd1e` (index 43)
Now: "Every plan comes with the complete feature set and unlimited candidates. What moves between plans is
how many jobs you publish, how many people you bring onto the account, and your monthly allowance of Plato
AI credits."
Matches `web/pages/faq.js` line 38, which names all three varying dimensions.

### HIGH 13 - trial verification step, block `63da52bee284` (index 44)
Appended: "During the trial, bulk messaging and the LinkedIn integration open up once you send a
verification request."
Instruction line 108. Phrased as what happens rather than what is withheld, and tied to verification
rather than to a plan.

### Noted, not changed
- Block `cccfff2d7506` (index 58) says "Basic and Advanced Jobs Widgets embed a live job feed into a site
  you already have, and every unique element in them can be styled with your own CSS." No checker filed a
  finding against this sentence. I fetched jazzhr.com/features and it carries no mention of any jobs
  widget; the only career-page wording there is "Implement a 100% custom design for your career page using
  your own custom HTML & CSS." The claim's cited source, help.jazzhr.com, fails TLS verification. Left in
  place because it was not flagged.
- Table row order, and every non-JazzHR cell, unchanged.

## Breezy

Two findings from `listicle-remaining.json` concern Breezy. One rejected, one patched.

### REJECTED (MED) — "the Breezy API is there for teams that want to build the page themselves" (block index 52, _key 1ce4290c04bd)

The finding says "breezy.hr/attract ... says nothing about an API" and "No Breezy page I reached documents a public developer API." Both are wrong.

- https://breezy.hr/attract states verbatim: **"Use the Breezy API to get complete control over how and where you display your jobs data."** The same page's Support footer links to **"Developer API" → https://developer.breezy.hr/**
- https://developer.breezy.hr/ redirects to https://developer.breezy.hr/reference/overview, titled "Welcome", which states: **"The Breezy API allows you to go beyond the features we provide out of the box and build something better suited for your needs"** and **"All API endpoints are rooted in https://api.breezy.hr/v3"**
- https://developer.breezy.hr/llms.txt indexes the full public endpoint reference, including the two that carry the table cell's meaning as fixed by instruction lines 96 and 114:
  - `GET /company/{id}/positions` (https://developer.breezy.hr/reference/listpositions.md) — "Returns the positions belonging to the specified company", filterable by `state=published`
  - `POST /company/{id}/position/{id}/candidates` (https://developer.breezy.hr/reference/addcandidate.md) — **"`origin: applied` instead runs the candidate through the same path as a public application: `email_address` is then required, the position must be published (otherwise `412`), and if the position's application form has required fields not satisfied by the payload the API returns `202` and emails the candidate a link to complete them"**

That is job retrieval plus application submission against the position's application form, which is the same capability Lever earns "Custom sites via API" on at instruction line 96. The prose sentence and the "Custom sites via API" half of the table cell are both sourced. **No change made** to block 1ce4290c04bd or to table row _key 81fb1c6ce5a5.

### PATCHED (LOW) — "an overall fit assessment backed by evidence" (block index 51, _key 53340932f7cb)

Source: https://breezy.hr/qualify/candidate-management, which states "scores candidates against your job requirements. Instantly see skills alignment, experience relevance, and overall fit" (Applicant Insights), "Activity Summary uses advanced natural language processing to condense interviews, assessments, and candidate interactions into clear, conversational overviews", and "Resume Audit keeps your head above water by detecting AI-generated fakes, copy-pasted tailoring, and low-quality resumes before they reach your desk".

Three unsourced additions removed in one `set` on `content[_key=="53340932f7cb"].children[_key=="cf32471ffe0a"].text`, guarded with `ifRevisionId`:

- "an overall fit assessment backed by evidence" → "overall fit". "backed by evidence" has no vendor wording behind it.
- "turns a candidate's whole hiring journey into a crisp, actionable summary" → "uses natural language processing to condense interviews, assessments, and candidate interactions into clear, conversational overviews". "crisp, actionable" and "whole hiring journey" were the writer's adjectives.
- "runs fraud detection in the background to spot AI-generated resumes and copy-paste jobs" → "detects AI-generated fakes, copy-pasted tailoring, and low-quality resumes before they reach your desk". "in the background" was unsourced.

Numbers in the block re-verified against https://breezy.hr/pricing and kept: "Credits starting at $30/100,000", and the Bootstrap 14-day free trial's "100,000 Breezy Intelligence Credits Included".

Final text of block 53340932f7cb:

> Breezy's AI is an add-on called Breezy Intelligence, bought in credits starting at $30 per 100,000. Applicant Insights scores candidates against your job requirements, so you can see skills alignment, experience relevance, and overall fit. Resume Audit detects AI-generated fakes, copy-pasted tailoring, and low-quality resumes before they reach your desk. Activity Summary uses natural language processing to condense interviews, assessments, and candidate interactions into clear, conversational overviews. A 14-day free trial includes 100,000 credits.

No em-dashes, no negative claims, no table cells changed. Rev after patch: `guLb7mLdCgNrjUoWfCCqBQ`.

---

## Tracker (remaining-findings pass, 2026-08-06)

Three findings in `listicle-remaining.json` name Tracker. Two produced patches, one is rejected as wrong.

Patched draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` only. Two `set` operations, both on `content[_key=="92440280c5fa"].rows[_key=="0a1f352ea914"].cells[n]`, guarded with `ifRevisionId` (read rev `kJ3OpIOJnJS2LKJpQpkC5d`, wrote rev `QzNVnRn1RN9Wy2ys8Qs1Pl`, no conflict). No prose block touched, no other row touched, published document untouched.

### 1. Table cell, column 7 "Further job board customization" (MED) – RESOLVED

- Was: `Customizable embed. Custom sites via API.`
- Now: `Customizable embed. Job feed in XML or JSON.`

The first sentence stands: `academy.tracker-rms.com/Home/Lesson/346` documents the iframe embed with a `fields` parameter ("a comma separated list of fields that will be displayed for each published job and in the order they appear in this list provided"), a `filters` parameter, named themes, and "use your own custom stylesheet if you wish by passing the full URL of your custom CSS file".

The second sentence went. In this table "Custom sites via API" has a meaning fixed by the instruction at lines 96 and 114: Lever earns it on an "Apply to a Posting" endpoint and Polymer on "endpoints for submitting complete applications with question responses". `www.tracker-rms.com/tracker-open-api/` documents neither a public job-posting retrieval endpoint nor an application-submission endpoint; its coverage is "Business Development", "Client & Contact Management", "Candidate Operations", "Project Delivery", "Financial Operations" and "System Configuration", framed as "Partners and customers can build secure, purpose-built integrations". So the phrase claimed a parity Tracker's own materials do not establish.

The replacement is verbatim-sourced from the same academy lesson, which offers three output formats on the publish endpoint: HTML, "xml" which is "XML formatted and ideal for integrating into another system", and "json" which is "JSON formatted and ideal for integrating into another system". That is a real further-customization pathway, it is what block `80a025541db5` already tells the reader in prose, and it claims nothing about application submission.

Sources: `https://academy.tracker-rms.com/Home/Lesson/346`, `https://www.tracker-rms.com/tracker-open-api/`

### 2. Table cell, column 2 "Pricing available on website" (MED) – RESOLVED

- Was: `Yes, monthly`
- Now: `Yes, on the Launch and Core plans`
- Column 3 `Per user, per month` left alone: it is accurate for both tiers that publish a figure.

`www.tracker-rms.com/plans/` publishes `$79 /user/month` for Launch and `$99 /user/month` for Core, and shows "Contact Sales" with "Custom pricing" for Professional and Enterprise. "Yes, monthly" read as though all four tiers were published. The new wording states only what the page publishes, names no absence, and takes the tier-qualified form the approved table already uses at instruction line 16 for JazzHR ("Yes, on the Plus plan and up"). Prose block `d12d73f193a3` already carries the same shape: "Professional and Enterprise are custom pricing through sales."

Flagging for Jessica rather than burying it: the approved table at instruction line 12 said "No, custom quote" for this cell. It was already overridden to "Yes, monthly" in the earlier pass under the line-38 mandate to re-verify pricing visibility. This change refines that override, it does not reverse it.

Source: `https://www.tracker-rms.com/plans/`

### 3. API paragraph, block `143ff6e1f1fa` (LOW) – FINDING REJECTED, nothing changed

The finding says the seven-item CRUD record list and "interactive Swagger documentation" "are not in the retrievable announcement text". They are, on Tracker's own page. `www.tracker-rms.com/tracker-open-api/` is reachable and carries every element of the sentence:

- "interactive Swagger documentation" appears verbatim, in "It is built on modern REST architecture with comprehensive JSON responses, interactive Swagger documentation, and production-grade security."
- "full create, read, update, and delete capabilities" appears verbatim.
- All seven records are named on the page: "Business Development: Leads, opportunities, and pipeline management", "Client & Contact Management: Complete relationship data and hierarchies", "Unlike basic APIs that expose only candidate and job data", "Project Delivery: Job orders, placements, and project management", "Financial Operations: Timesheets, invoicing, and billing workflows".
- The date: "KNOXVILLE, Tenn., February 3, 2026". The draft's "In February 2026" is right.
- "Tracker's Open API is available immediately to all Tracker customers" supports "generally available to all customers".

The finding also traced Swagger to a July 2025 release in the instruction rather than this announcement; the vendor page puts it on the February 2026 announcement, which is what the draft says.

The paragraph's closing sentence, "REST API access carries a checkmark on the Professional and Enterprise plans", checks out too: `www.tracker-rms.com/plans/` shows "REST API access" ticked on Professional and Enterprise.

Sources: `https://www.tracker-rms.com/tracker-open-api/`, `https://www.tracker-rms.com/plans/`

### 4. Careers paragraph tier attribution, block `912bb13eda10` – verified, no change

The plans page row is labelled "Branded careers page", with the qualifier "Client job board with full application and registration handling syncing directly from Tracker", ticked on Core, Professional and Enterprise. "Career site integration & one-click publish" is ticked on all four. The block already attaches each to the right tiers: "the plans page lists a client job board with full application and registration handling on the Core, Professional, and Enterprise plans, and career site integration with one-click publish on all four tiers." Correct as written.

Source: `https://www.tracker-rms.com/plans/`

---

## Polymer — remaining findings pass

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` only. Published document untouched, nothing published. One guarded patch, `ifRevisionId` on a freshly read `_rev`, six narrow `set` paths keyed by `_key`. Old rev `QzNVnRn1RN9Wy2ys8Qs1Pl` to new rev `kJ3OpIOJnJS2LKJpQplLuX`. No table cell changed: no finding in this batch touches the Polymer row. Whole document now contains zero em-dashes.

### 1. Customization bullet, block `040d5dd6826f` (LOW) — changed

- Was: "In Polymer's case, you can customize your job boards, application forms, and your internal dashboards."
- Now: "In Polymer's case, you can customize your job boards and your application forms, with file upload fields, custom job categories, multi-language support, video headers, location maps, and white-label options."

The finding is right that no Polymer surface claims a customizable internal dashboard. The replacement is the Customization card's own list, verified live on the pricing page as well as in `web/pages/pricing.js` lines 334-343: "Custom application forms, File upload fields, Custom job categories, Multi-language support, Video headers, Location maps, Social share images, White-label options". Social share images dropped for length only; every item printed is on the card.

Source: `https://www.polymer.co/pricing`

### 2. Closing CTA, block `e1fc6f5e7908` (LOW) — changed

- Was: markDef `a3ae34f482e7` href `https://app.polymer.co/jobs`
- Now: `https://app.polymer.co/auth-register`

Matches every sign-up CTA on the marketing site: `components/start.js:34`, `components/navigation.js:61` and `:94`, `components/footer.js:45`, `pages/pricing.js:158/198/237`, `components/home/intro.js:33`, `components/plato/platoDescription.js:36`, plus the industry pages and `components/home/ready.js:29`. Anchor text "Sign up for free" unchanged.

### 3. Plato credit allowance, block `79debf39cd1e` (MED) — changed

- Was: "and your monthly allowance of Plato AI credits."
- Now: "and your monthly allowance of Plato AI credits, which is 50, 100, or 150 depending on the plan."

The finding asked for the consumption rate ("one credit per completed review", instruction line 113). That rate is on no reachable Polymer surface: `polymer.co/plato` states nothing about credits, `help.polymer.co` has no Plato or credits collection, and the Subscription management collection holds only "Start your free trial" and "Using a promo code". Under "nothing you cannot source ships" the rate stays out. What the vendor does publish is the allowance itself, so the allowance is what the sentence now prints: the pricing cards read "50 Plato AI credits per month", "100 Plato AI credits per month", "150 Plato AI credits per month", and the FAQ states "monthly Plato AI credits (50, 100, or 150)". That gives the reader a number to size against Breezy's and Recooty's, which was the finding's point.

Sources: `https://www.polymer.co/pricing`, `https://www.polymer.co/faq`

### 4. Dropped internal link, blocks `e6ae8ef1fdeb` and `e4df5521f622` (MED) — changed

The Job distribution bullet lost the article's only working internal link when it was rewritten. Restored: "We Work Remotely" in block `e6ae8ef1fdeb` now carries markDef `wwrlink38a1` to `https://www.polymer.co/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers`. Sentence text is byte-identical to before the split; the script asserts the rejoined spans equal the original string before committing.

Block `e4df5521f622` markDef `ab233de609d2` pointed at the same slug on `www.wrk.xyz`, which 301s to the polymer.co URL. Repointed at the canonical target: same destination, one hop fewer, retired domain out of the article's link surface.

Source: `https://www.polymer.co/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers` (loads, title "One-click We Work Remotely Distribution | Polymer")

### 5. Webflow link slug, block `3e181b241bfc` (LOW) — FINDING REJECTED, nothing changed

Left alone per instruction: the slug is deliberate, it holds 8 referring domains and there is no redirect in scope. It resolves, verified: `https://www.polymer.co/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` returns the article "Webflow Job Boards | Polymer", first heading "Easily display Polymer job posts on your Webflow site with our CMS integration".

### 6. H3 heading "plans that include every feature", block `fe51fb3687b3` (MED) — FINDING REJECTED, nothing changed

The phrase states what Polymer has and is Polymer's own published wording, not a rewording of an absence. The pricing page heads that section "All plans include everything you need" and states "Every Polymer plan comes with our complete feature set—no limitations, no compromises" (`web/pages/pricing.js` lines 270-273); the FAQ answers "Are features held back on the cheaper plans?" with "No. Every Polymer plan comes with the complete feature set". No competitor is named or implied in the heading. Instruction line 102 required "flexible pricing" to be rewritten to reflect the current subscription model, which is what this is.

Sources: `https://www.polymer.co/pricing`, `https://www.polymer.co/faq`

### 7. Free-trial contrast clause, block `8ff4dbef9d68` (LOW) — already resolved before this pass

The flagged clause "Some ATS systems ask for payment before you can build anything" is no longer in the draft. Current text: "With Polymer, you can set up the job, the job board, and your hiring stages first, and a free trial starts when you publish." Positive half only, matching `pages/faq.js` lines 44 and 125. Nothing to do.

### 8. Plato beta status, block `4d5cd6fbb56b` (LOW) — Jessica's call, nothing changed

The finding flags rather than asserts a fix, and it is a positioning decision rather than a sourcing defect, so it stays as she left it. The qualifier is live on Polymer's own FAQ: "It is currently in beta." (`web/pages/faq.js` line 70, rendered at `https://www.polymer.co/faq`). The AI candidate reviews bullet omits it. Say the word and it goes in.

### 9. Screenshot filename, block `276d5a80a186` (LOW) — closed, nothing to change

Alt text is already clean: "Screenshot of Polymer Applicant Tracking Software Candidate Messaging Page". The asset's `originalFilename` still carries "wrk" but is never emitted; the delivered URL is hash-based (`https://cdn.sanity.io/images/a6d1clb1/production/d7a4e54a32909bd5d66a3ee66c6b042b559b627d-1999x1247.png`). The same asset is referenced by `/blog/a-player`, so a rename means a new asset plus a repointed `asset._ref`, not an edit in place. Cosmetic, out of scope for a patch.

---

# Unsourced-claim pass: JazzHR

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`, project `a6d1clb1`, dataset `production`. Three narrow `set` patches on `content[_key==...].children[0].text`, guarded with `ifRevisionId`. Base rev `kJ3OpIOJnJS2LKJpQpkC5d`, new rev `kJ3OpIOJnJS2LKJpQplNDp`. No table cell touched. No other vendor's block touched. Published document untouched.

## Patched

### Block `cccfff2d7506` (content index 58) — careers page

Was:
> Every JazzHR account comes with a hosted, uniquely branded careers page on its own company subdomain. Basic and Advanced Jobs Widgets embed a live job feed into a site you already have, and every unique element in them can be styled with your own CSS. For teams that would rather hand it over, Career Page Services is an add-on where JazzHR builds and maintains a custom-branded career page for you.

Now:
> JazzHR's Careers Page Builder lets you create your own branded careers page or integrate with your existing site, with 100% customization over look and feel so candidates get a first impression that truly represents your company. You set brand colors, upload a company logo, write the hero headline, and choose a Classic, Modern, or Minimal layout, with a live preview as you work. Easy Embed integrates it with a site you already have in one line of code, and the page is 100% mobile optimized.

Source: `https://www.jazzhr.com/solutions/candidate-experience`. Every phrase is on that page: "Create your own branded careers page or integrate with your existing site. Enjoy 100% customization over look and feel so candidates get a first impression that truly represents your company." / "Careers Page Builder" / "Brand Colors" / "Company Logo" / "Hero Headline" / "Layout: Classic, Modern, Minimal" / "Live Preview" / "Easy Embed — One line of code to integrate" / "100% Mobile Optimized".

The cited source for the old sentence, `https://help.jazzhr.com/s/article/Integrate-JazzHR-with-your-Website`, returns **HTTP 404** loaded in a real browser, not only to curl. `https://help.jazzhr.com/s/global-search/API` returns zero article results to a logged-out visitor, so the help centre is not a reachable source for anything. Removed for want of a source: the widget names "Basic and Advanced Jobs Widgets", the per-element CSS claim, the "own company subdomain" claim (the vendor's own careers-page mock reads `yourcompany.com/careers`, a path on the customer's domain), and "Career Page Services is an add-on" (absent from the candidate-experience page and from `https://www.jazzhr.com/pricing/`, whose only two "Add-on" markers are Advanced Visual Reporting and Offers & eSignatures).

The table cell "Further job board customization" for JazzHR is **unchanged** at Jessica's approved "As an add-on service".

### Block `64385ecccf03` (content index 61) — integrations

Was:
> JazzHR integrates with payroll and HR systems including BambooHR, UKG Pro, and UKG Ready, alongside ADP, Gusto, Paychex, Paycor, Paylocity, and Namely. The JazzHR API is included with all subscription levels, and a candidate export integration framework uses a webhook to move candidate information into another application.

Now:
> The JazzHR Marketplace groups technology partners into categories covering HRIS and payroll, background checks and I-9s, assessments, video interviews, calendars and scheduling, single sign-on, and job distribution. Under HRIS and payroll it lists BambooHR, UKG, ADP, Gusto, Justworks, GoCo, Asure Software, MassPay, and OnPay, which JazzHR presents as a way to easily send your new hire information into one of these leading employee data management solutions. LinkedIn is listed as a preferred sourcing partner, and Verified First lets you order background checks inside JazzHR with just a couple of clicks.

Sources: `https://marketplace.jazzhr.com/provider-category/hris-payroll/` (the complete, unpaginated provider list, and the category blurb "Easily send your new hire information into one of these leading employee data management solutions") and `https://marketplace.jazzhr.com/` (the sixteen technology categories; LinkedIn carrying the "Preferred" badge under "Sourcing, System Integrators"; "Verified First — Easily order background checks inside JazzHR with just a couple of clicks"). `https://www.jazzhr.com/integrations/` 308-redirects to the marketplace.

Removed for want of a source: "UKG Pro" and "UKG Ready" (the marketplace lists one card, "UKG"), Paychex, Paycor, Paylocity and Namely (none appear in the HRIS & Payroll category, which is the vendor's full list), "The JazzHR API is included with all subscription levels" (no reachable jazzhr.com surface states it; `https://www.jazzhr.com/api/` is a 404 and the help centre is unreachable), and the candidate-export webhook framework (same absence). Nothing in the article's table rests on the API sentence.

### Block `672b9c6b73d6` (content index 57) — compliance

Second sentence was:
> Employ, the parent company, holds an ISO/IEC 27001 certificate and a SOC 2 Type 2 report, both issued by the independent third-party auditor Schellman.

Now:
> Schellman, an independent third-party auditor, has issued Employ's ISO/IEC 27001 certificate and JazzHR by Employ's SOC 2 Type 2 report.

Source: `https://www.jazzhr.com/security/`, which splits the two holders verbatim: "Schellman, an independent third-party auditor, has issued Employ's ISO/IEC 27001 certificate" and "Schellman, an independent third-party auditor, has issued JazzHR by Employ's SOC 2 Type 2 report." Finding confirmed and fixed. The first sentence of the block (EEOC, OFCCP, VEVRAA, Section 503) is unchanged.

## Finding rejected

**"Switch to monthly and Hero is $110, Plus is $350, and Pro is $549 a month" is unsourceable** (MED, content index 62). Rejected on two counts, and nothing was changed.

1. The quoted sentence is no longer in the draft. Block `2b9840aa01ef` currently reads "The pricing page publishes annual rates: Hero is $1,000 a year, Plus is $3,480, and Pro is $5,508, each with a direct checkout link, and the page advertises saving up to 24% by paying yearly. Hero starts at three job postings a month and Plus covers up to 200 active jobs." Every figure in it verifies against `https://www.jazzhr.com/pricing/`: "$1,000/yr", "$3,480/yr", "$5,508/yr", "Save up to 24% by paying yearly", "Job Postings (Starting at 3/month)*", "Up to 200 active jobs*".
2. The premise is false anyway. The monthly figures **are** published on `https://www.jazzhr.com/pricing/`; the Yearly/Monthly toggle is a client-side control, so a plain fetch never sees it, but clicking Monthly in a browser renders "Plus — For Growing Teams / $350/mo / billed monthly" and "Pro — For Serious Hiring / $549/mo / billed monthly", matching the finding's own figures exactly.

The table cell stays at Jessica's approved "Annual pricing published".

## Still unsourced, left alone as outside this vendor pass's finding list

Block `3ff1a04a7f9d` (content index 59). "Talent Fit" and its plan availability both source cleanly: `https://www.jazzhr.com/` names "TalentFit" as "AI-powered candidate matching that analyzes resumes against job descriptions", and `https://www.jazzhr.com/pricing/` lists "AI-Powered Candidate Matching" under Plus with Pro as "Everything in Plus, plus". What does not source anywhere reachable is the descriptive detail: "an overview of positives, areas to clarify, and potential concerns on the candidate profile, with a Talent Fit filter for working through a pipeline". That detail traces to the same unreachable help centre. Note also that the vendor spells it "TalentFit", one word, and the draft spells it "Talent Fit". No checker raised this block, so I have not touched it.

---

# Recooty

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`, project `a6d1clb1`, dataset `production`. One `set` patch on one span path, guarded with `ifRevisionId`. The published document was not touched.

## Verification requested by name: Recooty's "LinkedIn integration: Yes"

Instruction line 36 flagged this cell as resting on a marketing claim. It rests on more than that. Confirmed, cell unchanged.

The strongest source is Recooty's own product documentation, not marketing copy: `https://help.recooty.com/en/articles/10429368-integrating-linkedin-with-recooty`, "Integrating LinkedIn with Recooty", written 20 March 2025. It opens "Integrating LinkedIn with Recooty allows you to automatically post your job openings on LinkedIn, extending your reach and making it easier to attract quality candidates" and then walks through the actual product flow: copy your LinkedIn Company ID, then in Recooty go to Profile > Settings > "APIs & Integrations" > Integration > "Job Portal Integrations" > LinkedIn > Connect, paste the Company ID, Save/Connect. A documented connect flow with a named settings location is confirmed fact, which is what the instruction asked for.

Two supporting sources on recooty.com itself:

- `https://recooty.com/integrations` lists LinkedIn as an integration: "Employers can now post jobs on LinkedIn via Recooty and hire candidates faster."
- `https://recooty.com/` FAQ: "Is LinkedIn integration possible with Recooty ATS software?" / "Recooty ATS software delivers seamless LinkedIn integration which lets you post jobs directly to the LinkedIn job board and your company page on LinkedIn."

The Starter plan card on `https://recooty.com/pricing` also carries "Post to Indeed, LinkedIn, Google for Jobs, and more" as a plan feature, so the capability is on every tier.

## Finding rejected

**"both the price and the credit allowance step up through headcount bands above that" is an unsourced behavioural claim** (MED, content index 89, block `9af9dcc50395`). Rejected. Nothing changed. The claim is correct and I measured it directly on the vendor's page.

The finding's premise, that "recooty.com/pricing shows Standard with a single flat '5,000 AI Credits/month' alongside the employee bands", does not hold. "5,000" is static markup that the page's own script overwrites before a reader ever sees it. `https://recooty.com/pricing` carries an inline script whose data block reads:

```js
const AICreditsandCandidatesValues = [500, 1000, 1500, 2000, 2500, 'Unlimited']
const annuallyStandardValues = [149, 249, 349, 449, 'Get a Quote']
const monthlyStandardValues  = [199, 299, 399, 499, 'Get a Quote']
```

`updateStandardPricing()` is bound to the `#EmployeeCount` select and writes both `.standardPricing` and `.AICreditsandCandidates` from the same `selectedIndex`, and it runs once on load at index 0. Driving that select in a browser on the live page gives:

| Employee band | Standard, annual | AI Credits/month |
|---|---|---|
| 1-20 employees | $149 | 500 |
| 21-50 employees | $249 | 1,000 |
| 51-100 employees | $349 | 1,500 |
| 101-250 employees | $449 | 2,000 |
| 250+ employees | Get a Quote | 2,500 |

So the allowance moves with the bands exactly as the draft says, the rendered Standard card at the default 1-20 band reads "500 AI Credits/month", and the number a reader sees is never 5,000. The Compare Plans grid on the same page agrees: its Standard "AI Tool Credits" cell is the same script-driven span.

The same check clears the rest of the block. Starter "500 AI tool credits a month" is on the visible Starter card and in the Compare Plans grid ("500/month"). "$79 per month on annual billing and $99 monthly" and "$149 ... and $199 monthly" match `starterPricing` 79/99 and `annuallyStandardValues[0]`/`monthlyStandardValues[0]`. "five active job posts" is "5 Active Job Posts"; "unlimited active job posts" is "Unlimited Active Job Posts". "Bulk candidate actions come with the Standard plan and up" is "Bulk Candidate Actions" in Standard's "Everything in Starter plan, plus:" list, with Premier as "Everything in Standard plan, plus:". "Premier is custom pricing for enterprises and recruiting agencies" is "Premier / For enterprises & recruiting agencies / Custom Pricing". "15-day free trial and no credit card" is "Start a 15-day free trial" / "No credit card needed", repeated in the page FAQ as "Yes, Recooty AI provides a 15-day free trial without a credit card".

One thing to know for a future re-verification: `https://recooty.com/pricing` does contain three unreachable-by-eye numbers that disagree with the rendered page. Its JSON-LD describes Standard as "750 AI credits/month"; a `display: none` duplicate card row carries "2,000 AI Credits/month" for Starter and "5,000 AI Credits/month" for Standard. None of the three renders. Anyone re-checking this page with a plain fetch will hit them and reach the wrong conclusion, which is what happened here.

## Corrected

**Block `839f0971481c` (content index 86), careers page paragraph.** Two unsourced elements, both removed. This block was not in the finding list; I found these while sourcing the entry and fixed them because an unsourceable claim does not ship regardless of who reported it.

Was:

> Recooty's careers page is a hosted page with branding customization: your logo, a company description covering mission, values, and employee benefits, fonts, colors, and styling to match your brand personality, and photos and videos that show your culture. New roles publish to it live as you post or edit jobs in Recooty, so it mirrors your listings in real time, and you can host it free on Recooty or connect your own custom domain. Their own user guide puts the effort at no coding and as simple as changing your Instagram bio.

Now:

> Recooty's careers page is a hosted page with branding customization: your logo, a company description covering your mission, vision, and values, fonts, colors, and styling to match your brand personality, and photos and videos that show your culture. New roles publish to it live as you post or edit jobs in Recooty, so it mirrors your listings in real time, and you can host it free on Recooty or connect your own custom domain. Recooty describes the build as needing no coding, and adding open roles as literally as simple as changing your Instagram bio.

1. "employee benefits" was in no Recooty source. The careers page editor is documented at `https://help.recooty.com/en/articles/10420112-how-to-build-a-branded-careers-page-in-recooty`, whose Company Profile step says "Use the Description section to provide an overview of your company. Include details about your mission, vision, values, and workplace culture." Replaced with Recooty's own three, mission, vision and values.
2. "Their own user guide puts the effort at ..." pointed at a document that does not contain either phrase. Both phrases are on the product page `https://recooty.com/features/company-career-page`: "Launch a mobile-friendly, fully branded careers site in minutes - no coding required" and, under Build Your Page in Minutes, "Add open roles automatically - literally as simple as changing your Instagram bio." The attribution now says Recooty rather than naming a document that does not say it, and the Instagram comparison is attached to adding roles, which is what the page attaches it to.

Everything else in the block sources verbatim to `https://recooty.com/features/company-career-page`: "Choose fonts, colors, and styling to align with your brand personality", "Upload photos and videos to show your culture and values visually", "New roles are published live when you post or edit jobs in Recooty", "Always-present careers page that mirrors your ATS listings in real time", "Host for free on Recooty or connect your custom domain to own the experience".

## Checked clean, unchanged

- **Block `57d0444a1777` (index 85), AI paragraph.** "score, rank, and match candidates" is `https://recooty.com/features/ai-candidate-matching`, "automatically score, rank, and match candidates with precision". The resume-parsing sentence is that page near-verbatim: "Our intelligent resume parsing and resume insights engine generates a concise summary of candidate qualifications, utilizing natural language processing to extract and highlight relevant experience and strengths." "semantic skill matching that goes beyond exact keywords" is `https://recooty.com/features/ai-candidate-ranking`, "Semantic Skill Matching / Goes beyond exact keywords to understand skill context and related competencies". "explainable AI" is that same page plus `https://recooty.com/applicant-tracking-system`, "Rank applicants instantly with explainable AI scoring for every open role", and the matching page's "driven by explainable AI". "You can filter a pipeline by AI match score" is the ranking page's "By AI Score: Choose a scoring range (e.g., 50-100) to prioritize candidates based on algorithmic fit". "on every plan" is the Starter card's AI Top Matches, AI Resume Parsing & Score, AI Powered Recruiting Tools and AI JD Generator, with the higher tiers reading "Everything in Starter plan, plus:".
- **Block `9b41b470f824` (index 87), embed widget.** Sources line by line to `https://recooty.com/features/job-widget-tool`: "Generate embed code in Recooty and paste it into your website's body section", "Place it wherever your job listings should appear", "Widget auto-syncs with Recooty - adds or removes openings instantly."
- **Block `04ad3193ca39` (index 88), distribution.** `https://recooty.com/free-job-posting` says "We distribute your free job posting to a vast network of over 250 platforms" and "your single job post is automatically sent to over 250+ free job posting sites". Indeed, LinkedIn, Google for Jobs, Glassdoor, Monster, ZipRecruiter, SEEK, Adzuna and Jooble are all named on that page.
- **Table row `f245df304593`.** All seven cells stand as approved: Recooty / Yes, monthly and annual / Monthly, tiered plans / Yes / Yes / Yes / Embeddable widget. No em-dash anywhere in the Recooty entry.

## Two things for Jessica, no action taken

1. **Recooty's own widget page documents CSS overrides, and the approved table cell does not carry them.** Breezy's cell reads "Embeddable widget with custom CSS"; Recooty's reads "Embeddable widget". `https://recooty.com/features/job-widget-tool` has an "Advanced Custom Styling" section: "Tailor even deeper with CSS overrides for total design control. Use custom class names like .widgetContainer, .jobCardTitle, .primaryButton, etc. Apply custom CSS with !important to ensure your styles override defaults." Recooty qualifies for the same wording Breezy has. The instruction forbids expanding a cell with additional detail, so I left it, but as it stands the table under-describes Recooty against a competitor on a dimension Recooty publishes.
2. **Recooty publishes two distribution counts.** The article uses 250+ and cites the distribution page, which is right. The pricing page plan card says "Job Posting to 200+ Boards Globally", while the FAQ lower down that same pricing page says "job postings on 250+ job boards". Nothing to fix in the draft; worth knowing if the number is ever questioned.

---

## Remaining-findings pass, vendor: Zoho Recruit (2026-08-07)

Three findings in `listicle-remaining.json` name Zoho Recruit. All three rested on
"the source is unreachable". A browser reached all of them. One was a real defect and
is patched; two are rejected with the sources that disprove them.

### Rendered pricing figures, recorded

`zoho.com/recruit/pricing.html` does inject prices client-side, but they render.
Read from the live DOM (`span.zprice-visually-hidden`), both toggle states:

Corporate HR edition, https://www.zoho.com/recruit/pricing.html
| Plan | Billed annually | Billed monthly |
|---|---|---|
| FREE | US$0 | US$0 |
| STANDARD | US$25 /recruiter/month | US$30 /recruiter |
| ENTERPRISE | US$50 /recruiter/month | US$60 /recruiter |

Staffing Agency edition, https://www.zoho.com/recruit/staffing-agency-software.html#priceStaffing
| Plan | Billed annually | Billed monthly |
|---|---|---|
| FOREVER FREE | $0 | $0 |
| STANDARD | $25 /user/month | $30 |
| PROFESSIONAL | $50 /user/month | $60 |
| ENTERPRISE | $75 /user/month | $90 |

Both figures also appear as static table rows, no client-side injection, on the two
plan-comparison pages, which is the cleaner citation:
- https://www.zoho.com/recruit/corporate-plan-comparison.html — "Billed Annually | - | US$25 /recruiter/month | US$50 /recruiter/month", "Billed Monthly | - | US$30 /recruiter | US$60 /recruiter"
- https://www.zoho.com/recruit/plan-comparison.html — "Billed Annually | - | US$25 | US$50 | US$75 /recruiter/month"

Add-ons on the pricing page: Employee License US$8.34/month billed annually
(US$10 monthly), Vendor Portal US$6, Video Interviews US$12 per job opening.

### Findings resolved

**1. MED, block index 98 (`eebc01d37cb6`), Zoho pricing paragraph.** REJECTED, nothing changed.
Finding: "no dollar figures at all ... the numbers are injected client-side, so they cannot
be confirmed from the served page ... the draft prints them as exact published prices."
Every figure in the paragraph confirms against the rendered page and against the static
plan-comparison tables:
- "Corporate HR is $25 per recruiter per month on annual billing for Standard and $50 for Enterprise" — exact, both sources above. The name "Corporate HR" is Zoho's own: the page title of https://www.zoho.com/recruit/corporate-plan-comparison.html is "Plan Comparison - Zoho Recruit Corporate HR".
- "The Staffing Agency edition adds a Professional tier in the middle, at $25, $50, and $75 on annual billing" — exact.
- "Pricing is per recruiter, per month" — both editions' comparison tables use the unit label "/recruiter/month".
- "advertises saving up to 16% by paying yearly" — the pricing page prints "SAVE UP TO 16%" beside the Monthly/Yearly toggle.
- "forever free plan at $0 covering candidate management, email management, and interview scheduling" — the FREE card reads "US$0 / Forever Free / 1 active job/ recruiter license / Candidate Management / Email Management / Interview Scheduling / 8/5 support".

Table cell "Yes, monthly and annual" (row `393416c64cb0`, column 2) also stands: both
toggle states render figures, and the Corporate HR comparison table publishes a
"Billed Monthly" row alongside "Billed Annually". Cell unchanged, now sourced.

**2. MED, block index 95 (`7cc599a16b5d`), careers site paragraph.** PATCHED. Split verdict.
- "Logo customization comes with the Standard plan and up" is SOURCED and unchanged. https://www.zoho.com/recruit/corporate-plan-comparison.html row "Customize Logos": Free `-`, Standard and Enterprise `<span class="ztick" aria-label="available">`. https://www.zoho.com/recruit/plan-comparison.html row "Customize logo": Free `-`, Standard / Professional / Enterprise available.
- "subdomain mapping ... comes with Professional and up" was WRONG as an unqualified statement. Corporate HR has no Professional tier. https://www.zoho.com/recruit/corporate-plan-comparison.html row "Sub Domain": Free `-`, Standard `-`, Enterprise available. https://www.zoho.com/recruit/plan-comparison.html row "Subdomain": Free `-`, Standard `-`, Professional and Enterprise available. So it is Enterprise in Corporate HR and Professional and up in the Staffing Agency edition.

Patched `content[_key=="7cc599a16b5d"].children[_key=="c6bf1adb7c1f"].text`, guarded with
`ifRevisionId`. Was:

> Logo customization comes with the Standard plan and up, and subdomain mapping, which puts the careers site on a web address carrying your own branding, comes with Professional and up.

Now:

> Logo customization comes with the Standard plan and up. Subdomain mapping, which puts the careers site on a web address carrying your own branding, comes with Enterprise in the Corporate HR edition and with Professional and up in the Staffing Agency edition.

Rest of the paragraph verified, unchanged. The branding list traces verbatim to
https://help.zoho.com/portal/en/kb/recruit/talent-sourcing/career-site/articles/brand-your-career-site
(company logo, maximum of five top menu links, social media channels, background image,
solid background color via color picker or HEX code, background transparency, theme,
header title/subtitle/description) including "Creating your branded career site doesn't
require technical expertise." The embed sentence traces to
https://help.zoho.com/portal/en/kb/recruit/talent-sourcing/career-site/articles/embed-jobs-on-your-website:
"If you wish to remove any of these fields, you can do so by adding the following CSS to
your website with the help of CSS Editors/Style Editors:" followed by classes such as
`.zrsite_City {display: none !important;}`.

Table cell "Yes, on higher tiers" (row `393416c64cb0`, column 7) stands as approved and is
now sourced: Careers Site Pages scale 1 / 3 / 10 by tier on the Corporate HR comparison
page, logo customization from Standard, subdomain from Enterprise.

**3. MED, block index 96 (`d42aa2420f27`), Zia paragraph.** REJECTED, nothing changed.
Finding: "No cited or findable Zoho page states this scoring methodology; zoho.com/recruit/zia-ai-recruiter.html
is a 404 ... The specific weighting factors (skill rarity, co-occurring skills, proficiency,
years of experience, recency) trace to nothing."
The 404 is real; the methodology is documented, at
https://help.zoho.com/portal/en/kb/recruit/zia/overview/articles/zia-matching-overview
("Zia Matches: An Overview"), reached from the "Explore this feature" link on
https://www.zoho.com/recruit/ai-feature-roadmap.html. Verbatim:
- "Zia separates and organizes the job's skill requirements based on _Rarity_ into common and rare skills."
- "Zia looks for _Co-occurring Skills_, i.e, skills that are related to and exist together often."
- "Zia grades the candidate's skills based on Proficiency, Experience and date of Last Use." — glossed on the same page as "how good the candidate is with a skill, how long they have been using it, and how recently they've used it."

That is skill rarity, co-occurring skills, and skill quality by proficiency, experience and
recency, in Zoho's own order. The draft sentence stands.

The adjacent "half-traced" claim is fully traced, in two Zoho statements:
- https://www.zoho.com/recruit/whats-new.html, September 2025: "Introducing AI-powered Assessments & Zoho's native LLM, Zia" / "Generate assessments using Zia LLM, Zoho's native AI model."
- https://www.zoho.com/recruit/ai-feature-roadmap.html, under "Zoho's approach": "Enterprise-specific data models built that run on our own data centers with a privacy-first approach."

The remainder of the paragraph, checked while I was in it, also traces:
- Sourcing Bot and Screening Bot — https://www.zoho.com/recruit/key-features.html: "Sourcing bot: Engage candidates instantly with an AI-powered chatbot on your career site." and "Screening bot: Engage candidates instantly and screen them with predefined tests."
- Auto-trigger on apply — whats-new.html, February 2026: "Introducing Auto-trigger for Screening Bot ... Automatically initiates candidate assessments when applicants apply to roles with pre-screening."
- "AI Assessments released in September 2025" — whats-new.html, September 2025 entry above.
- "AI profile summaries" — whats-new.html, August 2025: "Introducing Profile Summary powered by Zia."
- "interview transcription and summaries" — ai-feature-roadmap.html: "Video interview transcriptions."
- "AI candidate matching is listed in the Enterprise plan's feature set" — the Enterprise card on pricing.html lists "AI Candidate Matching", and https://help.zoho.com/portal/en/kb/recruit/zia/candidate-matches/articles/candidate-matches states "Edition Required: Available for the Professional & Enterprise plans of the Staffing Agency edition and the enterprise plan of the Corporate HR edition."

### Noted, not changed, outside the three findings

Block index 97 (`c0e748a2a7d9`), mass email. "250 a day on Standard, 500 on Professional,
and 750 on Enterprise" is exact for the Staffing Agency edition
(https://www.zoho.com/recruit/plan-comparison.html row "Mass email": `-` / 250/day/org /
500/day/org / 750/day/org). Corporate HR is 250 on Standard and 750 on Enterprise, no
middle tier. The "raised up to 2,250 a day per organization for an additional cost" figure
is not on either comparison page; what those pages publish is the Mass Mail add-on at
"US$28.50 /750 mails per day". Not one of my findings and not patched, but it is the one
Zoho number in the entry I could not confirm.


---

## Lever

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`, project a6d1clb1, dataset production.
Two patches, both narrow `set` calls guarded with `ifRevisionId`, both landed first try:
rev `guLb7mLdCgNrjUoWfCFhYC` then `guLb7mLdCgNrjUoWfCG7dX`. Nothing outside the Lever row and
the Lever entry blocks was touched, and the published document was never opened for write.

`help.lever.co` serves a real page to a browser and 401s only on the retired `/hc/en-us/...`
Zendesk paths. The live paths are `https://help.lever.co/s/article/<slug>`. The pages are
client-rendered, so curl returns an empty shell; I rendered them with headless Chrome
(`--dump-dom --virtual-time-budget`) in an isolated user-data-dir. Every Lever finding that
rested on "help.lever.co returns 401" was therefore re-checked against the real page, and
three of the four turned out to be sourced.

### Changed

**1. Table, Lever row (`92440280c5fa` / row `9c0199e749a2`), column 2 "Pricing available on website".**
Was `No, custom quote`, now `Custom quote`. Same fact, no negative. This resolves the LOW
finding that flagged it as the last literal negative in the table, against the instruction's own
table rule at line 25 ("Never state or imply what a tool lacks"). Note that this is a conflict
inside the instruction: the approved table at line 18 prints "No, custom quote" verbatim. I
resolved it in favour of the standing rule, which the brief for this pass restates. Jessica can
revert it with one cell edit if she wants the approved wording back. Column 3 is untouched.
Source: https://www.lever.co/pricing/ — form headed "Get Your Customized Quote", pricing
"tailored to your organization's size and hiring needs", no figures published.

**2. AI paragraph, block `a26b0ebe0f6f`.** MED finding, upheld in full. Second sentence was:

> Alongside them sit Talent Loss Risk, Candidate Transparency, Talent Rediscovery, Fraud Signals, and unlimited AI interview transcripts and summaries.

Now:

> Alongside them sit candidate loss risk alerts, which help teams spot signs of fading interest and act on lost momentum, Candidate Transparency, which drafts personalized rejection feedback, and Fraud Signals, which identifies suspicious candidate activity automatically. AI Interview Transcripts and Summaries capture conversations and generate actionable recaps.

All against https://www.lever.co/ai-features/:
- "Talent Loss Risk" is not Lever's name for anything. Lever's FAQ on that page says
  "candidate matching and interview summaries to **candidate loss risk alerts**, fraud signals,
  and AI-powered recommendations". The feature section reads "Proactive alerts and
  recommendations help teams spot signs of fading interest and act on lost momentum before
  it's too late." Renamed to Lever's own wording.
- "Talent Rediscovery" appears nowhere on the page (0 hits for "rediscover" in the full
  rendered text) and nowhere else on lever.co that I could reach. Removed. Lever does
  document "Using advanced search and rediscovery" in the help centre
  (https://help.lever.co/s/article/Using-advanced-search-and-rediscovery), but that is not a
  named AI feature and is not what the sentence claimed, so I did not substitute it in.
- "unlimited" is not on the page. The page's own name is "AI Interview Transcripts and
  Summaries", described as "automatically capture conversations and generate actionable
  recaps". The qualifier is gone and the feature is named as Lever names it.
- Candidate Transparency ("drafts personalized rejection feedback") and Fraud Signals
  ("identify suspicious candidate activity automatically") both verify verbatim, so both stay,
  now with the vendor's own description attached.
- Talent Fit, AI Screening Companion and the Employ Interview Intelligence add-on sentence were
  already verbatim-correct and are unchanged.

**3. Careers-site paragraph, block `ab5a23c54d13`, third sentence.** Not in the findings list;
found while sourcing the rest of the block, and it is the same misnaming shape as "Talent Loss
Risk". Was "with widgets for a team gallery, benefits list, testimonials, and video embeds".
None of "team gallery", "benefits list" or "testimonials" is a Lever widget. Lever's five widget
articles enumerate the full set:
- Basic (https://help.lever.co/s/article/Career-Site-Builder-Basic-widgets): text editor, title,
  button, breadcrumbs, icon, table, navigation, anchor, text & image, list, accordion, tabs,
  countdown, copyright, spacer, file.
- Media (https://help.lever.co/s/article/Career-Site-Builder-Media-widgets): image editor, photo
  gallery, image slider, video, Lottie animation, before & after, shape, audio.
- Business (https://help.lever.co/s/article/Career-Site-Builder-Business-widgets): contact forms,
  Zoom, map, Google Calendar, click to call, click to email, business hours, multi-location, Yelp reviews.
- Social (https://help.lever.co/s/article/Career-Site-Builder-Social-widgets): Instagram feed,
  social icons, WhatsApp, social share, Twitter feed, Facebook feed, Facebook Like, Facebook
  comments, Disqus, RSS.
Rewritten to Lever's own names, same length, still a fair description:

> Career Site Builder is a paid add-on for building a custom career site connected to your Lever instance, assembled from drag-and-drop widgets that include photo galleries, image sliders, video, lists, accordions, and contact forms, with HTML and CSS editing available on any widget.

"Widgets are the building blocks of your site", "drag and drop them from the left panel" and
"Edit HTML/CSS ... Allows you to make changes to the widget's HTML or CSS" are all from
https://help.lever.co/s/article/Career-Site-Builder-Widgets-overview.

### Findings rejected, nothing changed

**"six career site options" (MED).** The count is right and it is checkable.
https://help.lever.co/s/article/Lever-Career-Site-Options states: "To have Lever power your job
site, you have **six** options, ranging from a quick 30 minutes to multiple weeks." Its comparison
table columns are numbered 1-6 (Link to Lever, Embed a JavaScript snippet, Career Site Builder,
Customize your job list, Customize your job descriptions, API for everything) and its
"Custom application questions" row reads Yes across all six. The draft sentence "Custom
application questions are available on every one of the six career site options Lever documents"
is exactly what the page says. (The article ends with an "Option 7: Displaying Subsidiary Brand
Names" section on workarounds, which is not one of the six career site options and does not
appear in the comparison table.) The same page also verifies the sentence's last clause:
"Lever's Career Site Builder is a paid add-on that you can use to create your own custom career
site connected to your Lever instance."

**Job Site logo sizes and button colour (part of the same MED).** Both sourced.
https://help.lever.co/s/article/Uploading-logos-to-your-Lever-hosted-job-site: "Lever allows you
to upload your company's logo in multiple sizes to ensure brand consistency and optimize image
positioning across various social media sites with different size specifications. You can
customize the logo on both your job site or social media sites, including LinkedIn, Facebook,
Twitter, and Slack." Sizes are given as a 1200x1200 square and a 1200x630 landscape
(https://help.lever.co/s/article/Job-site-logo-image-guidelines).
https://help.lever.co/s/article/Configure-Your-Lever-hosted-Job-Site, Logos/Style tab:
"Customize the color of the buttons on your job site by opening the Button color menu and
selecting a color or inputting the hex code for a specific color that matches your organization's
brand."

**Bulk-action toolbar roles, block `1a40e2ca863c` (part of the same MED).** Sourced, unchanged.
https://help.lever.co/s/article/Using-the-bulk-action-toolbar lists "Available for / Roles /
Super Admin, Admin, Team Member, Limited Team Member" and "Packages / Lever Basic, LeverTRM,
LeverTRM for Enterprise". Every action the draft lists is in the article's "Types of bulk
actions" breakdown: Stage ("Move selected opportunities to a different stage"), Archive ("Also
provides option to draft and send email to candidates as part of the archiving action"), Tag,
Share, Email, Nurture, Merge, plus Unarchive and Anonymize under the caron menu.

### Noted, not changed, outside the findings

Block `6c18bf500b65`: "Lever is also another HR software that works alongside a CRM. Because of
its CRM functionalities, it's ideal for performance management and analysis." Pre-existing text,
not in any finding, and I found no lever.co page claiming performance management.

---

## Breezy niche job board count restored to `40+` (2026-08-07)

Draft `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060`, project `a6d1clb1`, dataset `production`. One
narrow `set` on `content[_key=="a9ab7b0f2a28"].children[_key=="12888ff1135b"].text`, guarded with
`ifRevisionId` on a `_rev` read in the same script, landed first try: rev `guLb7mLdCgNrjUoWfCG7dX` ->
`QzNVnRn1RN9Wy2ys8QwE4B`. No other block, no table cell, no other vendor's entry touched. The
published document `fcfc319d-8b14-46d0-aef5-fc1fdd751060` was never opened for write and nothing was
published.

Reverses the drop recorded above under "BLOCKER 3 - Breezy invented counts, block `a9ab7b0f2a28`
(index 49)". That drop was wrong.

Was:

> Breezy publishes a catalogue of premium job boards you can buy a posting on, role by role. Many of
> them are aimed at a specific audience, among them diversity and inclusion boards, industry boards,
> remote work boards, and veterans boards. You add the ones you want to a cart, pay, and the posting
> goes out.

Now:

> Breezy publishes a catalogue of premium job boards you can buy a posting on, role by role. 40+ of
> them are aimed at a specific audience, among them diversity and inclusion boards, industry boards,
> remote work boards, and veterans boards. You add the ones you want to a cart, pay, and the posting
> goes out.

**Provenance, so this is not re-derived a third time.** Jessica counted the paid niche board
integrations inside the Breezy app. That list is not published on breezy.hr. `breezy.hr/integrations`
is a marketing page covering all integrations, not the paid niche job boards, so enumerating it says
nothing about her figure, and the three disagreeing enumerations of that page (44, 51, and a third)
are not evidence against it. She chose `40+` rather than a precise count because it holds under her
app count and under every public enumeration, all of which came back at or above 40.

No source URL is attached and none should be: this is a direct observation of the product, per
instruction lines 48-49. Not verified against any page and not to be verified against one. Not
softened to "many". The entry's angle is "Best for paid niche job board integrations" and the count
is what carries it.

Positive framing only, no claim about what Breezy lacks, no em-dash and no en-dash in the new text.

## Breezy widget and custom CSS, block `1ce4290c04bd` (index 52) and table row `81fb1c6ce5a5`

Item: the sentence "If you already have a careers page, Breezy's widget embeds a branded list of your
open jobs on it and takes custom CSS, and the Breezy API is there for teams that want to build the page
themselves", and the half of Breezy's "Further job board customization" cell that reads "Embeddable
widget with custom CSS". Flagged as never sourced; an earlier pass had defended only the API half.

**No change made.** Both halves are stated verbatim on Breezy's own pages, and I loaded each in a
browser rather than by fetch.

### Widget, and CSS on the widget

`https://breezy.hr/attract`, section "Already have a Careers page?":

> Use our Breezy Widget to embed a branded list of your open jobs on your own Careers Page.
> - Jobs are automatically listed on your site
> - Super simple use, no coding experience necessary
> - Further customization is available with CSS

Second, independent source. `https://help.breezy.hr/en/articles/5376777-embedding-jobs-on-your-website`,
"Embedding Jobs on Your Website", Breezy Team, March 27 2026:

> You can embed jobs on your own website with an inline widget—and add custom CSS to match your page's design.

and, under "How to embed jobs on your website":

> Admin access is required to set up the Breezy jobs widget.

The draft sentence is a close paraphrase of the first source. "Branded list of your open jobs" is
Breezy's own phrase; "takes custom CSS" is their "add custom CSS to match your page's design".

Reached through `https://help.breezy.hr/en/?q=widget`, which returns 9 results. Two more of them are on
the same capability and corroborate it: "Customizing your Career Portal"
(`https://help.breezy.hr/en/articles/5307157-customizing-your-career-portal`, "Embed Widget… With
Breezy's inline widget you can choose how to group positions—and add custom CSS to match your page") and
"Using Custom CSS on Your Careers Site"
(`https://help.breezy.hr/en/articles/5749196-using-custom-css-on-your-careers-site`).

### API, re-verified rather than taken from the earlier pass

Same `https://breezy.hr/attract` page, section "Need even more control?":

> Use the Breezy API to get complete control over how and where you display your jobs data.
> Build whatever you want; the Breezy API can handle even the most complex needs.

`https://developer.breezy.hr/reference/overview` loads and is titled "Welcome".

### Result

Sentence in block `1ce4290c04bd` stands unchanged. Table row `81fb1c6ce5a5`, column "Further job board
customization", stands unchanged at "Embeddable widget with custom CSS. Custom sites via API." The cell
matches what the prose can source, on both halves and on one page.

The instruction's flagged cell value for Breezy ("No", line 35 of `listicle-comparison-table.md`) is
contradicted by the vendor's own site, so under the instruction's own rule at line 32 the cell is
corrected rather than annotated. It was already corrected by an earlier pass; this pass supplies the
source that was missing for the widget and CSS half.

No document mutation was issued, so no `ifRevisionId` patch was needed. Document revision observed while
checking: `QzNVnRn1RN9Wy2ys8QwE4B`.

---

## Block `7cc599a16b5d`, Zoho CSS sentence and the "higher tiers" cell (2026-08-07)

**Outcome: the CSS sentence is sourced verbatim and stands unchanged. The unsourced claim was the
table cell's tier qualifier, and that is what I patched.**

### The sentence, verified in a browser

> For job listings embedded on your own website, Zoho documents the CSS to add through a style
> editor to control which fields display.

Source: https://help.zoho.com/portal/en/kb/recruit/talent-sourcing/career-site/articles/embed-jobs-on-your-website
Loaded in Playwright (help.zoho.com renders client-side; `document.body.innerText` read directly),
section "Customisation" > "2. Removing Default Fields". Verbatim:

> By default, Zoho Recruit provides certain fields for your job listings such as job type, city,
> country, date opened, job description, and experience. If you wish to remove any of these fields,
> you can do so by adding the following CSS to your website with the help of CSS Editors/Style Editors:

followed by a Fields / CSS Code table: `.zrsite_City {display: none !important;}`,
`.zrsite_Date_Opened`, `.zrsite_Job_Type`, `.zrsite_Job_Description`, then a worked example removing
Work Experience and Job Type. The same section documents adding fields the other direction through
the embed snippet's `extra_fields:["Job_Opening_ID"]` parameter, and the page lists three job
listing templates and a `brand_color` parameter. The page carries **no edition, plan or tier note**.

The sentence's "a style editor" is Zoho's own "CSS Editors/Style Editors", which are the editors on
the customer's own site, not a Zoho feature. Sentence left exactly as written.

### The cell, patched

`content[_key=="92440280c5fa"].rows[_key=="393416c64cb0"].cells[6]`, guarded with `ifRevisionId`
(base rev `QzNVnRn1RN9Wy2ys8QwE4B`).

Was: `Yes, on higher tiers`
Now: `Embeddable widget with custom CSS.`

"on higher tiers" traces to nothing Zoho publishes. Both plan comparison pages were read in the
browser, every row extracted and filtered, and neither has a row for CSS, styling, embedding or
widgets at any tier:

- https://www.zoho.com/recruit/corporate-plan-comparison.html — section **Careers Site** contains
  exactly `Candidate Portal | - | - | TICK`, `Mass Invite Candidates | - | - | TICK`,
  `Careers Site Pages | 1 | 3 | 10`; section **Portal Management** contains `Default Domain`,
  `Sub Domain`, `Vendor Portal`, `Free Portal Licenses`, `Additional Portal Licenses`. Plus
  `Career Site | TICK | TICK | TICK` (all three editions, Free included).
- https://www.zoho.com/recruit/plan-comparison.html — section **Careers Website Integration**
  contains `Candidate Portal | - | - | TICK | TICK` and
  `Career Website Pages | Yes (1) | Yes (3) | Yes (5) | Yes (10)`; **Portal Management** contains
  `Default Domain | TICK | TICK | TICK | TICK`, `Subdomain | - | - | TICK | TICK`, `Client portal`,
  `Vendor portal`, portal licences. Plus `Career Site | TICK | TICK | TICK | TICK`.

The new value is Zoho's own vocabulary. The embed snippet is
`rec_embed_js.load({widget_id:"rec_job_listing_div", page_name:"Careers", source:"CareerSite", ...})`,
so "widget" is Zoho's word, and "custom CSS" is the quoted instruction above. It also puts the cell
in the same register as the rest of that column as it now stands (Breezy "Embeddable widget with
custom CSS. Custom sites via API.", Recooty "Embeddable widget", Tracker "Customizable embed. Job
feed in XML or JSON.").

Jessica's research note "CSS/styling control on higher tiers" is the part that could not be
sourced: the CSS control is documented with no tier, and the career-site things that ARE tier-gated
(number of career site pages, subdomain) are hosted-job-board attributes, which is column 6 and
already reads "Yes".

### Correction to an earlier entry in this log

The earlier Zoho pass cited `Customize Logos` / `Customize logo` as career-site logo gating. On both
comparison pages that row sits under **Customization** / **Product Customization**, next to
`Custom Fields`, `Unique Fields`, `Custom Views`, `Mass Update`, `Offer Letter Templates`,
`Custom Links`, `Web Tabs`. It is not in the Careers Site section. The values are as stated
(Free `-`, Standard and up available), so the draft sentence "Logo customization comes with the
Standard plan and up." is accurate and I left it, but it is a product-wide logo row, not a
career-site row, and it does not support a career-site styling tier claim.

https://help.zoho.com/portal/en/kb/recruit/talent-sourcing/career-site/articles/brand-your-career-site
has no edition note on logos. The one edition statement it makes is about how many sites you get:
"Apart from the default site, you can add and customize any number of career sites based on which
edition you are in."

### Not changed

Nothing else in block `7cc599a16b5d`. No other block, no other row, no other cell touched.
