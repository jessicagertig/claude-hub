# Refresh log: `/blog/problem-solving-interview-questions`

Tab 13 row 1. Refresh order 1. Site's #1 traffic asset, #1 on five 590-volume terms.
Run 2026-08-06. Sanity draft only, nothing published, no repo file touched.

## Document

| | |
|---|---|
| Published id | `4a4e07e8-b7bf-4173-b7e5-f77a7cfe9f8c` |
| Draft patched | `drafts.4a4e07e8-b7bf-4173-b7e5-f77a7cfe9f8c` |
| Draft rev before | `QzNVnRn1RN9Wy2ys8QjqAr` (`_updatedAt` 2026-08-07T03:03:32Z) |
| Draft rev after | `kJ3OpIOJnJS2LKJpQpedzR` |
| Published rev after | `xOkZa3jk0O3ygI9ZPCD39b`, `_updatedAt` 2022-08-23T15:14:43Z, `updatedDate` null |
| Content blocks | 137 before, 137 after |

The draft already existed and already carried `author` = `author-corey-daniels`. It was patched
with a `.patch().set()` keyed on individual `content[_key==...]` paths, never overwritten, so
nothing else pending in the draft was disturbed. The published document was read for comparison
and never mutated; its `_rev` and `_updatedAt` are unchanged from 2022.

## Survey

The whole post was read block by block, not skimmed for `%` and four-digit years. 137 blocks,
three body images, one feature image, ten example questions with model answers, plus
`pageTitle`, `editorialTitle`, `metaDescription` and every `markDefs` href.

Everything carrying a figure, a date, an attribution or an "according to":

| Block | What it carries | Disposition |
|---|---|---|
| `1266978b35ab` (22) | Gallup, "59% of Millenials believe a job that accelerates their professional development is very important" | **HELD**, figure is rendered inside image `3b836ca47045` |
| `ad6ab23440a4` (29) | SHRM "nearly $4,700" cost per hire, non-executive; "three or four times the position's salary" | **REPLACED** |
| `19d541badbb9` (30) | "some companies embrace a strategy of paying new hires to leave" | Unchanged, no figure, link verified |
| `643ed442a086` (31) | Chris Ronzio, CEO of Trainual, $5,000 to quit in first two weeks | **DATED to 2022** |
| `fcfef189ee6d` (32) | Ronzio pull quote, "$5,000" | Unchanged, direct quotation |

Nothing else in the 137 blocks carries a statistic, a study reference, a named report, a
"recent study found", a "last year", or a practice claim. The ten example questions and their
model answers were read end to end; none is stale and none was touched.

## Figures replaced

### 1. Cost to hire

Block `ad6ab23440a4`.

Before:

> According to the **Society for Human Resources Management**, the average cost per hire across
> all industries and business sizes for a non-executive position is nearly **$4,700**. It can be
> as much as three or four times the position's salary.
>
> Single link on "Society for Human Resources Management" to
> `https://www.shrm.org/resourcesandtools/hr-topics/benefits/pages/shrm-hr-benchmarking-reports-launch-as-a-member-exclusive-benefit.aspx`

After:

> According to the **Society for Human Resource Management**'s **2025 benchmarking report**, the
> average cost to hire across all industries and business sizes is **$5,475**. Employers estimate
> the total cost of a hire can be as much as **three or four times the position's salary**.
>
> Link 1 on "Society for Human Resource Management" to
> `https://www.shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports--how-does-your-organizat`
> Link 2 on "three or four times the position's salary" to
> `https://www.shrm.org/topics-tools/news/talent-acquisition/real-costs-recruitment`

Four separate things changed here.

**The figure.** Fetched from the source Jessica supplied rather than taken on trust. The page
states "Nonexecutive Average: $5,475" and "Executive Average: $35,879", from the 2025 SHRM
Benchmarking Reports, published 15 October 2025, survey run 9 January to 3 March 2025 with 2,371
member respondents. Per instruction the sentence does not describe $5,475 as a non-executive
average; the qualifier is noise for Polymer's users.

