# Refresh: `/blog/best-job-board-software`

Tab 01 row 16, "Link from /features/jobboard + blog index; refresh". Both links were already in the
repo, so the refresh is the whole of this pass. Refresh = Overview issue #13: 2026 data, updated
modified dates, author bylines, downloadable templates.

Everything below is in the Sanity **draft** `drafts.8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf`. Nothing
was published. The published document `8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf` still shows
`_updatedAt: 2023-01-17T14:17:50Z`, checked after every write.

Draft fields differing from published after this pass: `content`, `featureImage`, `author`,
`updatedDate`. `author` was already `author-jessica-gertig` on the draft from an earlier phase and
was not touched.

## What the post carried before this pass

141 content blocks: one `toc`, eight images (`featureImage` plus seven inline screenshots), 132 text
blocks. The body is a seven-tool roundup, each tool with a **Pricing** H3, followed by a "How to
select" section and a closing CTA.

**Every price in the post was stale, and two claims about Polymer were flatly false.** Read end to
end for "a recent study", "last year", named-report-with-no-date and practices that have since
changed. What that surfaced beyond the prices: a hardcoded "hiring in 2022", a Polymer intro
paragraph whose text was duplicated verbatim, a "live example" link that now lands on a competitor's
ATS, a Webflow feature bullet that describes a product Webflow has never sold, an anchor pointing at
the wrong plugin, and two orphaned markDefs.

34 blocks changed. Block count is unchanged at 141: nothing was added and nothing was removed.

## The two false Polymer claims

Both came out. Current model read from `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/pricing.js`:
three tiered plans, `prices.annual = { starter: 124, growth: 233, scale: 415 }` and
`prices.monthly = { starter: 149, growth: 279, scale: 499 }`, with "Up to 5 / 20 / 50 published
jobs" and "Up to 5 / 20 / 50 users" on the three cards respectively.

### 1. The per-job pricing framework, blocks `af91b2b18b61` and `8c39e076e76c`

Before:

> Polymer uses a per-job pricing framework, so you only pay for what you actually use. You can set
> up your company, configure jobs, and invite your team for free.
>
> Once published, listings cost $10 per published job post per month.

After:

> Polymer has **three plans** in 2026: Starter at $124 per month, Growth at $233 per month, and
> Scale at $415 per month, each billed annually. You can set up your company, configure jobs, and
> invite your team for free.
>
> Starter covers up to 5 published jobs and 5 users, Growth up to 20 of each, and Scale up to 50 of
> each. Billed monthly instead of annually, the same plans are $149, $279, and $499 per month.
>
> Link on "three plans" to `https://www.polymer.co/pricing`

The second sentence of the first paragraph survived unchanged because it is still true: the pricing
page states "You'll have unlimited time to explore Polymer and a 14-day free trial when you publish
your first job."

### 2. No user limit, block `19ac4b8b6d5f`

Before: "**Get all stakeholders on board with team collaboration.** With no user limit on Polymer
accounts, you can organize your hiring team and process the way that works best for your business."

After: "**Get all stakeholders on board with team collaboration.** Polymer plans include up to 5, 20,
or 50 users in 2026, so you can organize your hiring team and process the way that works best for
your business."

The rest of the bullet (user roles, group messaging, shared comments, candidate reviews) is
untouched and still accurate.

### 3. The same false model, restated 90 blocks later, block `cd582f0939dc`

This one is not in the brief and would have survived a search for the two quoted sentences. It sits
in "Cost & pricing options", well past the Polymer section.

Before: "Alternatively, Polymer offers a pay-as-you-go model, so you can build as your company grows
its bottom line."

After: "Alternatively, Polymer's plans step up from 5 to 20 to 50 published jobs, so you can move up
a tier as your company grows its bottom line."

Fixing the two named claims and leaving this one would have left the post asserting pay-as-you-go
pricing a screen after correcting it.

## Competitor pricing, every vendor from its own site

