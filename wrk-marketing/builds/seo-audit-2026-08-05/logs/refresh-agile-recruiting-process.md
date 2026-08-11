# Content refresh, `/blog/agile-recruiting-process`

Tab 13 row 7 ("Light refresh"), tab 01 row 13 ("Link + refresh").
Ranking #1-4 on agile recruiting / agile recruitment (50 vol), 4 referring domains, 7 ranking keywords.

Everything below is a Sanity **draft** patch. The published document was not touched and its `_rev` is
unchanged (`1GPeuoR4D0aUdfgdz93zDL` before and after).

- Published document: `bc1fe908-c69f-4919-89f9-9edcc1222507`
- Draft patched: `drafts.bc1fe908-c69f-4919-89f9-9edcc1222507`
- Draft `_rev` before: `guLb7mLdCgNrjUoWfC1fvG`
- Draft `_rev` after: `QzNVnRn1RN9Wy2ys8Qp6on`
- The draft existed already and carried one pending change, the author assignment
  (`author-jessica-gertig`). That reference was read and left exactly as found. No other pending
  change was on this draft.

Patch method: `@sanity/client` 2.23.2 from `web/node_modules`, run from a throwaway script in the
scratchpad, using keyed set paths (`content[_key=="..."].children[_key=="..."].text`) so only the
named spans moved. No whole-array replacement, no repo file written, no publish.

---

## 1. Survey of everything dated in the post

The post is 126 content blocks. All 126 were read, not scanned for `%` and four-digit years. What the
survey turned up, in document order:

| Block key | What it carries | Verdict |
|---|---|---|
| `565002e9de94` | McKinsey, "30% gains in efficiency, customer satisfaction, employee engagement, and operational performance" | **Source unreachable. Left as found and logged.** See section 4. |
| `38ca8dd93505` | "a model first developed in 2001 by a team of software developers" | Historical fact about the Agile Manifesto, correct, not a stale figure. No change. |
| `c63776ee3170` | "only 40% of employers test candidates' skills or general abilities", linked to HBR 2019 | **Replaced.** See section 2. |
| `17441d8777e3` | Predictive hiring paragraph, linked to Forbes 2019 | Carries no figure. Link resolves 200. No change. |
| `ffe1077ff7e1` | "teams should be between three and ten employees" | Scrum team sizing, no year attached, no source link, and the 2020 Scrum Guide's "10 or fewer" does not contradict it. Not a dated figure. No change. |
| `ab1b3706455c` | "Recruiting as a Service model (RaaS)" | Named model, no figure, no date. No change. |
| `3e22708438de` | "$4,000 and 24 days to hire an employee" (Glassdoor) and "$1,308 per worker" (Statista) | **Both replaced.** See section 2. |
| `e4d77b9557fb` | "Recruitment in 2022 has moved beyond..." | **Replaced.** Bare stale year in prose. |
| `1336db02167d` | "asynchronous voice communication (a rapidly growing communication method)", linked to yac.com | Undated trend claim. The linked article is still live and still on topic (`What is Asynchronous Communication? A Complete Guide`, HTTP 200). No figure to replace. No change. |

---

## 2. Figures replaced

### 2a. Skills testing, block `c63776ee3170`

**Before**

> Failure to define performance criteria (only **40% of employers** test candidates' skills or general
> abilities)
>
> link: `https://hbr.org/2019/05/your-approach-to-hiring-is-all-wrong`

**After**

> Failure to define performance criteria (in 2026, **30% of employers** still don't use skills-based
> hiring)
>
> link: `https://www.naceweb.org/job-market/trends-and-predictions/employer-use-of-skills-based-hiring-practices-grows`

**Source.** NACE, "Employer Use of Skills-Based Hiring Practices Grows", published **12 January 2026**,
by Kevin Gray. Verbatim: "The use of skills-based hiring by employers is growing, according to results
of NACE's Job Outlook 2026 survey. Among survey participants, 70% report using skill-based hiring, up
from 65% last year." Data collected 7 August to 22 September 2025 from 183 respondents, 170 of them
NACE employer members. The 30% in the prose is NACE's own 70% stated from the other side, which is what
the bullet needs, because the bullet is a list of pitfalls and a positive adoption figure would not
support it.