**The year.** The sentence now names 2025, so it cannot read as a 2026 number.

**2026 was checked first, per figure.** SHRM does have a 2026 release: *2026 Recruiting Executives
Benchmarking*, data collected 24 November 2025 to 23 January 2026,
`https://www.shrm.org/topics-tools/research/recruiting-benchmarking/full-data-brief`. Its figures
are **median** cost-per-hire, $1,300 nonexecutive and $15,000 executive for 2026, against $1,200
and $10,600 for 2025. That is a different survey population and a median rather than an average,
which is why it sits four times below the benchmarking report's average rather than one year
above it. It is not a newer version of the same number, so the supplied 2025 average stands.
Recorded for Jessica in QUESTIONS-FOR-JESSICA.md so the 2026 figure does not surprise her later.

**The 3x-4x clause got its own source.** Tracing the old sentence back: both halves came from
SHRM's "The Real Costs of Recruitment", 11 April 2022, which says "the average cost per hire was
nearly $4,700" and, separately, quotes Edie Goldberg of E.L. Goldberg & Associates saying "many
employers estimate the total cost to hire a new employee can be three to four times the position's
salary". So the 3x-4x figure was never SHRM's benchmark, and the old markup let one link imply it
was. The clause now says "Employers estimate" and links to the article that carries the estimate.
That article is live (200).

**Organisation name corrected.** "Society for Human **Resources** Management" to "Society for
Human **Resource** Management", their actual name.

### 2. Trainual pay-to-quit, dated

Block `643ed442a086`. "Chris Ronzio, CEO of Trainual, **says** it's more effective..." became
"Chris Ronzio, CEO of Trainual, **said in 2022 that** it's more effective...".

Ronzio is confirmed still Founder and CEO of Trainual in 2026, so the attribution holds and no
figure needed replacing. What could not be established is whether the $5,000 offer still runs:
every account traces to January 2022 coverage (Fast Company, and the Fox syndication of the same
story), and neither Trainual nor Ronzio has published anything since either way. Present tense on
a four-year-old policy claim is the page reading as more current than it is, which rule 2 forbids,
so the year went in. The pull quote at block 32 is a direct quotation and was left verbatim.

## Figure held

**Gallup, 59% of Millennials.** Block `1266978b35ab`, prose unchanged, Gallup 2016 link unchanged.

Held because the figure is rendered as pixels in image `3b836ca47045` immediately below it, and
images cannot be edited. Researched to the same depth as one about to be written:

- Source of the 59%: Gallup, "Millennials Want Jobs to Be Development Opportunities", published
  **30 June 2016**, `https://www.gallup.com/workplace/236438/millennials-jobs-development-opportunities.aspx`,
  still live (200). Verbatim: "59% of millennials say opportunities to learn and grow are extremely
  important to them when applying for a job", against 44% of Gen Xers and 41% of baby boomers.
- Current value: Gallup has not re-run that question by generation since 2016. The closest live
  measurement is the Q12 learn-and-grow element, where agreement with "This last year, I have had
  opportunities at work to learn and grow" fell to **37% in 2025 from 48% in 2020** among Gen Z and
  younger millennials, published **27 January 2026**,
  `https://www.gallup.com/workplace/701486/employee-engagement-declines-2020-peak.aspx`.
- Supporting: Gallup, 23 March 2026, "more opportunities to grow and advance is the second
  most-cited reason for job-seeking behavior",
  `https://www.gallup.com/workplace/703280/worker-thriving-declines-job-market-pessimism-grows.aspx`.
- Also checked and found not to carry a like-for-like restatement: *State of the Global Workplace
  2026* (`gallup.com/workplace/349484`), "One in Four U.S. Employees Lack Advancement
  Opportunities" (15 October 2025, `news.gallup.com/poll/695996`), "3 Employee Engagement
  Strategies for 2026" (`gallup.com/workplace/703361`).