Each figure below was read off the vendor's own pricing page today, not from a comparison site.
Where a vendor quotes both an annual and a monthly rate, the post now carries both, because the old
post quoted one rate without saying which it was.

### Niceboard, blocks `f7b26dea6951`, `1ac6957be9f0`, `5891baa1b814`

Source: `https://niceboard.co/pricing`

**Every plan was renamed and every price roughly tripled.** Essential/Pro/Business are gone; the
tiers are now Core, Advanced, Ultimate and Enterprise, and "job listings" is now "active jobs".

| | Before | After |
|---|---|---|
| Entry plan | "Essential", $103/mo billed annually, 3,000 job listings | "Core", $319/mo billed annually ($399 monthly), 5,000 active jobs |
| Mid plan | "Pro", $143/mo, 10,000 job listings | "Advanced", $479/mo billed annually ($599 monthly), 10,000 active jobs |
| Top plan | "Business", $223/mo, 100,000 job listings, foreign-language support | "Ultimate", priced on request, 30,000 active jobs |

The third block needed rewriting rather than renumbering, because **multi-language support moved
down a tier**: it is now an Advanced feature, and the plan above it caps at 30,000 active jobs, a
lower ceiling than the 100,000 the old Business plan carried. The sentence's job in the post was
"here is the plan to buy if you are going international", and that answer is now Advanced, not the
top tier. It reads:

> If you're planning on taking your job board international, multi-language support sits in that
> Advanced plan, alongside Zapier, webhooks, and real-time Google Jobs indexing. Above it, the
> Ultimate plan covers up to 30,000 active jobs and is priced on request.

Core's feature list also changed: "supports applications via link and email" is no longer how
Niceboard describes it, so the sentence now names what the page names, an applicant tracking
pipeline, a talent pool and AI-powered spam prevention.

### BambooHR, blocks `0512dcc13603`, `0601174522f8`, `265de0698b63`

Source: `https://www.bamboohr.com/pricing/`

**BambooHR now publishes its rates**, so "priced by individual quotation" is no longer true, and the
plan names changed again: Essentials/Advantage are now Core, Pro and Elite.

| | Before | After |
|---|---|---|
| Pricing model | "priced by individual quotation" | published per-employee rates, automatic volume discounts, non-profit discounts |
| Entry plan | "Essentials", around $4.95 per employee per month | "Core", $10 per employee per month |
| Next plan | "Advantage", around $8.25 per employee per month | "Pro", $17 per employee per month; "Elite", $25 per employee per month |

**One claim inverted rather than aged.** The old text said the Advantage plan "offers all these
basic features plus a designated applicant tracking system, custom reporting, and more". Applicant
tracking is now in the base plan: Core's own feature list carries Candidate Record, Job Posting,
Email & Offer Letter Templates and the Custom Report Builder. Leaving that sentence would have told
a reader to buy the middle tier for something the entry tier includes. Core's paragraph now names
those features, and Pro's paragraph names what Pro actually adds (performance management, the
employee community hub, recognition and rewards), with Elite's compensation planning and analytics
on the end.

**The seven-day trial figure was dropped rather than updated.** See QUESTIONS-FOR-JESSICA.md.

### Notion, blocks `db89f9f0c648`, `4ba83c1007de`

Source: `https://www.notion.com/pricing`

Personal Pro and Team no longer exist; the plans are Free, Plus, Business and Enterprise.

Before: "the Personal Pro and Team plans are priced at $4 and $8 per user per month respectively".

After: "the Plus and Business plans are priced at **$10 and $20 per member per month** in 2026 when
billed annually ($12 and $24 billed monthly), and offer greater scope for collaboration with
unlimited collaborative blocks, unlimited file uploads, and, on Business, SAML single sign-on and
private teamspaces."