The HBR 2019 link was the only thing on the page still citing a 2019 survey as current practice.

### 2b. Cost per hire and time to fill, block `3e22708438de`

**Before**

> When we factor in everything from recruitment drives to interviewing, onboarding, and training, it
> costs about **$4,000 and 24 days to hire an employee**. By contrast, the average CPD course is much
> more cost-effective. On average, learning and development training costs **$1,308 per worker**.
>
> links: `https://www.glassdoor.com/employers/blog/calculate-cost-per-hire/` (403)
> and `https://www.statista.com/statistics/738519/workplace-training-spending-per-employee/` (302)

**After**

> When we factor in everything from job ads and agency fees to recruiter pay and candidate travel, the
> median cost to fill a nonexecutive role in 2026 was **$1,300, and the median time-to-fill was 39
> calendar days**. By contrast, the average CPD course is more cost-effective. In 2025, learning and
> development training cost an average of **$874 per learner**.
>
> links: `https://www.shrm.org/topics-tools/research/recruiting-benchmarking/full-data-brief`
> and `https://trainingmag.com/2025-training-industry-report/`

**Sources.**

- SHRM, *2026 Recruiting Executives Benchmarking: Attracting Critical Talent*, 2026. Verbatim: "the
  median cost-per-hire for nonexecutive positions increased only slightly from $1,200 in 2025 to
  $1,300 in 2026" and "The time needed to fill open positions has decreased to a median of 39 calendar
  days for nonexecutive positions in 2026, compared to 44 days in 2025." Read directly off the SHRM
  page, not off a secondary summary.
- Training Magazine, *2025 Training Industry Report*. Verbatim: "Overall, on average, companies spent
  $874 per learner this year compared with $774 per learner in 2024." No 2026 edition of this report
  exists yet; it publishes in the autumn, so 2025 is the most recent published value for this figure
  and the sentence now says 2025 so it does not read as newer than it is.

**Two wording changes were forced by the new figures and are not free prose.**

1. The opening clause used to say the figure factored in "onboarding, and training". SHRM's published
   definition of cost-per-hire is "third-party agency fees, advertising agency fees, job fair costs,
   online job board fees, employee referral costs, travel costs of applicants and staff, relocation
   costs, recruiter pay and benefits, and talent acquisition system costs divided by the number of
   hires". Onboarding and training are not in it. Leaving the old clause would have misattributed the
   figure, so the clause now names what SHRM actually counts.
2. "much more cost-effective" became "more cost-effective". At $4,000 against $1,308 the "much" was
   earned. At $1,300 against $874 it is not, and the sentence would be overstating its own source.

Both old links were dead ends before the change: Glassdoor returns 403 and the Statista series is
behind a redirect to a paywall. Both replacements were fetched and read.

### 2c. Stale year, block `e4d77b9557fb`

"Recruitment in **2022** has moved beyond simply requiring '15 years of experience in the position.'"
became "Recruitment in **2026** has moved beyond...". Nothing else in that sentence changed.

### 2d. Orphaned markDefs, block `71194acb4b47`

The paragraph immediately before the cost paragraph carries a duplicate copy of the same two markDefs
(`0d3fc8aa5f6c` Glassdoor, `c262bcfacbfc` Statista) with no span referencing them. They render nothing,
but they are two dead source URLs sitting in the document. Both hrefs were repointed to the same new
sources so nothing left in the post points at a page that no longer states the figure. No text in that
block changed.

---

## 3. Images

All four graphics were downloaded from the Sanity CDN and viewed.

**No graphic in this post carries a dated figure**, so nothing was held and nothing needs regenerating.
Every dated figure in the post is prose-only and every one of them was replaced. The three product
screenshots show UI (a job board, a candidate pipeline, a team list) with sample data and no statistics
or dates; the manifesto card carries only the 2001 manifesto text and its 17 signatory names, which is
the historical fact the surrounding prose already states correctly.

Alt text was rewritten from what each graphic shows.

**Feature image** (`featureImage.altText`)

