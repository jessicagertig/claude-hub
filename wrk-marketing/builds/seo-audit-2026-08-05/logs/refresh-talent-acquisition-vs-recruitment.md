# Refresh: `/blog/talent-acquisition-vs-recruitment`

Tab 13 row 5, "Refresh + internal links; page-1 candidate". Tab 01 row 14, "Link + refresh -
page-2 -> page-1 candidate". Refresh = Overview K23: 2026 data, updated modified dates, author
bylines, downloadable templates.

Everything below is in the Sanity **draft** `drafts.00fd928a-3f05-4f9e-a0f1-2d7cbdc4b1e0`.
Nothing was published. The published document `00fd928a-3f05-4f9e-a0f1-2d7cbdc4b1e0` still shows
`_updatedAt: 2022-08-30T14:14:17Z`, checked after every write.

Draft fields differing from published after this pass: `content`, `featureImage`, `author`,
`updatedDate`. `author` was already on the draft from an earlier phase and was not touched.

## What the post carried before this pass

129 content blocks. One `toc`, one `table`, 127 text blocks. **No inline images at all**, so the
only graphic on the page is `featureImage`.

Four dated or datable figures, all four in the "Cons of recruitment" and "Implementing a talent
acquisition engine" sections. Everything else in the post is undated argument (pros and cons of
each approach, the nine-stage talent acquisition list, the pipeline advice). Read end to end for
"a recent study", "last year", named-report-with-no-date and practices that have since changed;
nothing else surfaced.

## Figures replaced

### 1. Recruitment agency placement fee

Block `ccebdd18ae6e`.

Before:

> Hiring a recruitment professional to source candidates is expensive and can **cost 15-20% of
> your new hire's salary**.
>
> Link on "cost 15-20% of your new hire's salary" to
> `https://www.topechelon.com/blog/typical-placement-recruitment-fees-average/`

After:

> Hiring a recruitment professional to source candidates is expensive and can **cost 20-25% of
> your new hire's first-year salary in 2026**.
>
> Link on "cost 20-25% of your new hire's first-year salary in 2026" to
> `https://www.indeed.com/career-advice/finding-a-job/headhunters-fee`

**Why the source changed.** The Top Echelon page is still live (200) but it is dated **20 February
2019** and reports **2018** network data, and it does not state 15-20% anywhere. Its own number is
an average fee of 21.5%, individual industries 20-23%. So the old sentence was citing a page that
did not support it, on data now eight years old.

**The new figure and its date.** Indeed, "FAQ: What Is a Headhunter Fee and How Much Does It
Cost?", **updated 15 June 2026**: "The average percentage fee is 20-25%, though it can range from
as low as 15% to as high as 40% or more". The sentence takes the average band, 20-25%, and names
2026. "first-year" was added because every source states the fee against first-year base salary
and the old sentence left it ambiguous.

**Other 2026 sources checked and not used**, all agreeing the band has moved up from 15-20%:
RecruitBPM "Recruitment Fees in 2026" says 15-25% but carries no visible date;
`https://www.isgpartners.com/blog/flat-fee-vs-contingency-recruiting` says 15-30% for 2026 but its
date line shows no year; `https://remotepad.net/recruiting-fee/` is dated 13 October 2025 and does
not tie its percentages to contingency specifically. Indeed was taken because it is the only one
of the four carrying an explicit 2026 update date against an explicit range.

### 2. Cost per hire

Block `27ad8be01c96`.

Before:

> Given the average employer in the US **spends $4,000** on making a new hire, when you're a
> growing startup and need to hire regularly, this adds up fast.
>
> Link on "spends $4,000" to `https://www.glassdoor.com/employers/blog/calculate-cost-per-hire/`

After:

> Given the average US employer **spent $5,475 on a hire in 2025**, when you're a growing startup
> and need to hire regularly, this adds up fast.
>
> Link on "spent $5,475 on a hire in 2025" to
> `https://www.shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports--how-does-your-organizat`

**The old source is unreachable.** The Glassdoor URL 301s to
`https://www.glassdoor.com/blog/calculate-cost-per-hire/` and returns **403** to a desktop Chrome
user agent. The $4,000 is the old SHRM 2016 average ($4,129) restated.