The two figures measure different things, applicant priority versus employee experience, so a
regenerated graphic needs a new sentence rather than a swapped number. Written up in
QUESTIONS-FOR-JESSICA.md under "Images that need regenerating" with old value, new value and
source URLs. Not a blocker; every other dated figure in the post was replaced.

## Images

All four images were downloaded from `cdn.sanity.io` and viewed, not inferred from surrounding
prose. Two outputs per image: what it actually asserts, and alt text written from that.

### `ec8a1120325b`, growth versus fixed mindset card

**What it asserts:** a white card on a peach-to-pink gradient, split into two rows. Top row
labelled "Growth mindset" with three seedling icons: "I can try a different strategy", "Is this
really my best work?", "This may take some time and effort". Bottom row labelled "Fixed mindset"
with three padlock icons: "I can't do this", "This work is good enough", "This is too hard". No
figures, no dates, no source attribution.

- Before: `Screenshot of Growth Mindset versus Fixed Mindset`
- After: `Comparison card contrasting growth mindset and fixed mindset self-talk. Growth mindset: I can try a different strategy; Is this really my best work?; This may take some time and effort. Fixed mindset: I can't do this; This work is good enough; This is too hard.`

The six statements were the entire content of the graphic and none of them appeared in the old
alt or in the surrounding paragraphs, so an answer engine got nothing from this image before.

### `3b836ca47045`, Gallup statistic card

**What it asserts:** "59% of Millenials believe a job that accelerates their professional
development is very important" in large type, a horizontal progress bar filled to just under two
thirds with a small triangle marker above the fill boundary, and "Source: Gallup" bottom right.
The misspelling "Millenials" is in the graphic itself.

- Before: `Screenshot of Gallup Report that Millennials Want Jobs that accelerates their professional development`
- After: `Statistic card with a horizontal bar filled to just under two thirds: 59% of Millennials believe a job that accelerates their professional development is very important. Source: Gallup.`

The old alt named the topic but not the number or the source, so the one thing this graphic exists
to carry was invisible to anything that cannot see. This is also the image that forces the hold.

### `b8f8cf668cb4`, interview scoring matrix template

**What it asserts:** a Google Sheets window titled "Interview scoring matrix". Column A criteria:
Cultural fit, Career motivation, Social skills, Teamwork, Technical skills, Leadership
capabilities, Critical thinking / problem solving, Self-awareness. Column B sample questions per
criterion. Column C scores, feeding an "Average score" row. Column E scoring scale, "1: Well below
standard" through "5: Well above standard". Header rows for Interviewer, Candidate and Date, with
"Candidate A" and **"7/11/2022"** filled in as sample data. Three sheet tabs: Candidate A,
Candidate B, Candidate C.

- Before: `Screenshot of Interview Scoring Matrix Template`
- After: `Google Sheets screenshot of an interview scoring matrix template. Criteria rows cover cultural fit, career motivation, social skills, teamwork, technical skills, leadership capabilities, critical thinking and problem solving, and self-awareness, each paired with sample questions and a score column that feeds an average score. The scoring scale runs from 1, well below standard, to 5, well above standard, and the workbook carries one tab per candidate.`

**Date carried as pixels:** cell C5 reads 7/11/2022. Not a statistic, so not a held figure in the
rule 6 sense, but it visibly dates the asset on a page that will now show "Updated August 6, 2026".
Recorded under "Images that need regenerating" as a second, lower-priority entry.

### `featureImage`, header

**What it asserts:** a white line-art speech bubble on a solid black field, containing three white
bullet rows. No text, no figures.

- Before (`featureImage.altText`): `Problem-Solving Interview Questions Header Image`
- After: `Line-art icon of a speech bubble containing a three-item bulleted list, drawn in white on a black background.`

## Byline and updated date