- Before: "Agile Recruiting Process Header Image"
- After: "Line drawing of three nested loops of increasing size sitting on a horizontal arrow that
  points right across a black background, representing repeated sprint cycles carrying a project
  forward"
- What it shows: white line art on black, three concentric open loops of increasing diameter resting on
  a long horizontal arrow that terminates in an arrowhead at the right.

**Block `40eb93eb5891`** (under "The Agile Manifesto laid out guidelines...")

- Before: "Screenshot of Manifesto for Agile Software Development"
- After: "The Manifesto for Agile Software Development, listing its four values: individuals and
  interactions over processes and tools, working software over comprehensive documentation, customer
  collaboration over contract negotiation, and responding to change over following a plan, above the
  names of its 17 signatories. Source: agilemanifesto.org"
- Why the long form: this is the one graphic on the page that carries substantive content rather than
  decoration. The four values are rendered only as pixels, and the surrounding prose never lists them.
  An answer engine reading the old alt learned nothing; it now gets the full text of the four values.

**Block `c6c93f25710d`** (Polymer job board)

- Before: "Screenshot of Wrk or Polymer Job Board"
- After: "A Polymer job board page headed 'We are hiring!' with dropdown filters for job location, job
  category and job type, and one listing under Software Development: Senior Front-end Developer, tagged
  Full-Time, US and Remote friendly, with a View job button"
- The old alt was hedging between two brand names inside the alt attribute itself. The graphic shows no
  brand mark at all, so the hedge was never resolvable from the image; the caption below it names
  Polymer, which is what the alt now says.

**Block `44b6a332588f`** (candidate management dashboard)

- Before: "Screenshot of Polymer's Candiate Management Dashboard" (misspelling "Candiate" was in the alt)
- After: "Polymer's candidate management dashboard for an iOS Developer role, with pipeline stages down
  the left (Inbox 11, Screen 19, Interview 4, Decide 1, Offer 0, Archive 4), the applicant list in the
  middle, and the selected candidate Ella Patterson on the right showing an 'Applied from job board'
  tag alongside her Activity, Resume, Document, Messages and contact details"

**Block `844d67fb30ac`** (team members)

- Before: "Screenshot of Polymer Create User Role Page"
- After: "A Polymer team list showing three members, Meg Barnes, Chuck Donner and Doug Sims, each with
  an avatar, email address and an actions menu, above an Add team member button"
- Worth knowing: the old alt described a page that is not what the screenshot shows. There is no role
  creation form in the image, only an existing team list and an "Add team member" button. The paragraph
  under it says "You can then create user roles and assign teammates to jobs", so the prose promises a
  screen the graphic does not show. The alt now describes the graphic. Whether the screenshot should be
  swapped for the actual role screen is a content call, not a refresh call, so it was left alone.

---

## 4. Not reached

**McKinsey, block `565002e9de94`.** The sentence "According to McKinsey, successful agile
transformations typically deliver around '30% gains in efficiency, customer satisfaction, employee
engagement, and operational performance'" was left exactly as found, and its link was left on the old
`/business-functions/` path.

mckinsey.com refused every automated request: `curl` with a browser user agent returned `000` on both
the old `/business-functions/` path and the current `/capabilities/` path, WebFetch timed out twice at
60 seconds, and the Wayback availability API rate-limited. Search results do report the figure verbatim
from the live `/capabilities/` page, so the claim appears intact, but I could not read the source
myself and therefore did not rewrite the sentence and did not repoint the URL to a path I could not
confirm serves the article. Logged as a named entry in QUESTIONS-FOR-JESSICA.md.

---

## 5. Byline and updated date

- `author` was already `author-jessica-gertig` on the draft. Read, verified, left untouched.
- `updatedDate` set to `2026-08-06`. The field is `type: "date"` on `studio/schemas/blogPost.js` line
  82 and feeds both the JSON-LD `dateModified` (`web/pages/blog/[slug].js` line 291) and the visible
  "Updated August 6, 2026" byline (lines 397-398).
- `publishDate` left at `2023-01-03`.

---

## 6. Not done, deliberately

- **No restructuring.** The post ranks #1-4 on its head terms. No new sections, no answer-first blocks,
  no heading changes, no reordering.
