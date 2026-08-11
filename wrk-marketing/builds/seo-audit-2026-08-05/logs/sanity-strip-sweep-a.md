# Sanity strip sweep A

Posts: `problem-solving-interview-questions`, `behavioral-interview-scoring-matrix`,
`interview-feedback-examples`, `talent-acquisition-vs-recruitment`.
Run 2026-08-07. Sanity drafts only. No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` touched.

## Method

Every draft was diffed against its published document field by field and block by block, rather than
read off the refresh logs. Comparison covered: block keys present and absent, block order, block
`style` and `_type`, the concatenated text of every block, `alt`, `sourceUrl`, every `markDefs`
href, and every document field outside `content`.

Authorising sources read in full: workbook tabs `Overview`, `13 Content Freshness`,
`01 Orphaned Pages`, and `_in-progress/seo-content-refresh/approved-decisions.md`.

## Structural finding: there is none

No post has a deleted block, an added block, a reordered block, or a changed block `style`. No
heading text changed anywhere. `toc` and `table` blocks are byte-identical to published.

| Post | Blocks pub -> draft | Deleted | Added | Reordered | Style changes |
|---|---|---|---|---|---|
| `problem-solving-interview-questions` | 137 -> 137 | 0 | 0 | no | 0 |
| `behavioral-interview-scoring-matrix` | 119 -> 119 | 0 | 0 | no | 0 |
| `interview-feedback-examples` | 100 -> 100 | 0 | 0 | no | 0 |
| `talent-acquisition-vs-recruitment` | 129 -> 129 | 0 | 0 | no | 0 |

Every post's field diff against published is exactly `featureImage` (altText only, same asset
`_ref`), `author`, `updatedDate`. No `pageTitle`, `editorialTitle`, `metaDescription`, `slug` or
`publishDate` moved on any of the four.

## Restored: 1

### `interview-feedback-examples`, block `205f502889fe`

| | |
|---|---|
| Draft rev before | `QzNVnRn1RN9Wy2ys8Qu8WV` |
| Draft rev after | `kJ3OpIOJnJS2LKJpQq2MCz` |
| Paths set | `content[_key=="205f502889fe"].children`, `content[_key=="205f502889fe"].markDefs` |

Published text, now restored byte for byte:

> **Send timely rejections (either manually or automated).** Aim to provide feedback within a week,
> as waiting too long can feel impersonal and harm your reputation.

What was there before this sweep:

> **Send timely rejections (either manually or automated).** Aim to provide feedback within three to
> five days, the disposition window the [Candidate Experience Institute's write-up of the 2025 CandE
> Benchmark Research](https://www.candidate-experience-institute.com/cande-2025-benchmark-the-3-to-5-day-decision-rule-that-separates-award-winners-from-everyone-else)
> links to higher offer acceptance and stronger re-application rates. Waiting too long can feel
> impersonal and harm your reputation.

**Why.** The published sentence carried no figure, no year, no source and no named study. It is
editorial advice. The refresh changed the advice and bolted on a new sourced claim, adding two spans
and a markDef. Tab 13 row 4 for this post reads "Refresh examples; answer-first blocks" and tab 01
row 10 reads "Link + refresh"; refresh is defined on the Overview as "2026 data, updated modified
dates, author bylines, downloadable templates". Replacing advice that carried no data is not 2026
data, and the added clause is new prose. `refresh-interview-feedback-examples.md` says so itself:
"It is the one edit in this pass that added a claim rather than swapping a number, and the source is
not primary", and offers Jessica "revert to 'within a week'" as one of three options.

The markDef went back to `[]` with the children, so the restoration leaves no orphan. The two
published span keys `625755d595460` and `965eb406276b` are the ones now in the draft; the two spans
the refresh added, `965eb406276c` and `965eb406276d`, are gone. Verified after the patch: the block
is `JSON.stringify`-identical to the published block, the document still has 100 blocks in the same
order, `author` is still `author-corey-daniels`, `updatedDate` is still `2026-08-06`, and no other
block changed.

## Kept, with the cell that authorises it

### `problem-solving-interview-questions`

| Block | Change | Authority |
|---|---|---|
| `ad6ab23440a4` | SHRM $5,475, 2025 press release + Real Costs of Recruitment links, "In 2022, employers estimated" | Approved decision 9. Stated plainly, no non-executive qualifier, as settled |
| `643ed442a086` | "says" -> "said in 2022 that" | Decision 1, the sentence carries the year the figure belongs to |
| `ec8a1120325b`, `3b836ca47045`, `b8f8cf668cb4`, `featureImage.altText` | Descriptive alt text | Decision 2 |
| `1266978b35ab` / image `3b836ca47045` | Gallup 59% untouched in prose | Decisions 6 and 9, held because the graphic carries it |
| The ten example questions | Untouched | Decision 5 |
| `author`, `updatedDate` | `author-corey-daniels`, `2026-08-06` | Tab 13 row 1 "author byline + dateModified schema", Overview K23 |

### `behavioral-interview-scoring-matrix`

| Block | Change | Authority |
|---|---|---|
| `731c15d3a0d3` | Google Sheets `/copy` -> `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx` | Tab 13 row 3 "Add downloadable scorecard template", tab 01 row 8 "add downloadable template" |
| `e944f0e90093` + `6fe2d763a6c3` | Monster 2022 report -> Monster 2026 Hiring WorkWatch, 64% | Overview K23 "2026 data" |
| `857d94077bcd` | `sourceUrl` off a 404 hubfs path onto the live HRSG page | Same document, same publisher, link repair with no reader-visible text change |
| `857d94077bcd`, `f209655a27a6`, `d0255c3b827c`, `771233236d49`, `abe851b5cbbc`, `featureImage.altText` | Descriptive alt text | Decision 2 |
| `author`, `updatedDate` | `author-jessica-gertig`, `2026-08-06` | Overview K23 |

### `interview-feedback-examples`

| Block | Change | Authority |
|---|---|---|
| `5b715b852846` | 36% -> 20%, 24% -> over 50%, NPS wording, dead Talent Board PDF -> live ERE write-up, year named | Overview K23 "2026 data", decision 1 |
| `f32d26a09fd0` | "a LinkedIn survey" -> "a LinkedIn survey from 2015" | Decision 1, year on the sentence. The referrals claim itself is held under decision 6 because image `d7ef9507c4ee` carries it |
| `0721197a0496` | Restored to the LinkedIn source's own wording, dated 2015 | Same source and same claim as published; the refresh's Survale substitution was retired in the fix pass |
| `f41fbdd7cfee`, `5852e2591824`, `0b71061d61c5.sourceUrl` | `careers.google.com/how-we-hire/` -> its 301 destination | Link repair, no reader-visible text change |
| `d7ef9507c4ee`, `0b71061d61c5`, `featureImage.altText` | Descriptive alt text | Decision 2 |
| Answer-first blocks | **Not done**, and left not done | Decision 8, the post ranks pos 5-29 |
| The eight "Instead of saying / Say" pairs | Untouched | Nothing dated in them |
| `author`, `updatedDate` | `author-corey-daniels`, `2026-08-06` | Overview K23 |

### `talent-acquisition-vs-recruitment`

| Block | Change | Authority |
|---|---|---|
| `27ad8be01c96` | $4,000 -> $5,475 in 2025, Glassdoor 403 -> SHRM press release | Overview K23, and the SHRM source Jessica supplied. The "nonexecutive" qualifier is deliberately absent, as settled |
| `5b6f5e3ecf3c` | 24 days -> 39 calendar days in 2026, SHRM 2026 brief | Overview K23. "nonexecutive" deliberately absent, same decision |
| `78a7cdd44c7c` | "Finding a hire in less than a month" -> "Filling the role that quickly" | Forced by the block above: at 39 days "less than a month" is false. Restoring it would put a false statement back |
| `4b2122701300` | "A study by LinkedIn" -> "A 2011 LinkedIn study" | Decision 1, year on the sentence. Figures and href unchanged |
| `f91031852f58`, `46956efd14e6`, `d6550fc80082`, `846d2dabb532`, `0415dbabdbac`, `15ac6ee3e2bc`, `f5609971e155` | Seven internal links, every anchor on words already in the post | Tab 13 row 5, "Refresh + **internal links**; page-1 candidate" |
| `c4ec9456d7db` | Orphaned Glassdoor markDef removed | No span referenced it, renders nothing |
| `featureImage.altText` | Descriptive alt text | Decision 2 |
| `author`, `updatedDate` | `author-corey-daniels`, `2026-08-06` | Overview K23 |

## Uncertain, quoted and left alone

### 1. `problem-solving-interview-questions` block `007def4d1446`, the template link

The href moved from `https://docs.google.com/spreadsheets/d/1n4Ek.../copy` to
`https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx`. The visible sentence, "Download
and use this template to guide your next hiring round", is unchanged.