`updatedDate` set to **2026-08-06** on the draft. Field confirmed against
`studio/schemas/blogPost.js:82`, type `date`, described there as the editorial last-updated date
distinct from Sanity's automatic `_updatedAt`. It drives three things already on the branch:
`web/pages/blog/[slug].js:291` `dateModified: post.updatedDate || post.publishDate` in the Article
JSON-LD, the visible "· Updated August 6, 2026" line at `web/pages/blog/[slug].js:397`, and
`web/pages/sitemap.xml.js:84`. So tab 13 row 1's "dateModified schema" is satisfied by this field
alone; no code change was needed or made.

Author was already `author-corey-daniels` on the draft and was not changed.

## Links checked

Every `markDefs` href in the post plus the two new ones:

| URL | Result |
|---|---|
| `polymer.co/blog/a-player` | 200 |
| `polymer.co/blog/first-impression-bias` | 200 |
| `polymer.co/blog/behavioral-interview-scoring-matrix` | 200 |
| `app.polymer.co/register` | 200 |
| `gallup.com/workplace/236438/...` | 200 |
| `docs.google.com/spreadsheets/d/1n4Ek.../copy` | 200, redirects to Google sign-in, correct for a `/copy` link |
| `shrm.org/resourcesandtools/...benchmarking-reports-launch...` (old) | 200 via 301, **replaced anyway** |
| `shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports...` (new) | 200 |
| `shrm.org/topics-tools/news/talent-acquisition/real-costs-recruitment` (new) | 200 |
| `fastcompany.com/90708440/this-ceo-pays-new-employees-5000-to-quit` | 403 to automation, **not dead** |

The Fast Company 403 was checked rather than assumed: `fastcompany.com/` itself and a deliberately
fabricated Fast Company URL both return 403 to the same request, so the code is a blanket bot
block and carries no information about whether the article exists. The article is indexed and
canonical under that URL. Link left in place.

## Not done, deliberately

- **"Update examples", tab 13 row 1.** The ten questions and their model answers were read in
  full. None is stale. The page is #1 on five 590-volume terms and rewriting its body risks the
  ranking for no identified gain.
- **Answer-first restructuring.** Currently ranking posts are not restructured. Nothing was
  reordered, no headings changed, no sections added or removed. Block count is 137 before and
  after.
- **No new prose beyond the figure sentences themselves.** No new sections, no added paragraphs,
  no "downloadable templates" work beyond confirming the existing template link is alive.

## Fix pass

Run 2026-08-07, against the 59 verifier findings in `refresh-findings.json`. Five of them name this
post: one MED and four LOW. Four were defects and were fixed, one was accurate and was recorded for
Jessica rather than fixed. Two further things the findings did not name were found on the re-read
and handled. Sanity draft only, nothing published, no repo file touched.

### Document

| | |
|---|---|
| Draft patched | `drafts.4a4e07e8-b7bf-4173-b7e5-f77a7cfe9f8c` |
| Draft rev before | `kJ3OpIOJnJS2LKJpQpedzR` (`_updatedAt` 2026-08-07T03:56:34Z) |
| Draft rev after | `QzNVnRn1RN9Wy2ys8Qu8ob` (`_updatedAt` 2026-08-07T05:27:31Z) |
| Published rev after | `xOkZa3jk0O3ygI9ZPCD39b`, `_updatedAt` 2022-08-23T15:14:43Z, `updatedDate` null. Unchanged |
| Content blocks | 137 before, 137 after, same keys in the same order |
| Keys changed | exactly three: `ad6ab23440a4`, `b8f8cf668cb4`, `007def4d1446` |

One `.patch().set()` keyed on three individual `content[_key==...]` paths, guarded with
`.ifRevisionId()`. The script refuses to run unless `author` is still `author-corey-daniels`,
`updatedDate` is still `2026-08-06`, the block count is still 137, and each of the three targets
still holds the exact string the survey found. Nothing else in the document moved: `author`,
`updatedDate`, `publishDate`, `pageTitle`, `editorialTitle`, `metaDescription`, `slug` and
`featureImage` are byte-identical before and after.