- **No downloadable template.** Tab 13 asks for one on rows 3 and 4, not on row 7.
- **Internal linking not touched.** Tab 01's "Link" column is about linking *to* this orphaned page
  from `/blog` and related posts, which is a different pass on a different file.
- **The two `wrk.xyz` links were left alone.** Blocks `0005699970a2` and `36f48f41793c` share markDef
  `a376d3ed1d9e` pointing at `https://www.wrk.xyz/` while the anchor text says Polymer. That is the
  Wrk legacy item (tab 10, phase 6), which already has its own drafts and its own log, and it carries
  no figure. Noted here so it is not read as missed.

---

# Fix pass

Five verifier findings on this post (3 MED, 2 LOW). Three were defects and are fixed; two are
Jessica's call and are recorded rather than fixed. Nothing was rejected as wrong: every factual
claim the verifier made about this post checked out.

Draft patched again: `drafts.bc1fe908-c69f-4919-89f9-9edcc1222507`.
`_rev` before `QzNVnRn1RN9Wy2ys8Qp6on`, after `QzNVnRn1RN9Wy2ys8QuHcn`, guarded with `ifRevisionId`.
Published document still `1GPeuoR4D0aUdfgdz93zDL`, re-checked after the patch and unchanged.
`author` still `author-jessica-gertig`, `updatedDate` still `2026-08-06`, still 126 content blocks.
Eight keyed `set` paths, no array rewrite, no publish.

## 1. Fixed: the NACE bullet, block `c63776ee3170` (MED, two findings)

**Before**

> Failure to define performance criteria (in 2026, **30% of employers** still don't use skills-based
> hiring)
>
> link: `https://www.naceweb.org/job-market/trends-and-predictions/employer-use-of-skills-based-hiring-practices-grows`

**After**

> Failure to define performance criteria (in 2022, **56% of employers** used pre-employment
> assessments to gauge job applicants' knowledge, skills and abilities)
>
> link: `https://www.shrm.org/about/press-room/new-shrm-research-makes-case-skills-based-hiring`

Both findings on this bullet are the same defect seen from two sides, and both are real.

**The complement.** I fetched the NACE page (HTTP 200, browser UA) and read it. It states "Among
survey participants, 70% report using skill-based hiring, up from 65% last year." It never states
30%. The post was carrying arithmetic, not a sourced figure, which rule 1 forbids.

**The subject swap.** The bullet has always been about testing candidates. Its original claim was
"only 40% of employers test candidates' skills or general abilities" (HBR 2019, Cappelli). NACE
measures adoption of skills-based hiring, which the same page defines as "focusing on the skills
candidates have rather than academic degrees or GPAs" across job descriptions (81%), screening (65%)
and interview rubrics (58%). Different construct. The first refresh replaced one with the other and
recorded only the 70%-to-30% inversion, so the post's original claim had left the page silently,
which rule 3 forbids.

I took the branch the verifier named: a current figure for the thing the sentence is actually about.
SHRM, "New SHRM Research Makes the Case for Skills-Based Hiring", fetched at HTTP 200 and read in
full. Verbatim: "more than half of employers ... 56 percent ... use pre-employment assessments to
gauge job applicants' knowledge, skills and abilities" (SHRM sets the figure off with em-dashes;
ellipses here rather than reproduce them). Survey of 1,688 SHRM members, fielded 1 to 17 February
2022, US organizations of all sizes.

Three consequences worth stating plainly rather than burying:

- **The bullet's figure is now 2022 on a post dated 2026**, and says 2022. No later measurement of
  pre-employment assessment adoption is published that I could find. That is the price of the bullet
  measuring what it claims to measure. The alternative was the reverse trade: a 2026 figure about a
  different pitfall.
- **The NACE figure is out of this post entirely**, so the population problem the third finding
  raised (NACE's Job Outlook surveys employers who recruit new college graduates, 183 respondents,
  170 of them NACE employer members, data collected 7 August to 22 September 2025) no longer applies
  here. It applies on `/blog/behavioral-interview-scoring-matrix`, which keeps the figure and has
  been given the population wording. The instruction to match that post's wording is moot once the
  figure is gone; I recorded the divergence in `QUESTIONS-FOR-JESSICA.md` under both posts so neither
  reads as an oversight.
