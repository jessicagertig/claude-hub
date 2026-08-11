# Sanity strip sweep B

Posts: `job-rejection-email`, `agile-recruiting-process`, `onboarding`, `a-player`,
`first-impression-bias`, `best-job-board-software`.

Run 2026-08-07. Sanity drafts only. No published document was read for anything but comparison and
none was mutated. No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was touched.

## Method

Every draft was diffed against its own published document field by field. Published is the
pre-refresh baseline: all six published `_rev`s are still their 2022-2023 originals, so the diff is
exactly what this build put on each draft.

The diff covers every field the schema holds (`content`, `featureImage`, `author`, `updatedDate`,
`publishDate`, `pageTitle`, `editorialTitle`, `metaDescription`, `slug`), block order, block
membership, per-block text, `style`, `listItem`, every `markDefs` entry and every child span's marks.

## Structural result, all six posts

| Post | Blocks pub | Blocks draft | Order identical | Blocks added | Blocks removed |
|---|---|---|---|---|---|
| `job-rejection-email` | 117 | 117 | yes | 0 | 0 |
| `agile-recruiting-process` | 126 | 126 | yes | 0 | 0 |
| `onboarding` | 183 | 183 | yes | 0 | 0 |
| `a-player` | 129 | 129 | yes | 0 | 0 |
| `first-impression-bias` | 123 | 123 | yes | 0 | 0 |
| `best-job-board-software` | 141 | 141 | yes | 0 | 0 |

**No block was deleted, added or reordered on any of the six. No heading was added, removed or
changed style.** No `style` or `listItem` value differs from published anywhere. Nothing was merged.
No slug changed and no redirect exists: `a-player` is still `a-player`, and neither the tab 13 row 9
merge nor the tab 01 row 12 fold-in was acted on. Nothing was folded into an onboarding-process play.

All the change is inside existing blocks, and it is overwhelmingly figure replacement, source URL
repair, image `alt` text, `author` and `updatedDate`.

## Restored

### `onboarding`, block `fe4bf7602ec9`, span `3c416e9448972`

Draft rev in `guLb7mLdCgNrjUoWfCG3zj`, rev out `QzNVnRn1RN9Wy2ys8QymfJ`. One `set`, guarded with
`ifRevisionID`, on `content[_key=="fe4bf7602ec9"].children[_key=="3c416e9448972"].text`. Published
`d83eccf5-1cec-4c18-9a29-b65c4ee1570c` still on `KBFYykA9ayL6CLsqBMJIdl`, verified after the write.

Removed:

> Slack has seen great results with the latter tactic, **and starts earlier still: two weeks** before
> the new hire's start date, they invite them to a channel specifically created for new hires to meet
> (e.g., **#new-hires-08-20-18**). Then, share tons of information to help ease them into the role.

Put back, byte for byte from the published document, not retyped:

> Slack has seen great results with the latter tactic. **A week** before the new hire's start date,
> they invite them to a channel specifically created for new hires to meet (e.g.,
> **#2022-new-hires**). Then, share tons of information to help ease them into the role.

Why. Three edits sat in that span and no cell authorises any of them.

1. **"A week" to "two weeks"** is a source-fidelity correction: the refresh log records that the
   linked Slack article says two weeks, so the post was misreporting it. That is a 2018-to-2025
   detail about Slack's practice, not 2026 data, not a modified date, not a byline and not a
   downloadable template. Issue #13's Recommended fix names those four things and nothing else, and
   tab 13 row 8 for this post says only "Fold into onboarding-process AEO play (320 vol)", which is
   the content plan and out of scope here.
2. **"and starts earlier still:"** is authored connective prose. The fix pass added it so the word
   "latter" would still agree with the bullet above after the figure moved. It carries no figure.
3. **`#2022-new-hires` to `#new-hires-08-20-18`** cannot be a freshness update in either direction of
   travel: it replaces a 2022 string with a 2018 one. Whatever authorisation a dated example string
   has under "2026 data", a value four years older than the one it replaced does not meet it. The
   refresh first shipped `#new-hires-08-20-26` and the fix pass moved it back to the source's own
   2018 date, which is the point at which the edit stopped being a refresh.

The restored text is the published state exactly. `#2022-new-hires` still carries a 2022 year, and
updating that specific string would be a legitimate 2026-data edit if Jessica wants one; it is left
as it was rather than replaced with something invented.

## Kept, and the cell that authorises it

Nothing else was patched. Everything below traces to a cell or an approved decision.

| Post | Change | Authorising cell |
|---|---|---|
| all six | `author` reference set, `updatedDate` = `2026-08-06` | Overview issue #13 Recommended fix, "updated modified dates, author bylines"; approved decision 6 point 5, "The byline and `updatedDate` always land, on every post" |
| all six | image `alt` / `featureImage.altText` rewritten from what the graphic shows | approved decision 2 part 1 |
| `job-rejection-email` | ghosting, applications-per-interview, Virgin Media $5.4m and the detractor attribution, each with a current source URL | issue #13, "2026 data"; tab 13 row 6 "Light touch; keep rankings" is honoured: 4 prose blocks touched of 117, no restructure |
| `agile-recruiting-process` | McKinsey dated, skills-testing figure, cost-per-hire and L&D spend, "Recruitment in 2022" to 2026 | issue #13; tab 13 row 7 "Light refresh", tab 01 row 13 "Link + refresh" |
| `onboarding` | BLS quits, Gallup engagement, Gallup cost of disengagement, Gallup turnover intent, manager attrition, LinkedIn learning, Warwick study dated, Gallup onboarding URL repaired | issue #13, "2026 data"; approved decision 1, "every dated statistic ... gets replaced with a current figure AND a current source URL", and "A different publisher is acceptable if it carries the current equivalent" |
| `a-player` | NFIB qualified-applicant figures, 2025 quits total, recognition and retention, burnout, flexible work and mental health | issue #13; approved decision 1 |
| `first-impression-bias` | diversity figures dated and sourced, UK field experiment dated, `http` to `https` on the Oxford PDF | issue #13; approved decision 4, dated data is found by surveying the post |
| `first-impression-bias` | internal links added to `/blog/problem-solving-interview-questions` and `/blog/behavioral-interview-scoring-matrix` on unchanged sentence text | tab 01 row 15, "Strengthen internal links" |
| `first-impression-bias` | `metaDescription` replaced | tab 12 row 14, verbatim the "Suggested rewrite (<=155)" cell |
| `best-job-board-software` | Polymer per-job pricing replaced with the three 2026 plans, and "no user limit" replaced with the 5/20/50 user tiers | tab 01 row 16 "refresh" + issue #13; per the sweep brief, both corrections are 2026 data |
| `best-job-board-software` | Niceboard, BambooHR, Notion, Google Workspace, Sheet2Site, Webflow, Bluehost prices and plan names | issue #13, "2026 data" |
| `best-job-board-software` | `join.hel.io` "live example" repointed to `jobs.polymer.co/motive`; `wrk.xyz` blog link repointed to `polymer.co`; `wpjobmanager.com` repointed to `wpjobboard.net` under a "WPJobBoard" anchor; Webflow gallery link repointed | dead and misdirected external links, Overview issue #14 |

Two things checked and found honoured rather than needing a strip:

- **`a-player` was not merged, redirected or folded.** Tab 13 row 9's "Merge candidates: could
  redirect into a broader hiring guide" and tab 01 row 12's "fold into hiring-ops cluster" were both
  declined. Slug unchanged, no redirect, no internal link added or removed.
- **`onboarding` was not folded into the onboarding-process AEO play.** Tab 13 row 8's instruction is
  untouched.

## Uncertain: quoted, left alone

Each of these has a cell that plausibly reaches it and an execution that goes past the cell. None was
patched, because over-removal is worse than a flagged uncertainty and because restoring any of them
would either put back visibly broken text or leave a stump that is neither the published version nor
the draft. Each is a one-line `set` for Jessica if she wants it gone.

### 1. `a-player`, block `acfe9c031572`, the Pallet sentence

Published:

> ... candidate curation sites like **Pallet**, Lean Hire, and Dice. For example, Pallet groups job
> seekers by characteristics into "Collectives."

Draft:

> ... candidate curation sites like Lean Hire and Dice. The screenshot below is from **Pallet**, which
> grouped job seekers by characteristics into "Collectives". **The Collectives are gone from
> pallet.com, which now sells supply chain software.**

`refresh-a-player.md` names this itself: "LOW. The Pallet sentence is the one place this run authored
prose."

The cell that reaches it is approved decision 4, which puts in the survey's scope things a skim
misses, including "**practices that have since changed**". Pallet's Collectives are gone and
`pallet.com/spotlight` is a 404, so the present-tense recommendation was stale and taking it out of
the list of sites to use today is the authorised half.

The final sentence is not. It is a new sentence about a vendor's pivot, written by the agent, and it
reads as an editor's footnote inside body copy. Cutting only that sentence leaves "The screenshot
below is from Pallet, which grouped job seekers by characteristics into 'Collectives'." linking to a
logistics company with no explanation, which is a third state neither version had. Left whole for
Jessica to take or leave in one look.

Same block: the `bece01d548d1` href moved from `pallet.com/spotlight` (404) to `pallet.com` (200),
and the image below it (`f215f572ad7b`) gained `source` = "Pallet Spotlight, archived July 2022" with
`sourceUrl` moved to the Internet Archive capture. `web/pages/blog/[slug].js` renders `source` as a
visible figcaption, so that is a new visible credit line where a bare URL used to print.

### 2. `onboarding`, block `0e09643e9479`, the "Great Resignation" clause

Published: "**In the age of the "Great Resignation,"** it's crucial that employers create an
effective onboarding program."
Draft: "It's crucial that employers create an effective onboarding program."

A clause was deleted and nothing replaced it. `refresh-onboarding.md` flags it plainly: "the only
sentence in the post whose meaning changed without a figure changing". The reason given is that the
quits figure two sentences above moved to June 2026, so the paragraph was offering 2026 evidence for
a 2021-22 phenomenon.

Approved decision 4 covers dated framing, so the clause was fair game for the survey. Whether "2026
data" authorises deleting it rather than updating it is the open half. Restoring it puts back a claim
that is no longer true.

### 3. `best-job-board-software`, block `d8efb56c7dcd`, the duplicated paragraph

The published Polymer intro contains its own body twice, the second copy starting mid-sentence with a
lowercase "is". The draft deleted the duplicate.

No cell authorises it: it is not 2026 data, not a modified date, not a byline, not a downloadable
template. It is a defect repair. Restoring it would put visibly broken text back on the page, which
is why it is flagged rather than reverted.

### 4. `best-job-board-software`, block `988ec8bbf59f`, two em-dashes removed

"hiring in **2022** is fast, organized, efficient**—and most importantly—**it connects" became
"hiring in **2026** is fast, organized and efficient**, and most importantly** it connects".

The year is authorised. The punctuation rewrite is not, and it breaks this build's own standard:
`refresh-job-rejection-email.md` and `refresh-a-player.md` both record leaving pre-existing em-dashes
alone because "the brief was to change nothing beyond dated figures". This post's agent stripped them
because the block was open anyway. Left because restoring would mean writing em-dashes back into
Sanity, and this sweep's brief forbids em-dashes.

### 5. `best-job-board-software`, block `3e3547e60e6a`, the Webflow bullet

Published: "Manage your team under one roof. **Webflow uses artificial intelligence (AI) to help you
manage and organize your workforce from anywhere.**"
Draft: "... **Webflow Workspaces let your whole hiring team build and edit the job board together,
with AI features built into the platform for generating and refining the site itself.**"

A full sentence rewrite. The log's reason is that Webflow has never sold workforce management, so the
claim "was never true" rather than having gone stale. "Never true" is not "2026 data" and not
"practices that have since changed", so the cell does not obviously reach it, but the replacement is
a correction rather than an addition. Flagged, not patched.

### 6. Invisible markDef edits, no rendered effect either way

Recorded so they are not silent. Every one of these is a `markDefs` entry that no span in its block
references, so it renders nothing before or after.

| Post | Block | What happened |
|---|---|---|
| `onboarding` | `b49585f62e57` | orphan `e1a5906265d2` repointed from the DDI press release to a Monster URL that has no relation to that block's text |
| `onboarding` | `694657a0c857`, `a1cb43571edf`, `75fa6103eaef` | orphan copies repointed alongside their live twins |
| `best-job-board-software` | `030b27beb6cf`, `50c3ff6196a1` | orphan `2e75c91d2f97` and `f3300400f68f` deleted outright |
| `first-impression-bias` | `b778cd1a9935` | image `source` changed from "Source: NFP People" to "NFP People", which stops the renderer printing "Source: Source: NFP People" |

The orphan deletions on `best-job-board-software` are the only case where content was removed rather
than repointed. `refresh-a-player.md` took the opposite decision on seven identical orphans and left
them, so the two posts now differ in policy. Neither renders.

## Published documents

Read for comparison, never written. Confirmed unchanged after the one patch:

| Post | Published `_id` | `_rev` |
|---|---|---|
| `job-rejection-email` | `35e36b52-728b-4eb1-b7d9-ed2003c4d1a5` | `l0bLyT137Vusgfcue9ZUuu` |
| `agile-recruiting-process` | `bc1fe908-c69f-4919-89f9-9edcc1222507` | `1GPeuoR4D0aUdfgdz93zDL` |
| `onboarding` | `d83eccf5-1cec-4c18-9a29-b65c4ee1570c` | `KBFYykA9ayL6CLsqBMJIdl` |
| `a-player` | `934c12d9-28de-4645-8cd7-3b6a504531d5` | `i7ljIeEeav1WO3JfFunmjG` |
| `first-impression-bias` | `a239b0d1-bad6-459f-98d1-b809d5a82dc7` | `GmE6MVIyfn5LRPNvzPtzDq` |
| `best-job-board-software` | `8e15bac9-7d65-4e3f-8b83-6d89b41fbdbf` | `gyPW55F7BVpjd55gdcAhPt` |

## Mechanics

Throwaway `.cjs` scripts in the session scratchpad, `@sanity/client` 2.23.2 read from
`web/node_modules`, token read from `web/.env.local` at run time and written nowhere. One `set`-only
patch, `ifRevisionID`-guarded, on a `drafts.` id. No `createOrReplace`, no publish, no array rewrite,
no write to any id without the `drafts.` prefix. The restored string was copied out of the published
document rather than retyped, and the patch script refuses to run if an em-dash appears in the
payload.