### 1. The template link, MED, fixed

Block `007def4d1446`, markDef `5acfa7d6f21b`.

| | |
|---|---|
| Before | `https://docs.google.com/spreadsheets/d/1n4Ek13uzmuuKqxrjTexSzHMVLKADLh3uNQ8IZO2dJps/copy` |
| After | `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx` |

The finding is right and the divergence was real. `/blog/behavioral-interview-scoring-matrix` block
`731c15d3a0d3` was repointed at the hosted XLSX per Jessica's decision that the post no longer sends
anyone to Google Sheets; this post kept offering the same template from Google Sheets, and the two
refreshes ran twelve minutes apart in parallel with no way for this one to see that decision.

The sentence is unchanged. Its anchor text is "Download and use this template" on span
`74a74c70d54a0`, so the verb still matches a file download.

The file is `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/behavioral-interview-scoring-matrix.xlsx`,
9,272 bytes, committed as `c3791f2` "Host the interview scoring matrix as a download" on branch
`seo-phase-8-faq`. Checked live: `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx`
returns **404** today, which is expected and is not a reason to keep the Google link. It resolves
when that branch deploys. Both drafts want to go live after the file, not before.

Verified after patching: the string `docs.google.com` does not occur anywhere in the draft.

### 2. "across all industries and business sizes", LOW, fixed

Block `ad6ab23440a4`, span `47bda84959be2`.

| | |
|---|---|
| Before | `'s 2025 benchmarking report, the average cost to hire across all industries and business sizes is $5,475. Employers estimate the total cost of a hire can be as much as ` |
| After | `'s 2025 benchmarking report, the average cost to hire is $5,475. In 2022, employers estimated the total cost of a hire could be as much as ` |

The finding is right, and it was checked at source rather than taken on trust. The SHRM 2025
benchmarking press release was fetched with a desktop Chrome user agent, 200, 533,219 bytes, and its
text extracted. What it states, verbatim:

> Cost-per-Hire
> Nonexecutive Average: $5,475 Executive Average: $35,879

The phrase "all industries" does not occur on the page. Neither does "business size". The nearest
thing to a scope statement is in the methodology:

> Respondents represent a diverse range of industries, sectors, and organization sizes across the U.S.

That is a claim about who answered the survey, not about what the figure covers, and "a diverse
range" is not "all". The reports themselves are described as "88 individual data sets, spanning
overall, industry groupings, sectors, organization sizes, and regions", which is also not the same
claim, and those breakdowns are behind the member wall.

So the clause was an inherited 2022 scope statement attached to a different report and never checked
against the new one. Rule 1 gives two options, cite a page that does state it or drop the clause.
No SHRM page states it, so the clause went. **The figure, both links and the absence of the
non-executive qualifier are all untouched**, so Jessica's HANDOFF decision 9 is unaffected.

### 3. The 3x-4x clause had no year, not in the findings, fixed

Same block, same span, same patch. The clause read "Employers estimate the total cost of a hire can
be as much as three or four times the position's salary" with no date on it.

`https://www.shrm.org/topics-tools/news/talent-acquisition/real-costs-recruitment` was re-fetched,
200. It is dated **11 April 2022** and states:

> But many employers estimate the total cost to hire a new employee can be three to four times the
> position's salary, according to Edie Goldberg, founder of the Menlo Park, Calif.-based talent
> management and development company E.L. Goldberg & Associates.

So the estimate is genuine, correctly linked, and four years old. Rule 2 says every figure carries
the year it belongs to. A 2022 consultant estimate in the present tense on a page that renders
"Updated August 6, 2026" is the page reading as more current than it is, and the very next paragraph
had already been given "said in 2022 that" for exactly the same reason. The two now match.

The post's "three or four times" against the source's "three to four times" is pre-existing 2022
wording, semantically identical, and was left alone. The anchor text on span `47bda84959be3` is
unchanged.