- **"56%" is not written as "only 56%".** SHRM frames it as "more than half". The old sentence's
  "only 40%" was earned; at 56% it would be spin, and the bullet does not need it: a reader draws the
  same conclusion from the number as stated.

## 2. Fixed: the McKinsey sentence, block `565002e9de94` (MED)

**Before**

> According to **McKinsey**, successful agile transformations typically deliver around "30% gains in
> efficiency, customer satisfaction, employee engagement, and operational performance."
>
> link: `https://www.mckinsey.com/business-functions/people-and-organizational-performance/...`

**After**

> According to a 2021 **McKinsey** survey, highly successful agile transformations typically delivered
> around "30% gains in efficiency, customer satisfaction, employee engagement, and operational
> performance."
>
> link: `https://www.mckinsey.com/capabilities/people-and-organizational-performance/...`

The first pass called this unreachable. That was a curl limitation, not a fact about the source, and
recording it as unreachability put a wrong reason in front of Jessica. curl still fails (HTTP/2
INTERNAL_ERROR on h2, timeout on `--http1.1`, both paths). The page loads normally in a browser.
Read there today:

- Dateline: **May 25, 2021 | Survey**.
- "we conducted a McKinsey Global Survey that reached 2,190 respondents across industries and
  geographies".
- Verbatim: "Highly successful agile transformations typically delivered around 30 percent gains in
  efficiency, customer satisfaction, employee engagement, and operational performance; made the
  organization five to ten times faster; and turbocharged innovation."

Three changes followed, all of them forced by what the page says.

1. **The year.** The sentence carried none on a post that renders "Updated August 6, 2026", so it read
   as a current finding. It now opens "According to a 2021 McKinsey survey". 2021 is the article's own
   dateline, which is the date the page states about itself.
2. **"highly".** McKinsey attributes the 30% to highly successful transformations, the roughly 300 it
   separates from the 580 less successful ones. The post attributed it to successful transformations
   generally, which is a claim the page does not make. One word, and it was wrong.
3. **The URL.** The article now lives on `/capabilities/`. The old `/business-functions/` path was on
   two markDefs, both keyed `dc010eca04b7`: the live one on block `565002e9de94` and an unreferenced
   duplicate on block `adb991625f4d` that renders nothing. Both were repointed, on the same reasoning
   the first pass used for the orphaned Glassdoor and Statista markDefs.

The quoted string itself was not touched. It differs from the source only in "30%" for "30 percent".

## 3. Jessica's call, not fixed: the cost comparison, block `3e22708438de` (LOW)

The verifier is right on every fact and right that the consequence was never surfaced. Both figures
were re-read at source today, both at HTTP 200:

- SHRM: "the median cost-per-hire for nonexecutive positions increased only slightly from $1,200 in
  2025 to $1,300 in 2026" and "The time needed to fill open positions has decreased to a median of 39
  calendar days for nonexecutive positions in 2026, compared to 44 days in 2025."
- Training Magazine: "Overall, on average, companies spent $874 per learner this year compared with
  $774 per learner in 2024."

Nothing false is on the page. What changed is the strength of the argument. The section is headed
"Hold fire before you hire" and exists to say developing an existing employee beats hiring one. It
used to make that case at $4,000 against $1,308. It now makes it at $1,300 against $874, a $426 gap,
between two figures that do not cover the same categories, because SHRM's cost-per-hire excludes
onboarding and training. Rewriting the argument is editorial work on a post ranking #1-4 on its head
terms, and rule 5 says currently ranking posts are not restructured. Recorded as item 6 under this
post in `QUESTIONS-FOR-JESSICA.md`. Nothing in the block changed.

## 4. Jessica's call, not fixed: the brand in the alt text (LOW)

The verifier's fact is confirmed. I downloaded all four graphics again and viewed them. Three are
product screenshots with no Polymer wordmark, logo or URL anywhere in frame:

- `c6c93f25710d`, the "We are hiring!" job board. Everything else in its alt is exact: the three
  dropdowns reading All locations / All categories / All types, the Software Development heading,
  Senior Front-end Developer, the Full-Time / US / Remote friendly pills, the View job button.