**Where the monthly rates came from.** The rendered pricing page shows only $10 and $20 and a "Pay
monthly / Pay yearly" toggle that does not change the static markup, so the page as fetched cannot
tell you which billing term those two numbers belong to. Notion ships the answer in the page's own
`__NEXT_DATA__` payload: `plus` carries `month: unit_amount 1200` and `year: unit_amount 12000`,
`business` carries `month: 2400` and `year: 24000`. That is $12 and $24 monthly, $120 and $240 a
year, so the displayed $10 and $20 are the annual rates. Both terms are now in the sentence so
neither number can be read as the other.

Block `4ba83c1007de` said Enterprise covers "everything in the Team plan". Team is gone; it now says
Business. Enterprise is still priced on request, which is what the page shows, so that was left.

Block `40232f801538`, the free-plan paragraph, was checked and left alone: Notion still lists a $0
per member per month Free plan and the paragraph makes no dated claim.

### Google Workspace and Sheet2Site, blocks `ca34df7a49ee`, `1406ee948d31`

Sources: `https://workspace.google.com/pricing` and `https://www.sheet2site.com/pricing`

Google Workspace Business Starter moved from $6 to **$7 per user per month**, on a one-year
commitment (the page also carries a limited 50%-off-for-three-months promotion at $3.50, which the
post does not quote because it expires).

**Sheet2Site's numbers did not move, but the post was quoting them incompletely.** The page's own
`data-monthly` / `data-yearly` attributes give Basic `49/mo` monthly and `29/mo` yearly, Premium
`99/mo` monthly and `49/mo` yearly. So the $29 and $49 the post already carried are the *annual*
rates, and a reader paying monthly would have been surprised by a bill 70% and 102% higher. Both
sentences now carry both terms. Every Premium feature the post lists (three custom domains, Google
Analytics, faster page loading, chat with your users) is still on the page.

### Webflow, blocks `ee15111e1097`, `26072f6048fb`, `3e3547e60e6a`, `0ea355bf6336`

Source: `https://webflow.com/pricing`

**Webflow's whole site-plan lineup was replaced.** The old paragraphs described Basic at $12, "Webflow
CMS" at $16 with 2,000 CMS items and 200 GB bandwidth, and "Webflow Business" at $36 with 10,000
items and 400 GB. The current site plans are Starter (free), Basic ($15/mo billed yearly) and
Premium ($25/mo billed yearly, marked "New"), with the CMS and Business site plans folded into
Premium. Team and Enterprise are now platform plans, Team at $2,500/mo on an annual contract, which
is a different product from what these two paragraphs describe and is not quoted.

After:

> Building your job board in Webflow is free on the Starter plan, which publishes to a webflow.io
> subdomain. Paid site plans start at **$15 per month billed yearly** in 2026 for Basic, which adds a
> custom domain, 300 static pages, and 10 GB of bandwidth. [...]
>
> The Premium plan, which replaced the separate CMS and Business site plans, comes in at $25 per
> month billed yearly and includes the Webflow CMS with up to 20,000 CMS items, site search, and up
> to 2.5 TB of bandwidth.

"completely free until you're ready to go live" became "free on the Starter plan, which publishes to
a webflow.io subdomain", because the free tier does publish, just not to your own domain. "(with one
site editor)" went because Webflow no longer describes Basic that way.

**A feature bullet that was never true, block `3e3547e60e6a`.** Before: "**Manage your team under one
roof.** Webflow uses artificial intelligence (AI) to help you manage and organize your workforce
from anywhere." Webflow is a website builder and has never sold workforce management. Its AI is for
building the site (the pricing page lists a Webflow AI MCP server, code components and AEO agents).
The bullet's heading is about team collaboration, so the sentence under it now says what Webflow
actually offers there: "Webflow Workspaces let your whole hiring team build and edit the job board
together, with AI features built into the platform for generating and refining the site itself."

