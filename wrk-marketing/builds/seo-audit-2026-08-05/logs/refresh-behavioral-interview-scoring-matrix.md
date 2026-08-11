# Refresh log: `/blog/behavioral-interview-scoring-matrix`

Tab 13 row 3, refresh order 3, "Add downloadable scorecard template (also feeds 'interview
scorecard template', 210 vol)". Tab 01 row 8, "Link + refresh + add downloadable template".
Ranking position today: pos 12-25 rubric/sheet cluster, 108 keywords, 5 referring domains.
Run 2026-08-06. Sanity draft only, nothing published. **One repo file added**, which is the
sanctioned exception for this post: the hosted XLSX.

## Document

| | |
|---|---|
| Published id | `50b679a8-8601-4697-b7ae-804f56ef65eb` |
| Draft patched | `drafts.50b679a8-8601-4697-b7ae-804f56ef65eb` |
| Draft rev before | `kJ3OpIOJnJS2LKJpQpSaw1` (`_updatedAt` 2026-08-07T03:03:33Z, `updatedDate` null) |
| Draft rev after | `QzNVnRn1RN9Wy2ys8Qp6LB` (`_updatedAt` 2026-08-07T03:59:26Z, `updatedDate` 2026-08-06) |
| Published rev after | `E7eX1vrAAKHQPLJk7VWKKB`, `_updatedAt` 2023-08-08T11:56:35Z, unchanged |
| Content blocks | 119 before, 119 after |
| Author on the draft | `author-jessica-gertig`, already assigned, **not changed** |

The draft already existed. Before patching it was read in full and diffed against the published
document: the only difference was the `author` reference, so nothing else was pending in it.
It was patched with a single `.patch().set()` keyed on individual `content[_key==...]` paths,
never overwritten. The patch script refuses to run if `author` is absent. The published document
was read for comparison and never mutated; its `_rev` is byte-identical before and after.

## Survey

The whole post was read block by block. 119 blocks, five body images, one feature image, one
table, one ToC block, plus `pageTitle`, `editorialTitle`, `metaDescription`, `publishDate` and
every `markDefs` href. Every image was downloaded from the Sanity CDN and viewed.

Everything in the post that carries a figure, a date, an attribution, an "according to", a
named report or a claim that could have gone stale:

| Block | What it carries | Disposition |
|---|---|---|
| `e944f0e90093` (1) | "According to a Monster survey, employers say finding skilled candidates will be their top challenge **this year**", linked to Monster's Future of Work **2022** Global Report PDF | **REPLACED**, figure and link |
| `6fe2d763a6c3` (0) | Same `ea8b41cb40e6` markDef carrying the same dead 2022 Monster PDF URL, with no span using it | **REPLACED**, orphan markDef href |
| `1ee1049a170a` (56) | "The Monster survey linked above found that **63%** of employers are willing to hire someone with transferable skills" | **REPLACED**, see the caveat below |
| `857d94077bcd` (10) | Image `sourceUrl` to `hrsg.ca/hubfs/Complete%20Guide%20to%20Running%20Competency-Based%20Interviews.pdf` | **404. Repointed** to the live HRSG page for the same guide |
| `731c15d3a0d3` (70) | "download and use this template", linked to the Google Sheets `/copy` URL | **REPLACED** with the hosted XLSX, per Jessica's decision |
| `d0255c3b827c` (39) | Image `sourceUrl` to Resumeway | Verified 200, unchanged |
| `379449eb5302` (53) | Closed-versus-open question table, four rows | No figure, no date, unchanged |
| `9970a2e8cff6` etc. (79) | thedecisionlab.com confirmation-bias link | Verified 200, unchanged |
| `01bca4ccde6b` (65) | polymer.co/features link | Verified 200, unchanged |
| `af40e8c22697` (66) | "Polymer can even deliver documents or assessments with templated messages when candidates move to the next stage" | Product claim, no figure, no pricing, left alone |

Blocks 99, 103, 104 and 106 use "today" and "now" about how a candidate's own behaviour changes
over time. That is not dated data and none of it was touched.

**No pricing claims in this post.** The dead per-job pricing model the handoff flags in
`/blog/best-job-board-software` does not appear here.