### 4. Alt text on the scoring matrix screenshot, LOW, fixed

Block `b8f8cf668cb4`, asset `image-325025b697de4812563038a278dadb307b8a2232-1999x1125-png`.

The finding is right. That one asset appears in three posts and carried three different alt texts:

| Post | Block | States the 7/11/2022 date | States all five scale labels |
|---|---|---|---|
| `/blog/job-rejection-email` | `2297adf503aa` | yes | yes |
| `/blog/problem-solving-interview-questions` | `b8f8cf668cb4` | **no** | no, endpoints only |
| `/blog/behavioral-interview-scoring-matrix` | `771233236d49` | **no** | yes |

The image was downloaded from the Sanity CDN and viewed again rather than trusting either log.
Confirmed from the pixels: row 1 "Interview scoring matrix", row 2 "Position title", row 4
Interviewer / Candidate / Date, row 5 Name / **Candidate A** / **7/11/2022**, criteria in column A,
sample questions in column B, Score in column C, "Scoring scale" in column E reading 1 Well below
standard through 5 Well above standard, "Average score" at row 23, tabs Candidate A / Candidate B /
Candidate C.

Two sentences changed. The scale now lists all five labels rather than only the endpoints, and a
closing sentence names the header rows and the date:

> ...The scoring scale runs 1 well below standard, 2 below standard, 3 meets standard, 4 above
> standard, 5 well above standard, and the workbook carries one tab per candidate. Header rows for
> Position title, Interviewer, Candidate and Date are filled with sample data, the Date cell reading
> 7/11/2022.

The image itself is still held. This does not regenerate it; it stops the accessible layer from
hiding the one thing on the page that still says 2022, which the same pass had already logged under
"Images that need regenerating".

`/blog/behavioral-interview-scoring-matrix` block `771233236d49` still omits the date. That is
another agent's post and was not touched. Recorded so it is not lost.

### 5. Three em-dash blocks, LOW, recorded and not fixed

The finding is right about the substance and slightly off on the count: there are **four** em-dash
characters in **three** blocks, because `fdac62c7a022` carries a matched pair.

| Block | Text |
|---|---|
| `fdac62c7a022` | "the best hiring decision possible**—**and avoid having to do it all again in a few months**—**you need to know" |
| `8185af2b07a9` | "overcame a real problem at work**—**for example" |
| `51337de87277` | "require a thoughtful response**—**for example" |

All three are 2022 human prose in blocks neither pass otherwise touched, and nothing written in
either pass contains an em-dash. Removing them means rewriting sentences in a post that is #1 on
five 590-volume terms, which is Jessica's call and not a defect to fix unilaterally. Recorded in
QUESTIONS-FOR-JESSICA.md as item 9 under this post, which is what `/blog/job-rejection-email` and
`/blog/behavioral-interview-scoring-matrix` both did with theirs. The batch now reports the rule
the same way on every post that has one.

### 6. The log's wrong block key, LOW, fixed

The survey table in this file cited "`62a3d16a...` (32)" for the Ronzio pull quote. No block in the
document has a key beginning `62a`. Index 32 is **`fcfef189ee6d`**. The disposition recorded against
it was correct and the block is genuinely untouched; only the identifier was wrong. The table row
above has been corrected in place.

### Re-read of the whole draft

All 137 blocks read again after patching, plus `pageTitle`, `editorialTitle`, `metaDescription`,
`featureImage.altText`, `slug`, `publishDate`, `updatedDate`, `author` and every `markDefs` href.

**Every figure in the post and where its source stands today.**