**The "live sample page" link was landing nowhere useful.** `https://webflow.com/websites/popular#stq=job%20board&stp=1`
301s to `https://webflow.com/made-in-webflow/popular`, dropping the `job board` search fragment, so
the reader got Webflow's generic popular-sites gallery. Repointed to
`https://webflow.com/templates/subcategory/job-portal-websites` (200, titled "Job Portal Website
Templates & Page Designs | Webflow"), which is the page the sentence promises.

### WordPress hosting, blocks `afa611bbba57` and `3c44feaa3829`

Source: `https://www.bluehost.com/wordpress-hosting`

Before: "Bluehost offers basic WordPress hosting starting at $2.75 per month for the first year
(renewing at $8.99 per month)."

After: "Bluehost offers WordPress hosting starting at **$3.99 per month** on a 36-month term in 2026
(renewing at $9.99 per month)."

**Both the price and the term changed**, and the term change forced a second edit. Bluehost's entry
price is no longer a first-year deal; the $3.99 Starter rate is tied to a 36-month term ("Save 60%
For 36 month term. Renews at $9.99/mo"). The neighbouring sentence in `3c44feaa3829` ended "each
offering tiers of service and **first-year deals**", which the new figure contradicts, so it now
reads "introductory deals". Updating the price and leaving the neighbour would have been exactly the
silent staleness the brief forbids.

Bluehost returns 403 to curl and to WebFetch behind Cloudflare, so the page was read through
Playwright in a real browser, where it loads normally. The old href `https://www.bluehost.com/wordpress`
was repointed to `https://www.bluehost.com/wordpress-hosting`, which is where the browser lands.

### The unsourced $299, block `f0ad6f3dcdce`

Before: "Some job board software subscriptions can be a decent hit to your budget (with some basic
plans starting at $299 per month)." No source, no vendor named, and no plan in the post cost $299
even when it was written.

After: "Some job board software subscriptions can be a decent hit to your budget: Niceboard's entry
plan starts at **$319 per month** in 2026, billed annually." Linked to `https://niceboard.co/pricing`.
The sentence keeps its job, warning about the top of the range, and now names the tool in the post
it is talking about and carries a source.

## Links that had gone wrong

### The Polymer "live example" now pointed at a competitor's ATS, block `57088a26f648`

`https://join.hel.io/` 301s to `https://jobs.lever.co/moonpay?department=MoonPay%20Commerce`. Helio
was acquired by MoonPay and its hiring moved to Lever, so the one sentence in the post inviting a
reader to see Polymer working was sending them to a **Lever-hosted board**. This is the single
worst thing the survey found.

Repointed to `https://jobs.polymer.co/motive` (200), a live Polymer-powered branded board for Motive
carrying five open roles: Customer Success Manager, Performance Manager, Website Launch Specialist,
Account Executive and OEM Program Manager. **Which customer to showcase is your call**, so it is
recorded in QUESTIONS-FOR-JESSICA.md with the alternatives. Boards checked: `/motive` and `/16vc`
and `/eli` and `/lumiinteractive` and `/m3` all return 200; `/polymer` (Polymer's own) and `/leland`
both render "We don't have any active job posts right now", so neither works as a live example.

### The legacy wrk.xyz link, block `562f0288f7cc`

`https://www.wrk.xyz/blog/four-steps-to-build-a-recruiting-strategy-for-your-startup` still resolves,
but only by 301 off the retired domain onto `https://www.polymer.co/blog/...`. Repointed to the
polymer.co URL directly.

### The plugin anchor named one product and linked another, block `50c3ff6196a1`

The sentence reads "downloading a job board plugin, like **WPJobBoard**", and the anchor's href was
`https://wpjobmanager.com/`. WP Job Manager and WPJobBoard are different plugins from different
vendors. The demo link two blocks later (`https://demo.wpjobboard.net/jobs/`) is WPJobBoard's, so
the anchor was the odd one out. Repointed to `https://wpjobboard.net/` (200), which is what the
anchor text says.

### Two orphaned markDefs removed

`2e75c91d2f97` on `030b27beb6cf` (a duplicate of the Niceboard examples link) and `f3300400f68f` on
`50c3ff6196a1` (a duplicate of the WPJobBoard demo link). Neither was referenced by any span on its
block, so neither rendered anything; the live copies of both links sit on `4b9586a7448d` and
`b7f5131135f2` and are untouched. Removing them changes nothing on the page and leaves the document
with no unused markDefs at all.

## Two other things the survey caught

**A hardcoded year, block `988ec8bbf59f`.** "hiring in 2022 is fast, organized, efficient" became
"hiring in 2026 is fast, organized and efficient". The original sentence carried two em-dashes
around "and most importantly"; since the block was being edited anyway they came out rather than
being written back in.

**Duplicated text, block `d8efb56c7dcd`.** The Polymer intro paragraph contained its own body twice:
"...video headers and interactive location maps. is the no-code, customizable job board platform
simplifying the staffing process... video headers and interactive location maps." The second copy,
which began mid-sentence with a lowercase "is", was deleted. Nothing else in the paragraph changed
and the `https://www.polymer.co/` link on "Polymer" is intact.

## Images

**Eight images, all viewed at full width off the Sanity CDN, and not one of them holds a figure the
prose asserts.** So nothing in this post is held under rule 6, and every dated figure the survey
found was replaced.

Three of the seven screenshots do carry dates rendered as pixels, none of which the prose repeats.
They are recorded in QUESTIONS-FOR-JESSICA.md as regeneration candidates rather than held figures,
because there is no prose value to hold.

| Block | What it shows | Dates or figures in the pixels |
|---|---|---|
| `featureImage` | Abstract Polymer logo tile graphic | none |
| `b833bc7b8405` | Polymer hiring dashboard, Tablespace Games, iOS Developer role | stage counts only |
| `9661a7b9d1ac` | Niceboard-powered board branded DesignerJobs | none |
| `c97c6560c67f` | BambooHR Reports screen, demo account | last-viewed dates from **2017 to 2019** |
| `ba2e470d7993` | Notion job board template page | none |
| `ecf4733ed54b` | Google Sheets used as an applicant tracker | none |
| `d442af9a2884` | Webflow "job board x" template | "Posted on: **August 24, 2021**", "$100,000 USD" salary |
| `fda151314482` | WordPress admin Job Listings screen | every post dated **January 2014** |

**All eight alt strings were rewritten from the pixels.** Every one of the old strings described the
post rather than the picture ("Screenshot of Niceboard Website", "Screenshot of Wordpress Software"),
which tells a screen reader and an answer engine nothing about what is on screen. One was wrong as
well as thin: `b833bc7b8405` was labelled "Screenshot of Wrk Website Inbox Page", naming the retired
Wrk brand, and the picture is the Polymer candidate dashboard.

Before and after for each, abbreviated to the first clause of the new text:

| Block | Before | After begins |
|---|---|---|
| `featureImage.altText` | "Best Job Board Software Header Image" | "Abstract header graphic: eight rounded squares laid out in two rows of four on a black background..." |
| `b833bc7b8405` | "Screenshot of Wrk Website Inbox Page" | "Screenshot of the Polymer hiring dashboard for a company called Tablespace Games, open on the iOS Developer role..." |
| `9661a7b9d1ac` | "Screenshot of Niceboard Website" | "Screenshot of a Niceboard-powered job board branded DesignerJobs, shown as a desktop page with a mobile version overlaid at the left..." |
| `c97c6560c67f` | "Screenshot of BambooHR website" | "Screenshot of the BambooHR Reports screen in a demo account named Your Own Co..." |
| `ba2e470d7993` | "Screenshot of Notion Software" | "Screenshot of a Notion job board template page..." |
| `ecf4733ed54b` | "Screenshot of Google sheets" | "Screenshot of a Google Sheets file named Business Report being used as a job applicant tracker..." |
| `d442af9a2884` | "Screenshot of Webflow Website\n" | "Screenshot of a Webflow job board template called \"job board x\"..." |
| `fda151314482` | "Screenshot of Wordpress Software" | "Screenshot of the WordPress admin Job Listings screen added by a job board plugin..." |

The Webflow and WordPress alts both end by naming the date printed in the picture (August 24, 2021
and January 2014), so a reader who cannot see the screenshot is told how old it is rather than being
left to assume it is current.

## Byline and updated date

`updatedDate` set to `2026-08-06`. The field is `type: "date"` in `studio/schemas/blogPost.js`, so
the value is a plain `YYYY-MM-DD` string; `web/pages/blog/[slug].js` renders it as "Updated August 6,
2026" and feeds `dateModified` in the Article JSON-LD.

`author` was already `author-jessica-gertig` on the draft from an earlier phase and was not changed,
per instruction.

## Not done, deliberately

- **No restructuring and no answer-first treatment.** Tab 01 row 16 asks for links and a refresh and
  nothing else. No heading was added, moved, merged or reworded, and the block count is unchanged at
  141.
- **No downloadable template.** Nothing on tab 01 row 16 asks this post for one and the post has no
  template to attach.
- **No metadata rewrite.** `pageTitle`, `metaDescription` and `editorialTitle` belong to Phase 4 and
  were left alone.
- **No new prose sections.** Every edit replaces text that was already in the block it sits in.
- ~~**Pre-existing em-dashes in untouched blocks were left.** They are 2023 human prose and rewriting
  blocks that carry no stale figure would be outside the brief.~~ **Corrected 2026-08-07: this
  described a state that does not exist.** A scan of all 141 blocks, not just the changed ones,
  finds zero em-dashes and zero en-dashes anywhere in the document, including every field outside
  `content`. The only em-dashes the published post ever carried were the pair around "and most
  importantly" in block `988ec8bbf59f`, and that block was rewritten in this pass, so they came out
  with it. Nothing was left.

## Verification run after the final write

- Published document `_updatedAt` still `2023-01-17T14:17:50Z`.
- Draft vs published differs in exactly four fields: `content`, `featureImage`, `author`, `updatedDate`.
- `content` still has 141 blocks, the same count it had before this pass. 34 differ; every one is
  listed above.
- No dangling marks anywhere in the document: every `marks` entry on every block resolves to a
  markDef on that block.
- No unused markDefs anywhere in the document, including the two pre-existing orphans that were
  removed.
- No em-dash and no en-dash in any changed block.
- All eight images carry alt text written from the picture.
- 28 distinct hrefs in the document. 26 return 200 under a desktop Chrome user agent. The two that
  do not are `https://www.bluehost.com/wordpress-hosting` and
  `https://www.godaddy.com/en-uk/hosting/wordpress-hosting`, both 403 to curl behind Cloudflare bot
  protection; Bluehost was confirmed loading normally in Playwright, and the GoDaddy link is
  pre-existing and unchanged by this pass.

# Fix pass

2026-08-07. Four verifier findings on this post, one HIGH and three LOW. Three were defects and were
fixed; one was a defect in this log rather than in the post and the log line has been struck and
corrected in place above. Nothing here is a decision for Jessica: every item was either true or
false against a page I read.

Draft `drafts.8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf`, three blocks changed, still 141 blocks.
Published document `8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf` re-checked after the writes: `_updatedAt`
still `2023-01-17T14:17:50Z`. A field-by-field diff of the draft before and after this pass shows
exactly three blocks differ (`29bfa3849f21`, `26072f6048fb`, `f54de8dbebf4`); `author`,
`updatedDate`, `featureImage`, block count and block order are byte-identical.

## HIGH: the retired Niceboard plan name, block `29bfa3849f21`

The refresh renamed Essential to Core, Pro to Advanced and Business to Ultimate in the three Pricing
blocks and missed this one in Core features, so the post still read "With Niceboard Business". The
log's claim above that "**Every plan was renamed**" was true of the Pricing section only.

`https://niceboard.co/pricing` was fetched again today. The tiers are Core, Advanced, Ultimate and
Enterprise; the string "Business" does not appear on the page. Two defects sat in the one sentence,
and the second is the worse of them: **`Talent pool + monetization` is listed in Core**, the $319 per
month entry plan, so the post was telling a reader to buy a top tier for something the cheapest plan
includes. Core's own list also carries "Gated jobs & applications"; what the higher tiers add is
narrower than the feature itself ("Include talent pool credits in job plans" on Advanced, "Talent
pool boolean search" and "Talent pool alerts (5,000)" on Ultimate), so the sentence's claim, browsing
the talent pool, is genuinely an entry-plan capability.

Before:

> **Create valuable connections via your talent pool.** With Niceboard Business, you can allow
> employers to browse your job seeker talent pool (your curated group of niche job seekers) and find
> the best candidates.

After:

> **Create valuable connections via your talent pool.** In 2026 Niceboard includes the talent pool in
> **Core**, its entry plan, so you can allow employers to browse your job seeker talent pool (your
> curated group of niche job seekers) and find the best candidates.

"Core" carries a new link to `https://niceboard.co/pricing`, so the tier claim ships with the page
that states it. The bold lead-in span, the bullet's `listItem` and `level`, and the closing sentence
are untouched. Same shape as the two recommendation changes already recorded in
QUESTIONS-FOR-JESSICA.md items 3 and 4: a plan change that moved the advice, not just a number.

## LOW: the unsourced Webflow plan history, block `26072f6048fb`

The block said the Premium plan "which replaced the separate CMS and Business site plans". The claim
is true of Webflow's lineup but `https://webflow.com/pricing`, the URL the section cites, carries no
plan history: the word "replaced" appears zero times and the only occurrence of "Business" on the
whole page is a footer link to a Business Value Calculator. Webflow's own help centre article
"Choose a Site plan" (`https://help.webflow.com/hc/en-us/articles/33961232582419`, 403 to curl, read
through Playwright) describes Starter, Basic, Premium and Ecommerce and likewise never mentions the
retired plans. There is no Webflow page that states the replacement, so per rule 1 the clause goes.

After: "The Premium plan comes in at $25 per month billed yearly in 2026 and includes the Webflow CMS
with up to 20,000 CMS items, site search, and up to 2.5 TB of bandwidth."

"in 2026" moved into this sentence at the same time, so the three figures no longer depend on the
previous block for their year. All three were re-verified on the pricing page today: the plan
comparison table gives Premium 20,000 CMS items and "Up to 2.5 TB/month" bandwidth, and site search
is listed in the Premium card.

## LOW: the plain-HTTP Notion link, block `f54de8dbebf4`

The "Notion" anchor pointed at `http://notion.so`, which walks three redirects cross-host to
`https://www.notion.com/`. Repointed straight at `https://www.notion.com/` (200, no redirects). The
verification note above counted this href in "26 return 200" because it does eventually return 200;
it reached that 200 by way of an insecure first hop. The post's two other Notion links
(`https://www.notion.so/templates` and `https://www.notion.so/templates/nonprofit-job-board`) are
https and each 301s once to its notion.com equivalent, which is a vendor's own domain move and was
left alone.

## LOW: the em-dash claim in this log

Corrected in place under "Not done, deliberately". Zero em-dashes and zero en-dashes in the whole
document.

## Re-read of the whole draft, every vendor, after the fixes

Every plan name and every price in the post was checked against the vendor's own page today, not
against the earlier pass's notes.

| Vendor | Source read today | Verdict |
|---|---|---|
| Niceboard | `https://niceboard.co/pricing` | Core $399/mo, $319 billed annually, 5,000 active jobs; Advanced $599/$479, 10,000, and Multi-language support in its list; Ultimate contact sales, 30,000. All three Pricing blocks correct |
| Polymer | `https://www.polymer.co/pricing` and `web/pages/pricing.js` | Starter $124, Growth $233, Scale $415 annual; 5/20/50 published jobs and 5/20/50 users on the cards; `prices.monthly` still `{starter: 149, growth: 279, scale: 499}`. The trial sentence matches the page's "unlimited time to explore Polymer and a 14-day free trial" |
| BambooHR | `https://www.bamboohr.com/pricing/` | Core $10, Pro $17, Elite $25 per employee per month, all three stated twice on the page. Core lists Employee Records, Custom Report Builder, Workflows and Approvals, Dashboards, Candidate Record and Job Posting; Pro adds Performance Management, Employee Community, Recognition & Rewards; Elite adds Compensation Planning and Salary Benchmarking. "Volume and non-profit discounts are available" is on the page verbatim |
| Notion | `https://www.notion.com/pricing` | Free, Plus, Business, Enterprise. Plus $10 and Business $20 per member per month rendered; `__NEXT_DATA__` still gives `plus` month 1200 / year 12000 and `business` month 2400 / year 24000, so the $12 and $24 monthly figures hold. Unlimited collaborative blocks and unlimited file uploads on Plus, SAML SSO and private teamspaces on Business, Enterprise "Everything in Business, and:" with User provisioning (SCIM) and Customer success manager |
| Google Workspace | `https://workspace.google.com/pricing` | Starter $7.00 per user per month under "Annual (Save 16% with 1 year commitment)". The 50%-off-for-three-months promotion now shows dates, 20 Aug to 20 Nov 2026, and is still not quoted |
| Sheet2Site | `https://www.sheet2site.com/pricing` | `data-yearly` 29/mo and `data-monthly` 49/mo on Basic, 49/mo and 99/mo on Premium, with $348 and $588 annual totals. Basic "Connect 1 Custom domain"; Premium "Connect 3 Custom domains", Google Analytics, 2x Faster page loading, Chat with your users |
| Webflow | `https://webflow.com/pricing` | Starter free, Basic $15/mo billed yearly with custom domain, 300 static pages, 10 GB bandwidth; Premium $25/mo billed yearly |
| Bluehost | `https://www.bluehost.com/wordpress-hosting` via Playwright, still 403 to curl even with full browser headers | "Starter ... $3.99/mo Save 60% For 36 month term Renews at $9.99/mo" |

Three claims were checked and deliberately left, none of them a figure:

- **"You can try out BambooHR for free before you buy"**, block `0512dcc13603`. The word "trial" does
  not appear on `https://www.bamboohr.com/pricing/` at all, but `https://www.bamboohr.com/signup/` is
  headed "Sign Up for a BambooHR Free Trial" and says "No credit card required. Trial ends
  automatically", and the homepage carries two "Start Free Trial" buttons. The claim is true and
  carries no number, so it stays as written; the open question about the trial's length is already
  recorded in QUESTIONS-FOR-JESSICA.md.
- **Notion Enterprise "custom contracts"**, block `4ba83c1007de`. The pricing page lists Enterprise as
  "Custom pricing" with a Contact Sales button and does not use the phrase "custom contracts". User
  provisioning (SCIM) and Customer success manager are both listed. The phrase predates this refresh
  and asserts no figure, so it was not rewritten.
- **All 141 blocks re-scanned for plan and product names.** The only stale one in the document was
  "Niceboard Business". "Business" now appears three times, all of them current: Notion's Business
  plan twice, and once in the ordinary sense.

## Verification after the fix pass

- Published `_updatedAt` still `2023-01-17T14:17:50Z`.
- Draft still 141 blocks, same keys in the same order.
- Exactly three blocks differ from the pre-fix draft; every other field is unchanged, including
  `author` (`author-jessica-gertig`) and `updatedDate` (`2026-08-06`).
- No dangling marks and no unused markDefs anywhere in the document.
- Zero em-dashes and zero en-dashes anywhere in the document.
- Every href in the post re-checked under a desktop Chrome user agent. `http://notion.so` is gone;
  `https://www.notion.com/` returns 200 with no redirect. Bluehost and GoDaddy still 403 to curl
  behind Cloudflare and are unchanged from the earlier pass.