Nothing else in the 119 blocks carries a statistic, a study, a named report, a "recent study
found", a "last year", or a practice claim.

## Figures replaced

### 1. The Monster hiring-challenge figure

Block `e944f0e90093`, plus the same markDef on block `6fe2d763a6c3`.

Before:

> According to a Monster survey, employers say **their top challenge** this year will be finding
> skilled candidates. So, it's no surprise that you'd want to find out as much as possible about
> a candidate's experience.
>
> Link on "their top challenge" to
> `https://media.monster.com/marketing/2022/The-Future-of-Work-2022-Global-Report.pdf?_ga=2.262419724...`

After:

> According to **Monster's 2026 Hiring WorkWatch Report**, **64%** of employers say they struggle
> to find qualified candidates, the most cited factor slowing hiring down. So, it's no surprise
> that you'd want to find out as much as possible about a candidate's experience.
>
> Link on "Monster's 2026 Hiring WorkWatch Report" to
> `https://www.monster.com/career-advice/research/2026-hiring-workwatch-report`

**Source, read directly.** Monster's 2026 Hiring WorkWatch Report, a survey of 800 US-based
hiring decision-makers, page updated 11 February 2026. Its words: "Employers also report that
finding qualified candidates is still difficult: 64% say they struggle to do so." The same page
ranks the operational factors that slow hiring, and finding qualified candidates is first at 64%,
ahead of salary and benefit expectations (44%), addressing skills gaps (30%), competition from
other employers (27%) and remote and hybrid expectations (24%).

`monster.com` returns 403 to curl and to WebFetch. The page was read through Playwright, which is
why the figure could be taken from the publisher rather than from a search snippet.

**The old URL.** `media.monster.com/.../The-Future-of-Work-2022-Global-Report.pdf` returns 403,
and the Future of Work series has been superseded by WorkWatch. Either way it was a 2022 report
being cited for "this year" in 2026.

### 2. The transferable-skills figure

Block `1ee1049a170a`.

Before:

> For example, the interviewee might not have experience in a certain area, but they could have
> relatable skills that transfer to the role. **The Monster survey linked above found that 63% of
> employers are willing to hire someone with transferable skills**, so it's not unheard of.
>
> No link on the block.

After:

> For example, the interviewee might not have experience in a certain area, but they could have
> relatable skills that transfer to the role. **NACE's Job Outlook 2026 survey found that 70% of
> employers now use skills-based hiring, judging candidates on the skills they have rather than
> their degree or GPA**, so it's not unheard of.
>
> New link markDef `b7c41d9e2f08` on "NACE's Job Outlook 2026 survey" to
> `https://www.naceweb.org/job-market/trends-and-predictions/employer-use-of-skills-based-hiring-practices-grows`

**Source, read directly.** NACE, "Employer Use of Skills-Based Hiring Practices Grows",
12 January 2026, reporting NACE's Job Outlook 2026 survey (fielded 7 August to 22 September 2025,
183 respondents, 170 of them NACE employer members). Its words: "Among survey participants, 70%
report using skill-based hiring, up from 65% last year", and, defining the term, "Employers do so
by focusing on the skills candidates have rather than academic degrees or GPAs."

**This is a publisher change and it is in QUESTIONS-FOR-JESSICA.** The 63% is a Monster 2022
figure that Monster no longer publishes; its successor report carries no equivalent. Searches
against SHRM's 2026 Talent Trends Report (27 April 2026) and LinkedIn's Skills on the Rise 2026
(24 February 2026) found no like-for-like "willing to hire someone with transferable skills"
figure either. Leaving 63% in place while replacing its neighbour was not an option, so the
nearest current, primary, verifiable figure went in. The claim shifts slightly, from "willing to
hire on transferable skills" to "hires on skills rather than degrees", and that shift is hers to
accept or send back.

The same NACE page also reports that 58% of employers use skills-based hiring when building
interview rubrics and 87% when interviewing, which is this post's exact subject. Neither was
added: that would be new prose, and the refresh definition does not include it.

## Link repaired

Block `857d94077bcd`, the image `sourceUrl` under "What is the behavioral interview scoring
matrix?".