Tab 13 row 1 for this post reads:

> "Update examples, add 2026 context + author byline + dateModified schema; keep URL"

It does not mention templates. Tab 01 row 7 reads:

> "Link from /blog + related posts; include in sitemap; refresh"

and bare "refresh" is defined on the Overview as including "downloadable templates", which is what
makes this arguable either way. Two things for Jessica: the tab 13 cell that is specific to this post
names four things and a template is not one of them, and the swap replaces a link that works today
with one that 404s until `seo-phase-8-faq` deploys, on the site's #1 traffic asset. Left as the
refresh left it.

### 2. `behavioral-interview-scoring-matrix` block `1ee1049a170a`, a changed claim

> Before: "The Monster survey linked above found that **63% of employers are willing to hire someone
> with transferable skills**, so it's not unheard of."
>
> After: "**NACE's Job Outlook 2026 survey found that 70% of employers who recruit new college
> graduates now use skills-based hiring, judging candidates on the skills they have rather than their
> degree or GPA**, so it's not unheard of."

The paragraph was carrying a stale figure, so replacing it is inside "2026 data". What the refresh
also did is change what the sentence claims: from willingness to hire on transferable skills to use
of skills-based hiring over degrees, on a different publisher and a narrower population. Decision 1
says a figure with no current equivalent goes into `QUESTIONS-FOR-JESSICA.md`; it does not say to
substitute a different claim. It is already recorded there with the shift named, and the closing "so
it's not unheard of" now rests on a figure beside the point rather than on it. Restoring 63% would
put back a figure its publisher no longer carries, which decision 1 forbids, so this is left for
Jessica rather than decided here.