**Why 2025 and not the 2026 SHRM figure.** Fetched and read both. SHRM's **2026 Recruiting
Executives Benchmarking** data brief
(`https://www.shrm.org/topics-tools/research/recruiting-benchmarking/full-data-brief`) gives
**median** cost-per-hire of **$1,300 nonexecutive and $15,000 executive for 2026**, against $1,200
and $10,600 for 2025. SHRM's **2025 Benchmarking Reports** press release, published **15 October
2025**, survey run 9 January to 3 March 2025, gives **"Nonexecutive Average: $5,475"** and
**"Executive Average: $35,879"**. Those are a different survey population and a median rather than
an average, which is why they sit four times apart rather than a year apart. The 2026 brief is
therefore not a newer version of the same number, and the most recent published value of *this*
figure, a US average cost per hire, is the 2025 average. That is also the source Jessica supplied
for the identical figure on `/blog/problem-solving-interview-questions`, so the two posts now
carry the same number from the same report. Recorded in QUESTIONS-FOR-JESSICA.md.

**The nonexecutive qualifier was dropped**, matching Jessica's instruction on the sibling post that
it is noise for Polymer's users. The sentence names 2025 so nothing reads as newer than it is.

### 3. Time to fill

Blocks `c4ec9456d7db` (source only) and `5b6f5e3ecf3c`.

Before:

> It may only take the average employer **24 days** to fill an open role, but this is often due to
> necessity (i.e. they want to fill the position fast before taking a productivity hit).
>
> Link on "24 days" to `https://www.glassdoor.com/employers/blog/calculate-cost-per-hire/`

After:

> It may only take the median employer **39 calendar days in 2026** to fill an open role, but this
> is often due to necessity (i.e. they want to fill the position fast before taking a productivity
> hit).
>
> Link on "39 calendar days in 2026" to
> `https://www.shrm.org/topics-tools/research/recruiting-benchmarking/full-data-brief`

**The new figure.** SHRM 2026 Recruiting Executives Benchmarking, data collected 24 November 2025
to 23 January 2026: "median of 39 calendar days for nonexecutive positions in 2026, compared to 44
days in 2025". Executive positions sit at 45 days, unchanged from 2025. The nonexecutive qualifier
was dropped for the same reason as figure 2; 39 is the nonexecutive number and every role the
surrounding section describes is nonexecutive.