| | |
|---|---|
| Before | `https://www.hrsg.ca/hubfs/Complete%20Guide%20to%20Running%20Competency-Based%20Interviews.pdf`, **404** |
| After | `https://resources.hrsg.ca/blog/ebooks/complete-guide-to-running-competency-based-interviews`, 200 |

Same document, same publisher, same title ("Complete Guide to Running Competency-based
Interviews"), still a free download, now on HRSG's own resources site rather than a moved hubfs
path. The raw PDF also survives at
`https://cdn2.hubspot.net/hubfs/188537/Complete%20Guide%20to%20Running%20Competency-Based%20Interviews.pdf`
(200, `application/pdf`); HRSG's own page was used rather than the bare CDN file.

The image `source` string "HRSG" is unchanged.

## The downloadable template

Tab 13 row 3 and tab 01 row 8 both ask for it. Jessica's decision: a real download on
polymer.co, not a Google link.

**Repo file added:** `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/public/behavioral-interview-scoring-matrix.xlsx`
(9,292 bytes). Working tree was clean and on branch **`seo-phase-8-faq`** when it was written.
Not committed; that is the orchestrator's call.

**How it was built.** Exported from
`https://docs.google.com/spreadsheets/d/1n4Ek13uzmuuKqxrjTexSzHMVLKADLh3uNQ8IZO2dJps/export?format=xlsx`,
opened with openpyxl, cell A1 of the first sheet rewritten, saved. Three sheets, Candidate A /
Candidate B / Candidate C, all preserved, along with the `=AVERAGE(...)` formula at the bottom of
each and the column widths. The workbook carries no data validation, no conditional formatting
and no charts, so the openpyxl round trip loses nothing.

Cell A1, `Candidate A`:

| | |
|---|---|
| Before | Instructions: make a copy before using. Head to File > "Make a copy" and save the scoring matrix to your Google Drive to start using right away. |
| After | Instructions: this workbook is your copy, so edit it directly. Use one tab per candidate, score every answer from 1 to 5 with the scoring scale in column E, and compare the average score at the bottom of each tab. |

Verified after saving: sheet names, A1, A2, `Candidate A!C24` = `=AVERAGE(C9:C23)`,
`Candidate B!C23` = `=AVERAGE(C8:C22)`, `Candidate C!B5` = "Candidate C", column B width 71.63.

**The post's link now points at it.** Block `731c15d3a0d3`, markDef `85b995b4cf20`, href changed
from the Google Sheets `/copy` URL to `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx`.
The sentence itself is unchanged and already read "Feel free to download and use this template to
guide your next hiring round", so the verb still matches.

**That URL 404s today** and will until the branch carrying the file deploys. Sequencing note in
QUESTIONS-FOR-JESSICA.

## Images

All six were downloaded from `cdn.sanity.io/images/a6d1clb1/production/` and viewed. Alt text was
written from the graphic, not from the paragraph beside it.

### `featureImage`, field `altText`

Shows four circular markers on black: three empty dashed outlines and, second from the left, a
solid ring with a checkmark inside.

| | |
|---|---|
| Before | Behavioral Interview Scoring Matrix Header Image |
| After | Four circular markers on a black background: three empty dashed outlines and, second from the left, a solid ring containing a checkmark, showing one of four options selected. |

### `857d94077bcd`, under "What is the behavioral interview scoring matrix?"

Shows one HRSG competency block, labelled down the left in five parts: criteria name and
definition (Creativity & innovation, "Generating viable, new approaches and solutions"); the
job-specific question; five probes; behavioral indicators; and a 1-5 rating scale reading
well below standard / below standard / meets standard / above standard / well above standard.
"Source: HRSG" bottom right.

| | |
|---|---|
| Before | Screenshot of Behavioral interview scoring matrix example |
| After | One competency block from a behavioral interview scoring matrix, labelled in five parts: criteria name and definition (Creativity and innovation, generating viable, new approaches and solutions); the job-specific question, describe the most complex problem you faced and how you generated a new approach or solution; five probes to draw out specifics; behavioral indicators to look for, such as creating new ideas for ongoing challenges and solving complex problems through new explanations; and a rating scale of 1 well below standard, 2 below standard, 3 meets standard, 4 above standard, 5 well above standard. Source: HRSG. |

### `f209655a27a6`, under "1. Create a rating scale"

Shows a two-column candidate scorecard. **It carries six scores and a total, all rendered as
pixels**: results orientation 3, initiative 4, analytical thinking 3, conceptual thinking 4,
problem solving 4, integrity 5, total score 23. Arithmetic checks out.

| | |
|---|---|
| Before | Screenshot of candidate scorecard example |
| After | Candidate scorecard with a criteria column and a candidate score column: results orientation 3, meets standard; initiative 4, above standard; analytical thinking 3, meets standard; conceptual thinking 4, above standard; problem solving 4, above standard; integrity 5, well above standard. Total score 23. |

These are illustrative scores for an invented candidate, not published data, so nothing about
them is stale and no figure is held on their account.

### `d0255c3b827c`, under "2. Choose the interview questions"

Shows sixteen example questions under eight competency headings, "Source: Resumeway" bottom right.

| | |
|---|---|
| Before | Screenshot of competency-based behavioral interview questions |
| After | Example competency-based behavioral interview questions grouped under eight competencies, two questions each: results orientation, initiative, impact and influence, customer service orientation, analytical thinking, conceptual thinking, problem solving, and integrity. Examples include tell me about a period when you were focused on achieving your goals, and describe a situation where you had to make a difficult decision based upon your values. Source: Resumeway. |

### `771233236d49`, under "A behavioral interview scoring matrix template"

Shows the template open in the Google Sheets web UI, complete with menu bar, Share button and the
Candidate A / Candidate B / Candidate C tabs. **Carries a date rendered as pixels, cell C5 reads
7/11/2022.** Its row 1 is the "Interview scoring matrix" title, so the screenshot predates the
instructions row that sits in A1 of the live sheet.

| | |
|---|---|
| Before | Screenshot of behavioral interview scoring matrix template on google sheet |
| After | The interview scoring matrix template open in Google Sheets, with one tab per candidate: Candidate A, Candidate B and Candidate C. Rows list the criteria cultural fit, career motivation, social skills, teamwork, technical skills, leadership capabilities, critical thinking and problem solving, and self-awareness, each with sample questions and a score column that feeds an average score row. A scoring scale column runs 1 well below standard, 2 below standard, 3 meets standard, 4 above standard, 5 well above standard. |

The alt says Google Sheets because that is what the picture shows. Recorded under "Images that
need regenerating" in QUESTIONS-FOR-JESSICA, because the post now links to an XLSX instead.

### `abe851b5cbbc`, under "Easier to review and compare candidates"

**The old alt was wrong, not merely thin.** It said "candidate's answers comparison"; the graphic
is a bar chart of scores, and it was clearly written from the paragraph above it rather than from
the image. Bar ends were measured against the axis ticks to confirm the values: Candidate A 5,
Candidate B 3, Candidate C 4.

| | |
|---|---|
| Before | Screenshot of candidate's answers comparison |
| After | Bar chart titled Candidate scores comparing three candidates on a five-point scale: Candidate A scores 5, Candidate B scores 3 and Candidate C scores 4. The axis reads 1 well below standard, 2 below standard, 3 meets standard, 4 above standard, 5 well above standard. |

## Figures held

**None.** No image in this post carries a published statistic. The scorecard totals and the bar
chart are illustrative figures for invented candidates, and the two sourced graphics (HRSG,
Resumeway) carry rubric structure and question text, not data. So no prose figure had to be held
back to avoid contradicting a graphic, and both dated figures in the post were replaced.

The Google Sheets screenshot is a separate matter, recorded as an image to regenerate rather than
a figure held.

## Not done, deliberately

- **Not restructured for answer-first.** Tab 13 row 3 does not ask for it and the post ranks
  pos 12-25 across the rubric/sheet cluster. Per the standing rule, currently ranking posts are
  not restructured.
- **No new prose, no new sections.** The refresh definition is four things: 2026 data, updated
  modified dates, author bylines, downloadable templates. All four landed.
- **The ten sample questions in the table and the eight competency headings were not touched.**
  None is stale.
- **Four pre-existing em-dashes** sit in blocks 74, 104, 109 and 112, all in prose this refresh
  did not otherwise touch. Nothing I wrote contains one. Left alone rather than editing copy
  outside the refresh; say the word if they should go.

## Verification

Re-read the draft from the API after patching and diffed it against the pre-patch snapshot:

- Published `_rev` identical before and after, `E7eX1vrAAKHQPLJk7VWKKB`.
- `author` identical, `author-jessica-gertig`.
- `publishDate` unchanged, `2023-08-08`. `updatedDate` now `2026-08-06`.
- Content array still 119 blocks. Exactly 9 keys changed, and all 9 are the intended ones:
  `6fe2d763a6c3`, `e944f0e90093`, `857d94077bcd`, `f209655a27a6`, `d0255c3b827c`,
  `1ee1049a170a`, `771233236d49`, `731c15d3a0d3`, `abe851b5cbbc`.
- No other document field changed.
- Full-document string search: no `media.monster.com`, no `hrsg.ca/hubfs`, no
  `docs.google.com/spreadsheets`, no `63%` anywhere in the draft.
- All five content images have a non-empty `alt`, lengths 627 / 304 / 466 / 520 / 267.
- Every href in the document re-checked live: `monster.com` 2026 report 200 via Playwright,
  NACE 200, HRSG resources page 200, Resumeway 200, thedecisionlab 200, `polymer.co/features` 200,
  `polymer.co/blog/a-player` 200, `polymer.co/blog/best-applicant-tracking-software` 200,
  `polymer.co/blog/first-impression-bias` 200. The XLSX URL 404s until the branch deploys.
- Second dated-language pass over the patched draft: only blocks 1 and 56 carry figures, both now
  2026 and both carrying the year in the sentence.

## Fix pass

Run 2026-08-07 against the 59 verifier findings in `refresh-findings.json`. Seven of them name this
post: 2 MED, 5 LOW. Three were defects and are fixed, three are Jessica's call and are recorded,
one is a non-defect the verifier itself labelled as such. Draft patched again, published document
still untouched.

| | |
|---|---|
| Draft rev before this pass | `QzNVnRn1RN9Wy2ys8Qp6LB` (matches the rev the refresh left, so nothing else touched it in between) |
| Draft rev after this pass | `kJ3OpIOJnJS2LKJpQppdvR`, `_updatedAt` 2026-08-07T05:26:58Z |
| Published rev | `E7eX1vrAAKHQPLJk7VWKKB`, `_updatedAt` 2023-08-08T11:56:35Z, unchanged again |
| Content blocks | 119 before, 119 after |
| Keys changed | exactly 3: `e944f0e90093`, `1ee1049a170a`, `857d94077bcd` |
| Other document fields | none changed. `author` still `author-jessica-gertig`, `updatedDate` still 2026-08-06, `publishDate` still 2023-08-08 |

One `.patch().ifRevisionId('QzNVnRn1RN9Wy2ys8Qp6LB').set()` carrying three keyed paths, so the three
edits landed as one transaction and a concurrent write would have failed it rather than half-applied
it. The script asserted the exact prior text of each span and the presence of `author` before
committing.

### Fixed 1. NACE's population is named (MED)

Block `1ee1049a170a`, span `c2e5947681042`.

| | |
|---|---|
| Before | " found that 70% of employers now use skills-based hiring, judging candidates on the skills they have rather than their degree or GPA, so it's not unheard of." |
| After | " found that **70% of employers who recruit new college graduates** now use skills-based hiring, judging candidates on the skills they have rather than their degree or GPA, so it's not unheard of." |

The figure was verbatim correct and stays. What was wrong is that NACE's panel was presented as
"employers". The page was re-read on 2026-08-07, HTTP 200 to curl with a browser user agent, no
Playwright needed. Its words: "Among survey participants, 70% report using skill-based hiring, up
from 65% last year"; "The Job Outlook 2026 report is the definitive source on employer hiring
projections for **new college graduates**"; "NACE collected data for its Job Outlook 2026 survey from
August 7, 2025, through September 22, 2025. Of the 183 total respondents, 170 were NACE employer
members, representing 22.7% of eligible member respondents. The Job Outlook 2026 survey was also
distributed to nonmember companies; this group provided an additional 13 responses."

`/blog/agile-recruiting-process` carries the same figure and is being fixed with the same phrase,
"employers who recruit new college graduates", so the two posts do not describe one survey two ways.

### Fixed 2. The Monster superlative is cut (LOW)

Block `e944f0e90093`, span `e3fdd429cd2d2`.

| | |
|---|---|
| Before | ", 64% of employers say they struggle to find qualified candidates, **the most cited factor slowing hiring down**. So, it's no surprise that you'd want to find out as much as possible about a candidate's experience." |
| After | ", 64% of employers say they struggle to find qualified candidates. So, it's no surprise that you'd want to find out as much as possible about a candidate's experience." |

The verifier is right and the clause is gone. `monster.com` still returns 403 to curl even with a
full browser user agent (DataDome interstitial), so the page was re-read through Playwright on
2026-08-07. It carries the 64% verbatim: "Employers also report that finding qualified candidates is
still difficult: 64% say they struggle to do so." It never states a superlative. Its ranking passage
reads "Monster's research highlights several operational factors that can slow hiring, **including**:
Finding qualified candidates (64%), Salary and benefit expectations (44%), Addressing skills gaps
(30%), Competition from other employers (27%), Meeting remote and hybrid expectations (24%)". 64% is
the top of that list, but "including" marks it non-exhaustive, so "most cited" was an inference from
an admittedly partial list. Restating it as "highest of the factors it lists" would have been the
same class of derived claim as the 30% complement the verifier flagged on
`/blog/agile-recruiting-process`, so the clause went rather than being reworded. Nothing else in the
sentence moved.

### Fixed 3. The HRSG alt drops a word the graphic prints (LOW)

Block `857d94077bcd`, field `alt`. The image was downloaded from
`cdn.sanity.io/images/a6d1clb1/production/0fe96a4c164115aa7d85028f6eb39a3fe549273f-1288x1999.png`
and viewed again. Its job-specific question reads, in pixels: "Describe the most complex problem that
you were faced with and how you generated a new approach **or explanation** or solution."

| | |
|---|---|
| Before | "...the job-specific question, describe the most complex problem you faced and how you generated a new approach or solution;..." |
| After | "...the job-specific question, describe the most complex problem you were faced with and how you generated a new approach or explanation or solution;..." |

Every other clause in that alt was re-checked against the graphic in the same viewing and all of it
holds: the five labelled parts, "Creativity & innovation" and its definition, the five probes, the
behavioral indicators, the 1 to 5 scale and the "Source: HRSG" line.

### Jessica's call 1. The connective the NACE figure now serves (LOW)

Block `1ee1049a170a` closes "so it's not unheard of". The retired 63%, employers willing to hire
someone with transferable skills, supported that clause directly. The NACE figure is about hiring on
skills rather than degrees or GPA, a credentials axis rather than an adjacent-experience axis, so the
clause now rests on a figure beside the point rather than on it. Rewriting the clause is prose
editing outside a refresh and the post is a currently ranking one, so nothing was reworded. Recorded
under item 1 of "Content refresh, `/blog/behavioral-interview-scoring-matrix`" in
QUESTIONS-FOR-JESSICA.md with four options: keep it, reword the closing clause, cut the statistic, or
restore 63% dated to 2022.

### Jessica's call 2. What a regenerated template screenshot should show in the Date cell

The workbook ships with empty date cells, so "screenshot it with a current date in the Date cell" is
an instruction the file cannot satisfy on its own. Either the shot shows the Date cell empty as it
ships, or a date is typed in for the shot. Recorded in both image entries.

### Jessica's call 3. Whether "no like-for-like 2026 transferable-skills figure exists" is settled

One verifier recorded that it could not retest this claim. I retested it: the session's WebSearch
budget was exhausted by other agents, so two searches were run in a real browser instead, for a
current "% of employers willing to hire on transferable skills" figure. Nothing like-for-like
surfaced. The first returned only 2026 listicles of which transferable skills employers want
(Resume Genius, Keller Group, The Interview Guys, Resumeway); the second returned no results at all.
That is an unsuccessful search and it is written into QUESTIONS-FOR-JESSICA.md as an unsuccessful
search, not as proof the figure does not exist.

### Not a defect. The orphan markDef (LOW)

Block `6fe2d763a6c3` still carries markDef `ea8b41cb40e6` with the Monster 2026 href and no span
referencing it (all its children carry `marks: []`). The verifier itself concluded this is not a
defect and it has zero reader-visible effect either way. Left in place: removing it would be a write
to a block this pass has no reason to touch, and it is already disclosed. Recorded here so the
decision is not silent.

### Corrections written into QUESTIONS-FOR-JESSICA.md

Five statements in that file were false or unsupported about artifacts that shipped. Each is now
corrected in the entry Jessica reads, not only in the errata section 300 lines below it.

1. **Item 4, "the sample interview date in cell C5 of each tab still reads 7/11/2022".** False.
   Verified with openpyxl against the committed file: the "Date" label sits in C5 on `Candidate A`
   and in C4 on `Candidate B` and `Candidate C`, and the value cell under each of the three (C6, C5,
   C5) holds no value. A scan of every cell in all three sheets found no date value and no cell
   containing "2022". The `M/d/yyyy` number format survives on those cells, so a date a user types
   still renders as a date. Also added: the A1 rewrite is on the `Candidate A` tab only, which the
   entry never said.
2. **Item 3, "the file ... is uncommitted".** False. Committed as `c3791f2`, "Host the interview
   scoring matrix as a download", on branch `seo-phase-8-faq`, working tree clean for that path.
3. **The recorded size, 9,292 bytes.** 9,272 on disk. The 9,292 figure in the body of this log,
   under "The downloadable template", is the same stale number and is superseded here.
4. **Item 2's quoted after-text** still carried "the most cited factor slowing hiring down". Updated
   to the sentence as it now stands, with Monster's actual wording and the "including" qualifier
   quoted so the reason is on the page rather than asserted.
5. **Item 1** never named NACE's population. It now does, along with where the claim shift lands and
   the retest of the "no like-for-like figure" claim.

Two image entries said a regenerated screenshot should show "a current date in the Date cell": the
one for this post's block `771233236d49`, and the one for `/blog/problem-solving-interview-questions`
block `b8f8cf668cb4`, which another agent repointed at this same hosted workbook during this pass.
Both now say the shipped file's date cells are empty. The errata entry under "Corrections from
verification to entries already in this file" is marked closed, so Jessica does not read a correction
and an uncorrected entry and have to work out which is live.

The sequencing warning is unchanged and still live: `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx`
was re-requested on 2026-08-07 and still returns **404**. Do not publish the draft ahead of the
branch.

### Full re-read of the patched draft

All 119 blocks read again after patching, looking for anything the findings did not name.

- Every href in the document re-requested on 2026-08-07: `polymer.co/blog/a-player` 200,
  `resources.hrsg.ca` guide 200, `polymer.co/blog/best-applicant-tracking-software` 200,
  `resumeway.com` 200, `naceweb.org` 200, `polymer.co/features` 200, `thedecisionlab.com` 200,
  `polymer.co/blog/first-impression-bias` 200, `monster.com` 2026 report 200 through Playwright.
  The XLSX URL 404s, as expected until deploy.
- Both sentences that carry a figure carry its year: "Monster's 2026 Hiring WorkWatch Report" and
  "NACE's Job Outlook 2026 survey". No other block in the post carries a statistic, a study, a named
  report or a dated practice claim.
- Full-document string search after patching: no `most cited factor`, no `media.monster.com`, no
  `hrsg.ca/hubfs`, no `docs.google.com/spreadsheets`, no `63%`.
- Em-dashes: still exactly four, in blocks 74, 104, 109 and 112, all pre-existing prose this pass did
  not touch. Nothing written in this pass contains one.
- `pageTitle`, `editorialTitle` and `metaDescription` carry no figure, no year and no product claim
  that has moved.
- `updatedDate` deliberately left at 2026-08-06 rather than bumped to 2026-08-07, so this post's
  modified date stays consistent with the other ten posts in the batch.
- The remaining product claim in block `af40e8c22697`, "Polymer can even deliver documents or
  assessments with templated messages when candidates move to the next stage", carries no figure and
  no pricing and was left as the refresh left it.