### 3. `talent-acquisition-vs-recruitment` block `ccebdd18ae6e`, a narrowed subject

> Before: "Hiring a **recruitment professional** to source candidates is expensive and can cost
> **15-20%** of your new hire's salary."
>
> After: "Hiring a **headhunter** to source candidates is expensive and can cost **20-25%** of your
> new hire's first-year salary, per Indeed's June 2026 guidance."

The figure and source change is authorised; the noun change is editorial. Restoring "recruitment
professional" on its own would leave the sentence citing a page titled "What Is a Headhunter Fee",
which explicitly excludes salaried in-house recruiters, so the two halves cannot be separated
cleanly. Already recorded as item 5 in `QUESTIONS-FOR-JESSICA.md`. Left alone.

### 4. `interview-feedback-examples` block `4ceb87a4d79a`, a missing space

"interview scoring matrixtemplate" -> "interview scoring matrix template". A pre-existing rendering
bug, one character, no cell asks for it and no word changed. Restoring it would put the bug back.
Left alone.

## Published documents

Re-read after all work. None was mutated and nothing was published.

| Post | Published `_rev` | Published `_updatedAt` |
|---|---|---|
| `problem-solving-interview-questions` | `xOkZa3jk0O3ygI9ZPCD39b` | 2022-08-23T15:14:43Z |
| `behavioral-interview-scoring-matrix` | `E7eX1vrAAKHQPLJk7VWKKB` | 2023-08-08T11:56:35Z |
| `interview-feedback-examples` | `61xVu2ruomGQNeKnFgFBWq` | 2022-09-06T15:18:10Z |
| `talent-acquisition-vs-recruitment` | `L2FV4LWPPbEVlP1xCogfbs` | 2022-08-30T14:14:17Z |