- `44b6a332588f`, the iOS Developer candidate dashboard. Alt is exact, down to the pipeline counts.
- `844d67fb30ac`, the team list. Sample addresses are @alkime.co, and the alt does not state them.

All three alts name Polymer. That brand is true of the product being shown, and the prose beside each
one names it, so no false statement ships; it is simply not derivable from the pixels. Whether alt
text may name the software it depicts is a house style decision, not a factual error, and it applies
to all three of these alts and not just the one the finding names. Fixing it into my preferred shape
would strip "Polymer" from the accessible text layer in three places on an SEO refresh. Recorded as
item 7 under this post in `QUESTIONS-FOR-JESSICA.md`, all three named. Nothing changed.

## 5. Corrections written back into QUESTIONS-FOR-JESSICA.md

Four entries in that file were false or incomplete after this pass, and were corrected in place
rather than left for her to decide on:

1. Item 2 under this post said the McKinsey figure was left as found because the source could not be
   read. Replaced with what the browser returned, the 2021 dateline, the verbatim sentence, and the
   three changes that followed.
2. The row for this post in "Figures that could not be reached, consolidated index" said the same
   thing. Marked closed, with the same correction, and it now says explicitly that the reachability
   framing was a curl limitation rather than a fact about the source.
3. The closing sentence of "Verification found the substitution's population is narrower than
   stated" said this post carries the NACE figure as a complement. It no longer carries it at all.
4. A sibling agent's entry on `/blog/behavioral-interview-scoring-matrix` said this post "carries the
   same figure and is being corrected with the same wording". Corrected: the figure is gone from this
   post, and why.

Three new items were added under this post: item 5 (the bullet, what it now measures and the 2022 vs
2026 trade), item 6 (the cost comparison), item 7 (the brand in the alt text).

## 6. Full re-read of the draft, for things no finding named

All 126 blocks read again after the patch. Everything dated or numeric:

| Block | Carries | Verdict |
|---|---|---|
| `565002e9de94` | McKinsey 30%, now dated 2021, `/capabilities/` link | Fixed this pass |
| `38ca8dd93505` | "first developed in 2001 by a team of software developers" | Correct. `agilemanifesto.org` 200 |
| `c63776ee3170` | SHRM 56%, dated 2022 | Fixed this pass |
| `17441d8777e3` | Predictive hiring, Forbes 2019 link | No figure. Link 200. No change |
| `ffe1077ff7e1` | "teams should be between three and ten employees" | No year, no source, not contradicted by the 2020 Scrum Guide's "10 or fewer". No change |
| `1336db02167d` | "a rapidly growing communication method", yac.com link | No figure. Link 200. No change |
| `3e22708438de` | $1,300 / 39 days / $874, dated 2026 and 2025 | Both re-verified at source. Recorded, not changed |
| `71194acb4b47` | Orphaned duplicate SHRM and Training Magazine markDefs | Already repointed in the first pass. Correct. No change |
| `e4d77b9557fb` | "Recruitment in 2026 has moved beyond ..." | Correct as of this year. No change |

Every external link in the post fetched today: `agilemanifesto.org` 200, the Forbes predictive hiring
article 200, `yac.com/blog/asynchronous-communication` 200, the SHRM benchmarking brief 200, the SHRM
skills-based hiring release 200, `trainingmag.com/2025-training-industry-report/` 200, McKinsey
`/capabilities/` 200 in a browser. Nothing in the post now points at a page that does not state what
the sentence claims.

Two things left alone on purpose, both already logged and neither a figure:

- The `https://www.wrk.xyz/` markDef `a376d3ed1d9e` shared by blocks `0005699970a2` and
  `36f48f41793c`, where the anchor text says Polymer. That is the Wrk legacy item, tab 10, with its
  own drafts and its own log.
- The team list screenshot under "You can then create user roles and assign teammates to jobs", which
  shows no role creation screen. Already recorded as item 4 under this post.

No em-dashes were introduced. No section was added, moved, merged or reworded, and the draft still
has the 126 blocks it had before.