**Unlike figure 2, there is no competing supplied source here.** The 2025 benchmarking press
release states no overall time-to-fill figure at all (its only timing detail is "screening and
interviewing alone averaging 8-9 days each"), so the 2026 brief is the most recent published
time-to-fill benchmark and it is used. The post therefore cites SHRM 2025 for cost and SHRM 2026
for time-to-fill, each figure taking its own most recent source.

**The orphaned annotation on `c4ec9456d7db` was removed.** That block carried a copy of the
Glassdoor markDef that no span referenced, so it rendered no link; leaving it would have left a
403 URL in the document pointing at nothing.

### 4. The neighbour sentence that the new time-to-fill figure contradicted

Block `78a7cdd44c7c`, immediately after figure 3.

Before:

> **Finding a hire in less than a month** may fill the gap in the short term (and could end up
> working out), but it's more likely quick hires won't stick around for the long term.

After:

> **Filling the role that quickly** may plug the gap in the short term (and could end up working
> out), but it's more likely quick hires won't stick around for the long term.

"Less than a month" was written against the old 24-day figure. At 39 calendar days it is false,
and updating its neighbour while leaving it would have been exactly the silent staleness rule 4
forbids. The replacement carries no duration of its own, so it cannot go stale again when the
benchmark next moves.

## Figure dated rather than replaced

### LinkedIn employer brand, block `4b2122701300`

Before: "**A study by LinkedIn** found that a strong employer brand makes it easier to recruit
candidates, attracts 50% more qualified applicants, and reduces your cost-per-hire by up to 50%."

After: "**A 2011 LinkedIn study** found that ..." Figures and link unchanged.

**Why it was not replaced.** The source in the post,
`https://business.linkedin.com/content/dam/business/talent-solutions/global/en_us/c/pdfs/ultimate-list-of-employer-brand-stats.pdf`,
still resolves (301 to LinkedIn's Adobe AEM asset host, 200, 2.3 MB). Its text was extracted and
read. Page 4 carries exactly the four numbers the post uses, "50% cost-per-hire reduction. 1-2x
faster time to hire. 28% reduction in the organization's turnover. 50% more qualified applicants",
and the attribution printed under them is **"LinkedIn Study, 2011"**. So the figures are real and
the source states them, but they are fifteen years old and the post presented them undated.

**2026 was searched for, per figure.** No primary source republishes them. LinkedIn's 2025 Future
of Recruiting report and the 2026 LinkedIn Talent Velocity Advantage Report were both located; the
2026 report was downloaded and its text searched for "employer brand", "cost-per-hire", "time to
hire", "qualified applicant" and "turnover", with zero matches. Every 2026-dated page that quotes
the 50%/50% pair (Vouch, Searchlab, amraandelma, Sociabble) traces back to this same 2011 study,
and several silently mutate it, one saying 43% rather than 50% for cost-per-hire and another
attributing the cost figure to Universum instead. None is a new measurement.

So the most recent published value of this figure is the 2011 one, the sentence now says so, and
the choice of whether to keep a 2011 statistic at all is recorded in QUESTIONS-FOR-JESSICA.md.

## Images

**One image on the page, and it holds no figure.** The post has no inline image blocks. The only
graphic is `featureImage`, asset
`image-6a90871c681717a275b306d645c64d0ea2bfce7b-3600x1890-png`, viewed at
`https://cdn.sanity.io/images/a6d1clb1/production/6a90871c681717a275b306d645c64d0ea2bfce7b-3600x1890.png?w=1400&fit=max`
(200, full frame, aspect preserved).

**What it actually shows:** a solid black field. A white dashed line runs diagonally from the
bottom-left corner to the top-right corner. Slightly right of centre, an unfilled white circle
outline sits on that line, the dashes passing behind the ring and reappearing inside it. No text,
no numbers, no labels, no logo, no date. Nothing in it is a figure, so **nothing in this post is
held** and no entry belongs under "Images that need regenerating".

Alt text, `featureImage.altText`:

- Before: "Acquisition vs Recruitment Header Image"
- After: "Abstract header graphic: a white dashed line crosses a black background diagonally from
  bottom left to top right, passing through an empty white circle outline near the center."

The old string described the post, not the picture, and told a screen reader nothing about what is
on screen. The new one is written from the pixels.

## Internal links added

Tab 13 row 5 and tab 01 row 14 both ask for internal links. Seven were added. Every one is anchored
on words already in the post; no sentence was written to carry a link, and no existing link was
removed. All seven targets return 200.

| Block | Anchor text (already present) | Target |
|---|---|---|
| `f91031852f58` | Screen applications | `/plato` |
| `46956efd14e6` | fill the wide skills gap many businesses face | `/blog/skills-mapping-for-hiring-a-complete-guide` |
| `d6550fc80082` | establish your employer brand | `/blog/employer-branding-steps` |
| `846d2dabb532` | applicant tracking system | `/blog/best-applicant-tracking-software` |
| `0415dbabdbac` | behavioral-based questions | `/blog/behavioral-interview-scoring-matrix` |
| `15ac6ee3e2bc` | onboarding new team members | `/blog/onboarding` |
| `f5609971e155` | save money on recruitment costs | `/pricing` |

`f5609971e155` also had an orphaned `/features` markDef that no span referenced, left over from the
block split with `cd06f981f2cc`. It rendered nothing and was replaced by the `/pricing` annotation
the block now uses. The live `/features` link on `cd06f981f2cc` is untouched.

The five internal links the post already had are all intact and all 200: `/blog/a-player`,
`/blog/employee-turnover`, `/blog/first-impression-bias#how-to-overcome-cognitive-biases-in-the-hiring-process`,
`/blog/talent-acquisition`, `/features`.

## Byline and updated date

`updatedDate` set to `2026-08-06`. The field is `type: "date"` in
`studio/schemas/blogPost.js`, so the value is a plain `YYYY-MM-DD` string; `web/pages/blog/[slug].js`
renders it as "Updated August 6, 2026" and feeds it to `dateModified` in the Article JSON-LD.

`author` was already set to `author-corey-daniels` on the draft by an earlier phase and was not
changed, per instruction.

## Not done, deliberately

- **No restructuring.** The post sits at position 26 on two 480-volume terms, so it is a currently
  ranking page. Tab 13 row 5 asks for "Refresh + internal links" and nothing else; there is no
  answer-first instruction on this row, and none was invented.
- **No downloadable template.** Overview K23 lists templates as part of "refresh", but tab 13 names
  a specific template only for row 3, `behavioral-interview-scoring-matrix`. Nothing on row 5 or
  tab 01 row 14 asks this post for one, and this post has no template to attach.
- **No metadata rewrite.** `pageTitle` and `metaDescription` belong to Phase 4 and were left alone.

## Verification run after the final write

- Published document `_updatedAt` still `2022-08-30T14:14:17Z`.
- Draft vs published differs in exactly four fields: `content`, `featureImage`, `author`,
  `updatedDate`.
- 13 content blocks differ. Every one is listed above.
- No dangling marks: every `marks` entry on every changed block resolves to a markDef on that
  block.
- No unused markDefs on any changed block.
- No em-dash in any changed block.
- Every URL the changed blocks link to returns 200 under a desktop Chrome user agent.

## Fix pass, 2026-08-07

Six verifier findings on this post: 2 MED, 4 LOW. **One block changed in Sanity**, `ccebdd18ae6e`.
Draft `drafts.00fd928a-3f05-4f9e-a0f1-2d7cbdc4b1e0`, rev `kJ3OpIOJnJS2LKJpQpfI3J` to
`QzNVnRn1RN9Wy2ys8QubiB`, one `set` on `content[_key=="ccebdd18ae6e"].children` guarded with
`ifRevisionId`. Published document `00fd928a-3f05-4f9e-a0f1-2d7cbdc4b1e0` still on `_rev`
`L2FV4LWPPbEVlP1xCogfbs`, `_updatedAt` `2022-08-30T14:14:17Z`, re-read after the write. Nothing was
published. A field-by-field diff of the draft before and after this pass reports exactly one
differing key: `content`, and within it exactly one differing block. `author`
(`author-corey-daniels`), `updatedDate` (`2026-08-06`), `featureImage`, `pageTitle`,
`metaDescription` and the block count (129) are all unchanged.

### 1. LOW, fixed: the 20-25% fee cited a headhunter page for a sentence about recruiters, and dated the band to a year the page never attaches to it

Both halves of the finding are right, and both are now fixed in the same `set`.

**The subject mismatch.** The Indeed page was re-fetched (200, 1,298,619 bytes, desktop Chrome UA)
and read end to end. It is titled "FAQ: What Is a Headhunter Fee and How Much Does It Cost?" and it
draws the recruiter/headhunter distinction itself, in its own words:

> A standard headhunter's fee is often a percentage of the negotiated first-year salary in an offer
> letter (including any sign-on bonuses), paid by the hiring company on the start date of the
> successful candidate. The average percentage fee is 20-25%, though it can range from as low as 15%
> to as high as 40% or more, depending on the firm the headhunter works with and the type of job
> position being filled.

and, under the H2 "What is the difference between a headhunter and a recruiter?":

> Another difference between headhunters and recruiters is that a headhunter only gets paid if they
> successfully recommend and place a suitable candidate with the company, and recruiters often are
> salaried employees of the company.

So the page states the band for headhunters and explicitly excludes salaried in-house recruiters
from the category. The sentence said "a recruitment professional", which is broader than what the
source supports. Rule 1 gives two outs: cite a page that does state it, or drop the clause. No dated
source stating the same band for agency recruiters as a class was found on this pass or the last one
(the refresh checked RecruitBPM, ISG Partners and RemotePad; none carries both an explicit range and
an explicit year). Narrowing the sentence to the source's own subject keeps the figure and makes the
citation exact, so that is what was done.

**The manufactured year.** "in 2026" came off the page's "Updated June 15, 2026" line. The page
attaches no year to the band itself. The year now sits on the publication rather than on the
measurement, which is the same form block `4b2122701300` already uses two screens later ("A 2011
LinkedIn study found").

Before:

> Hiring a **recruitment professional** to source candidates is expensive and can cost 20-25% of your
> new hire's first-year salary **in 2026**.
>
> Link anchor: "cost 20-25% of your new hire's first-year salary in 2026"

After:

> Hiring a **headhunter** to source candidates is expensive and can cost 20-25% of your new hire's
> first-year salary, **per Indeed's June 2026 guidance**.
>
> Link anchor: "cost 20-25% of your new hire's first-year salary"

The markDef (`7e9e1086499f`), the href, the three span keys and the figure are all unchanged. No
em-dash. Verified after the write: no orphaned markDef and no dangling mark on the block.

Recorded for Jessica as item 5 in QUESTIONS-FOR-JESSICA.md, because narrowing "recruitment
professional" to "headhunter" narrows who the sentence is about and that is an editorial consequence
she may want to unmake.

### 2. MED, left as it is by Jessica's decision: neither SHRM figure says "nonexecutive"

The finding is accurate on the facts. SHRM's 2025 press release states "Cost-per-Hire / Nonexecutive
Average: $5,475" and "Executive Average: $35,879"; SHRM's 2026 brief states "The time needed to fill
open positions has decreased to a median of 39 calendar days for nonexecutive positions in 2026,
compared to 44 days in 2025. For executive positions, the median time-to-fill (45 days) is lower
than in 2022 (60 days), though it remained unchanged from last year." Both were re-fetched today
(200) and both strings were read at source, not taken from the earlier log.

**Neither figure was changed.** Jessica instructed on `/blog/problem-solving-interview-questions`
that $5,475 is stated plainly and is not to be described as a non-executive average, because most
Polymer users are not hiring executives and the qualifier is noise. The two posts carry the same
figure from the same report and must not describe it differently, so that decision governs this post
too, and the 39-day figure is written the same way for the same reason. The verifier is right that
extending the instruction to a second figure from a different report was the refresh agent's own
judgement rather than a sanctioned decision; it is now a recorded decision rather than an
undisclosed extension. QUESTIONS-FOR-JESSICA.md item 4 for this post says so explicitly, and says
why, so a later reviewer does not "correct" the qualifier back in.

### 3. MED, left as it is, but the consequence the entry never stated is now in the questions file

Cost-per-hire stays at **$5,475 dated 2025**. Jessica supplied that source. The sentence already
carries the year, re-read in the draft today: "Given the average US employer **spent $5,475 on a
hire in 2025**, when you're a growing startup and need to hire regularly, this adds up fast." So
nothing on the page reads as newer than it is, and the 2026 brief's $1,300 is a median from a
different survey population rather than a newer version of the same number.

What the questions file did not say, and now does: `/blog/agile-recruiting-process` took **$1,300**
from the 2026 brief for the same concept. Confirmed in `logs/refresh-agile-recruiting-process.md`
and in `logs/refresh-problem-solving-interview-questions.md`. The audit therefore ships two
cost-per-hire figures across three posts, four times apart, and that is a real deviation from the
rule that 2026 is taken wherever it exists. It is Jessica's call, so nothing was changed; the
consequence was added under item 2 of her entry for this post so she is deciding on the whole
picture rather than on one post at a time.

### 4. LOW, correcting this log: three orphaned markDefs were removed, not two, and the block list was short

The finding is right and the earlier sections above are the ones at fault. Read off the published
document today, block by block:

| Block | Orphaned markDef removed by the refresh | Href it carried |
|---|---|---|
| `ccebdd18ae6e` | `53e8a6404695` | `https://www.glassdoor.com/employers/blog/calculate-cost-per-hire/` |
| `c4ec9456d7db` | `ca5289d82370` | `https://www.glassdoor.com/employers/blog/calculate-cost-per-hire/` |
| `f5609971e155` | `fbf9fd952f2c` | `https://www.polymer.co/features` (replaced by the `/pricing` annotation) |

Published `ccebdd18ae6e` carried two markDefs, `7e9e1086499f` (Top Echelon, referenced by a span)
and `53e8a6404695` (Glassdoor, referenced by nothing). The refresh rewrote that block's children and
markDefs for the fee figure and the dead Glassdoor definition went with them, which is correct but
was never written down: the "Figures replaced" section above records the removals on
`c4ec9456d7db` and `f5609971e155` and not this one. The removal itself is harmless and stands.

**Four orphaned markDefs remain in the draft, and all four are pre-existing on blocks neither pass
touched:** `f1ab4f543029` on `0f65ce29c358`, `2239b7c1e86d` on `63eaecfedb61`, `cf6d67ea9d7e` on
`ae72692f9f39`, and `cb9c9da12cd8` on `8d1dbfd12a0b`. Each is a duplicate of a definition that is
live on the following block, left behind when a paragraph was split in the Studio, so each renders
nothing. They were not cleaned up, because that is scope neither the tabs nor the findings ask for
on a currently ranking post. Recorded so the count is complete.

### 5. LOW, correcting this log: tab 01 row 14 asks for links INTO this page, not out of it

The finding is right and the "Internal links added" section above credits the wrong row. Read from
the workbook today, tab 01 is titled "Orphaned High-Value Pages (10 URLs)" and its own note reads
"Pages verified live (HTTP 200) but unreachable from any internal link in the crawl". Its
Recommended action column is about reachability: row 7 is "Link from /blog + related posts; include
in sitemap; refresh", row 16 is "Link from /features/jobboard + blog index; refresh". Row 14, this
post, is "Link + refresh - page-2 -> page-1 candidate", and that "Link" is the same inbound one.

Seven outbound links from this post do not de-orphan it. **Nothing is missing.** The inbound side
was closed in Phase 1 and was verified in the repo for this pass: `web/pages/blog.js` server-renders
the index, `web/components/blogIndex.js` renders a `Pagination` component that emits a real `<a>` to
every page number through `blogPagePathname` in `web/lib/blog.js`, `web/pages/blog/page/` holds the
route, `web/pages/sitemap.xml.js` line 84 emits an entry for every `blogPost` slug, and the
related-posts module links siblings. So the post is reachable with JavaScript off.

The seven links the refresh added satisfy **tab 13 row 5**, which reads "Refresh + internal links;
page-1 candidate" (workbook row 11 of that tab). That row is genuinely served. Only the tab 01
credit was wrong, and it is corrected here.

### 6. LOW, re-tested rather than accepted: the LinkedIn 2011 figures have no 2026 replacement

The finding says the negative rested on the refresh agent's own record and could not be
independently re-tested. It has now been re-tested, and it holds.

- **The PDF.** Downloaded again, 200, 2,404,917 bytes. Text extracted with
  `/opt/homebrew/bin/gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite`. Page 4 prints "28% reduction in the
  organization's turnover", "50% cost-per-hire reduction", "50% more qualified applicants" and
  "1-2x faster time to hire", and the attribution line directly under them reads **"LinkedIn Study,
  2011"**. The only years anywhere in the document are 2011, 2012, 2013, 2015 and 2016. The post's
  "A 2011 LinkedIn study found" is exactly what the source says.
- **SHRM 2026.** The brief was re-fetched and its full text searched: zero occurrences of "employer
  brand". It carries no employer-brand metric, as recorded.
- **A fresh search, run in a browser** because this session's WebSearch budget was already spent.
  Every result on the first page for the 50%/50% pair is a restatement of the same 2011 trio. The
  top one is a LinkedIn Pulse article published three days ago: "LinkedIn's recruiting research
  links a strong employer brand to roughly 50% lower cost per hire, about 50% more qualified
  applicants, and close to 28% lower staff turnover", naming no study and citing no report. The only
  genuinely 2026 employer-brand study on the page is **Randstad's 2026 Employer Brand Research**,
  which measures employer attractiveness and preference rather than applicant quality or
  cost-per-hire, so it answers a different question and cannot replace this sentence.

Nothing changed on the page. The QUESTIONS-FOR-JESSICA.md entry now records the re-test, so the
negative rests on two independent checks rather than one.

### Full re-read of the draft, for anything the findings did not name

All 129 blocks were re-read after the patch, not only the ones the findings touch.

- **Every URL in the document returns 200** under a desktop Chrome user agent: all twelve
  `polymer.co` targets (`/plato`, `/pricing`, `/features`, and the nine blog posts), both SHRM URLs,
  the Indeed page and the LinkedIn PDF. Sixteen distinct URLs, no redirects into 404s.
- **Both SHRM sources still state what the sentences claim**, re-read at source rather than trusted
  from the earlier log. The 2025 press release prints "Cost-per-Hire", "Nonexecutive Average:",
  "$5,475"; the 2026 brief prints the 39-calendar-day sentence in full.
- **No dangling marks anywhere.** Every `marks` entry on every block resolves to a markDef on that
  block.
- **Two pre-existing em-dashes, left alone**: block `9bfeaeb70b51` ("fill a role—especially at a
  startup or small business") and block `20deafba7684` ("productivity, and innovation—factors that
  reduce turnover"). Both are 2022 human prose in blocks neither pass otherwise touched. Nothing
  written in either pass contains one. Same standing as the em-dash notes on the sibling posts: one
  word from Jessica and they go.
- **No dated figure was missed.** The four dated figures are the fee, the cost per hire, the
  time-to-fill and the LinkedIn pair, and all four are handled above. The rest of the post is
  undated argument, the nine-stage list, and the two product mentions.
- **Product and plan names check out.** Block `f91031852f58` anchors "Screen applications" to
  `/plato`, which is Polymer's AI candidate reviewer, and block `846d2dabb532` says "A tracking
  system like Polymer". Neither names a plan or a price, so nothing here goes stale with the pricing
  page.
- **`updatedDate` was deliberately not bumped** from 2026-08-06 to 2026-08-07. It is the date the
  refresh set, it feeds `dateModified` in the Article JSON-LD, and the whole batch carries it; moving
  one post's byline a day ahead of the other ten for a one-sentence correction would make the eleven
  posts disagree for no reader-visible gain.