| Figure | Block | Source, re-checked | Result |
|---|---|---|---|
| 59% of Millennials | `1266978b35ab` | gallup.com/workplace/236438, 200 | States it verbatim: "59% of millennials say opportunities to learn and grow are extremely important to them when applying for a job". Still **HELD** behind image `3b836ca47045`, correct as held |
| $5,475 | `ad6ab23440a4` | shrm.org 2025 benchmarking press release, 200 | States "Nonexecutive Average: $5,475". Scope clause removed, see 2 above |
| three or four times salary | `ad6ab23440a4` | shrm.org "The Real Costs of Recruitment", 200 | States "three to four times the position's salary", 11 April 2022. Year added, see 3 above |
| $5,000 to quit | `643ed442a086` | fastcompany.com/90708440, **read in a browser** | See below |
| $5,000 pull quote | `fcfef189ee6d` | same article | See below |

**The Fast Company article was opened in a browser, and that corrects an entry in
QUESTIONS-FOR-JESSICA.md.** The refresh pass established that the 403 is a blanket bot block and
left the link in place, which was the right call, but the consolidated index recorded "No figure was
taken from it". That is wrong: the $5,000 figure and the pull quote both hang on it, and neither had
been read at source by anybody. Loaded through Playwright: **200**, title "This CEO pays new
employees $5,000 to quit", by Stephanie Vozza, dated **01-05-2022**. It states the figure:

> Chris Ronzio, CEO and founder of Trainual ... says offering employees $5,000 to leave just two
> weeks after starting employment helps him find and retain top talent

and it carries the quote the post prints. It also confirms the policy's history: $2,500 originally,
instituted May 2020, raised to $5,000, and "none of the 38 people hired since the policy was
implemented has taken the offer". Nothing published since either way, so "said in 2022 that" stands.

**One thing found in the quote and deliberately not changed.** Block `fcfef189ee6d` prints two
sentences of that quote as if they were contiguous. The source has a third between them: "If someone
knows a week or two in that this is not their long-term place or position, it gets more expensive to
replace them as they take on more work and responsibility." Every word the post prints is verbatim
and the meaning does not change, so this is a quotation convention rather than a misquote, and it is
2022 prose the refresh deliberately left alone. Marking the omission with an ellipsis is a
one-character edit. Recorded as item 10 in QUESTIONS-FOR-JESSICA.md rather than made.

**Links re-checked live.**

| URL | Result |
|---|---|
| `polymer.co/blog/a-player` | 200 |
| `polymer.co/blog/first-impression-bias` | 200 |
| `polymer.co/blog/behavioral-interview-scoring-matrix` | 200 |
| `app.polymer.co/register` | 200 |
| `gallup.com/workplace/236438/...` | 200, states the 59% |
| `shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports...` | 200, states $5,475 |
| `shrm.org/topics-tools/news/talent-acquisition/real-costs-recruitment` | 200, states three to four times |
| `fastcompany.com/90708440/...` | 403 to curl, **200 in a browser**, states the figure and the quote |
| `polymer.co/behavioral-interview-scoring-matrix.xlsx` (new) | 404 until `seo-phase-8-faq` deploys |
| `docs.google.com/spreadsheets/d/1n4Ek.../copy` | no longer referenced by this post |

**Nothing else moved.** No plan name, product name or price appears in the post. The ten example
questions and their model answers were not touched, per instruction and per rule 5. No section was
added, removed or reordered. No new prose was written beyond the two clauses in block
`ad6ab23440a4` and the two alt-text sentences.

### Verification after patching

- Draft re-read from the API and diffed key by key against the pre-patch snapshot.
- Block keys and their order identical, 137 before and after.
- Exactly three blocks differ, and all three are the intended ones.
- No document field outside `content` changed. `author` still `author-corey-daniels`,
  `updatedDate` still `2026-08-06`, `publishDate` still `2022-08-23`.
- Published document re-read: `_rev` `xOkZa3jk0O3ygI9ZPCD39b` and `_updatedAt`
  2022-08-23T15:14:43Z, both unchanged. Nothing was published.
- Full-document string search: no `docs.google.com`, no "all industries".
- Em-dash count in the document is 4, the same four that were there before. None was introduced.
