# Content refresh, `/blog/onboarding` (tab 13 row 8)

Date: 2026-08-06. Draft patched: `drafts.d83eccf5-1cec-4c18-9a29-b65c4ee1570c`, rev after patch `kJ3OpIOJnJS2LKJpQpfN0P`.
Published document `d83eccf5-1cec-4c18-9a29-b65c4ee1570c` untouched: still rev `KBFYykA9ayL6CLsqBMJIdl`, `_updatedAt` 2023-03-16, no `author`, no `updatedDate`.

Tab 13 row 8 says "Fold into onboarding-process AEO play (320 vol)". The fold-in is a separate content plan and was not touched. What was done is the refresh: dated figures, byline, `updatedDate`, alt text.

Post is 183 content blocks, published 2023-03-14. Block count is 183 before and after. Nothing was added, deleted or reordered. The existing draft was read and patched by `_key` selector, so the author assignment already on it survives.

---

## What the survey found

The whole post was read block by block, not skimmed for `%` and four-digit years. Eleven dated or datable items were found: seven statistics, one academic study, one dated cultural framing, one dated example string, one practice claim that disagreed with the article it cites. Four images were downloaded from the Sanity CDN and viewed.

---

## Figures replaced (7)

Each one is the most recent published value, found by looking for 2026 first and establishing per figure what the publisher actually has out.

### 1. BLS quits: 4.4 million / April 2022 → 3.2 million / June 2026

Block `1b771e69c4ed`, spans `868196f373c11` and `868196f373c12`.

- Old: "Around **4.4 million people** quit their job in **April 2022** alone."
- New: "Around **3.2 million people** quit their job in **June 2026** alone."
- Source: https://www.bls.gov/news.release/jolts.nr0.htm (unchanged; it is a rolling URL that always serves the newest release)

JOLTS is monthly, so 2026 data exists. `bls.gov` returns 403 to any non-browser client, so the value was taken from the BLS Public Data API, series `JTS000000000000000QUL` (quits level, total nonfarm, seasonally adjusted): June 2026 = 3,232 thousand, flagged preliminary, latest available. Cross-checked against the June 2026 release, published 2026-08-04, which states quits were 3.2 million and the quit rate 2.0%.

### 2. Gallup engagement: 51% lack engagement (2017) → 31% engaged (H1 2026)

Block `75fa6103eaef`, spans `be57f42f4b85`, `a45a1ff73ee81`, `a45a1ff73ee82`.

- Old: "According to Gallup's State of the American Workplace report, **51% of people** lack engagement at work."
- New: "According to Gallup, just **31% of U.S. employees** were engaged at work in the first half of 2026."
- Source: https://www.gallup.com/workplace/712433/employee-engagement-remains-flat-adoption-accelerates.aspx (published 2026-07-21)

Gallup states "31% of U.S. employees were engaged at work" and "Eighteen percent were actively disengaged." The polarity flips from "lack engagement" to "are engaged" because Gallup no longer publishes the not-engaged share as a headline number, and 51% by subtraction would be a figure no source states. The sentence that follows it is unchanged and still reads correctly.

The old markDef pointed at the 2017 State of the American Workplace report page. Repointed to the 2026 article, in both `75fa6103eaef` and in `a1cb43571edf`, which carries the same markDef with no span attached to it.

### 3. Gallup cost of disengagement: $483bn to $605bn → $2 trillion a year

Block `90f05974d885`.

- Old: "According to Gallup, disengaged employees cost the U.S. **$483 billion to $605 billion** each year in lost productivity."
- New: "According to Gallup, employees who are not engaged or actively disengaged cost the U.S. economy **an estimated $2 trillion a year** in lost productivity."
- Source: https://www.gallup.com/workplace/712433/employee-engagement-remains-flat-adoption-accelerates.aspx

Gallup's sentence: "Employees who are not engaged or actively disengaged cost the U.S. economy an estimated $2 trillion annually in lost workplace productivity."

This block had **no link at all** before. It now carries one, new markDef `b7c2e4f81a95`, so the figure ships with the URL of the source that states it.

### 4. Gallup job-seeking: "disengaged are 2x as likely" (2017) → 51% of U.S. employees, Q4 2025

Block `d38d1af07911`.

- Old: "According to Gallup, disengaged employees are **2x as likely** to actively seek new jobs as engaged ones."
- New: "In Q4 2025, **51% of U.S. employees** told Gallup they were either actively looking for a new job or watching for opportunities."
- Source: https://www.gallup.com/workplace/703280/worker-thriving-declines-job-market-pessimism-grows.aspx (published 2026-03-23)

The old claim traces to Gallup's "Are Your Star Employees Slipping Away?", published 2017-02-24, which says "While 37% of engaged employees are looking for jobs or watching for opportunities, higher numbers of employees who are not engaged or actively disengaged are doing the same (56% and 73%, respectively)." 73 against 37 is where the "2x" came from. **Gallup has not republished that engaged-versus-disengaged split since**, so the comparative claim has no current value. See the note in `QUESTIONS-FOR-JESSICA.md`.

What Gallup does publish currently is turnover intent as a single number: "In Q4 2025, 51% of U.S. employees said they were either actively looking for a new job (11%) or watching for opportunities (40%)." That is what the sentence now carries. The sentence's job in the article, that the first three months are a retention risk, is unchanged.

This block also had **no link** before. New markDef `a1f4c7b93d20`.

### 5. Manager-driven attrition: DDI 57% (2019) → Monster 56% (2026)

Blocks `b49585f62e57` and `26a79b621289`, spans `c599c1ce5905`, `caaa2453182e1`, `caaa2453182e2`.

- Old: "More than **57% of DDI survey respondents** said they have previously quit a job due to a bad manager."
- New: "In Monster's 2026 Workplace Relationships Report, **56% of workers** said they have left a job primarily because of a bad manager."
- Source: https://www.monster.com/career-advice/job-search/news-and-insights/office-romance-isnt-dead

The DDI figure comes from its Frontline Leader Project, announced 2019-12-10. DDI has not remeasured it; the 2025 Global Leadership Forecast covers manager trust and high-potential attrition intent, not the share who have quit over a bad manager. A 2026 measurement of the same claim does exist: Monster's 2026 Workplace Relationships Report, surveyed by Pollfish on 2026-01-04 among more than 1,000 employed U.S. workers, finds 56% have left a job primarily due to a bad manager and 55% have stayed longer than planned because of a good one.

**Caveat worth knowing: `monster.com` returns 403 to every automated client**, so the primary page could not be fetched directly. The figure was confirmed from two independent reproductions of Monster's release, Illinois Business Journal 2026-02-24 (https://www.ibjonline.com/2026/02/24/bad-managers-drive-turnover-56-percent-say-they-left-primarily-because-of-one/) and Quality Digest 2026-03-17 (https://www.qualitydigest.com/inside/people-management-news/bad-managers-drive-turnover-56-say-thats-why-they-left-031726.html), and by a search engine reading Monster's own page. A human browser gets a 200 on the Monster URL. This is in `QUESTIONS-FOR-JESSICA.md` in case you would rather the link point somewhere fetchable.

The preceding sentence, "Research shows that people tend to quit poor-fitting managers more so than poor-fitting jobs", was left as it is; the dated source immediately after it now carries a 2026 date.

### 6. LinkedIn learning and retention: 94% (2018) → 2025 Workplace Learning Report

Blocks `8659140c0a46` and `cdf6a39ece7d`, spans `4f087490aecb`, `ba7dfdfa61a81`, `ba7dfdfa61a82`.

- Old: "A Workplace Learning report by **LinkedIn found that 94%** of employees stay at a company longer if it helps them learn."
- New: "In **LinkedIn's 2025 Workplace Learning Report**, 88% of organizations said they are concerned about employee retention, and providing learning opportunities was their number one retention strategy."
- Source: https://business.linkedin.com/learn/resources/workplace-learning-report

The 94% is from the 2018 edition. **The current edition no longer carries it.** The 2025 report is the newest LinkedIn has published; there is no 2026 edition. Its retention statement is "88% of organizations are concerned about employee retention. Providing learning opportunities is survey respondents' No. 1 retention strategy." Same publisher, same annual series, newest edition, and the sentence still makes the same argument.

The markDef also moved off `learning.linkedin.com`, which 301s, onto `business.linkedin.com`, which is the live destination.

### 7. Gallup onboarding 12%: figure stands, dead URL replaced

Block `1b771e69c4ed`, markDef `b0d7a75cbee0`. Same markDef also sits unattached on block `694657a0c857`; both were repointed.

- Figure: **12%**, unchanged. It is still Gallup's current published value.
- Old URL: `https://www.gallup.com/workplace/247172/problems-onboarding-program.aspx` which **301s to `https://www.gallup.com/workplace/insights.aspx`**, a generic hub. The article is gone.
- New URL: https://www.gallup.com/workplace/235121/why-onboarding-experience-key-retention.aspx which states "Only 12% of employees strongly agree that their organization does a great job onboarding new employees."

This is the one figure where the search for a 2026 value returned the same number. Gallup still publishes 12%.

---

## Not a figure, but dated (3)

### 8. The "Great Resignation" framing, removed

Block `0e09643e9479`, span `4106c9014933`.

- Old: "In the age of the "Great Resignation," it's crucial that employers create an effective onboarding program."
- New: "It's crucial that employers create an effective onboarding program."

This sentence is the third of three in the lead and depends on the two figures above it. Once the quits figure became June 2026, the paragraph read as though 3.2 million quits in 2026 were evidence of a 2021 to 2022 phenomenon. The clause is a deletion, not a rewrite, and no new prose replaced it. Flagging it plainly because it is the only sentence in the post whose meaning changed without a figure changing.

### 9. Warwick study: year now stated

Block `bea6199dd9d0`, span `e50f6a4d68b2`.

- Old: "A University of Warwick study found employees are 12% more productive..."
- New: "A **2015** University of Warwick study found employees are 12% more productive..."
- Source: https://warwick.ac.uk/news/pressreleases/new_study_shows/ (was `warwick.ac.uk/newsandevents/pressreleases/new_study_shows/`, which 301s here)

The 12% stands. It is a one-off academic paper, "Happiness and Productivity" by Oswald, Proto and Sgroi, Journal of Labor Economics, four experiments with over 700 participants. It is not a recurring series, so there is no 2026 edition to find and no newer value to take. Dating it in the sentence is what stops it reading as current research. The markDef was repointed past the redirect in both blocks that carry it.

### 10. Slack: the practice and the dated example

Block `fe4bf7602ec9`, span `3c416e9448972`.

- Old: "**A week** before the new hire's start date, they invite them to a channel specifically created for new hires to meet (e.g., **#2022-new-hires**)."
- New: "**Two weeks** before the new hire's start date, they invite them to a channel specifically created for new hires to meet (e.g., **#new-hires-08-20-26**)."
- Source: https://slack.com/blog/productivity/how-to-gently-onboard-new-hires-using-slack (live, 200, last published 2025-09-30)

Two corrections in one span. The cited Slack article says new hires get access to the workspace **two weeks** before their start date, not one, so the post was misreporting the source it links to. And Slack's own example channel is `#new-hires-08-20-18`, a cohort start date, not a year label. The example now follows Slack's real naming convention with a 2026 date rather than inventing a format.

---

## Images: all four viewed (rule 5)

Downloaded from `cdn.sanity.io` and looked at. Two were purely decorative or structural, one is a photograph, one carries a figure.

### Feature image, asset `86dba43b32615f76f2df8fe4b937e1fe1bb182c3-3600x1890-png`

Shows: three white circles on a solid black field, growing left to right, outlines going from finely dotted to dashed to solid. No text, no numbers, no dates.

- Old `altText`: "Employee Onboarding Header Image"
- New `altText`: "Abstract header graphic: three white circles on a black background, each larger than the last from left to right, with outlines that shift from finely dotted to dashed to solid."

### Block `a064aafb19bf`, Salesforce welcome package, asset `1d078cc77a0a86abfc0c381d84ab33e52fc4653c-800x600-png`

Shows: an overhead flat-lay on a wood desk. Open white gift box with a blue looping-line logo, matching round stickers, a round Salesforce lightbulb sticker, three paperbacks including one titled "Manage Your Day-to-Day: Build Your Routine, Find Your Focus and Sharpen Your Creative Mind", a folded navy T-shirt with the same logo, a printed welcome card reading "WELCOME Brandon", a gift card marked **$200** for headphones, a Nerf N-Strike Jolt blaster, a black pen, a small burlap drawstring bag of enamel pin badges, a bar of Recchiuti Almond chocolate, and the name "Brandon" cut out in blue lettering. A blue-lit office lobby is visible below.

- Old `alt`: "Image of personalized welcome package new employees receive at Salesforce"
- New `alt`: the contents, named. Full string is in the draft.

The only figure the graphic carries is the **$200** on the gift card. It is not asserted anywhere in the prose, so there is nothing to hold and nothing that could contradict.

### Block `f2fa3058baf2`, the 30-60-90 plan, asset `cd50ae4b036da6ab132f243099df88ad6e9cff19-1999x1452-png`

Shows: a diagram titled "The 30-60-90 day plan", three stacked rounded boxes joined by downward arrows. "1-30 days: Learn the company's mission, team structure, and role expectations." "31-60 days: Put what you've learned into action by ramping up your workload." "61-90 days: Contribute to the team and start mastering the skills of the role."

- Old `alt`: "the 30-60-90 onboarding day plan"
- New `alt`: the title and all three rows written out, so the diagram's content survives for a reader who cannot see it.

**No dated figure.** 30, 60 and 90 are the article's own structure, not data. Nothing held.

### Block `e4d6d7566d1b`, the Gallup statistic card, asset `0645d146932de4ba2983de848f49a8577e775142-1999x1031-png`

Shows: a horizontal bar filled about one fifth of the way with a small triangular marker at the fill point, the caption "21% of employees strongly agree their performance is managed in a way that motivates them to do oustanding work." and "Source: Gallup" bottom right. **The word "outstanding" is misspelled "oustanding" in the graphic.**

- Old `alt`: "Gallup survey result shows that 21% of employees strongly agree their performance is managed in a way that motivates them to do outstanding work"
- New `alt`: adds the chart form (the bar and the marker) so an answer engine gets both the figure and what it is looking at. The alt does not reproduce the typo.

**The 21% appears nowhere in the prose**, so no prose figure is held behind this image and every dated figure in the post was still replaced. The graphic itself is stale and is recorded under "Images that need regenerating": Gallup currently states "Only 2 in 10 employees say their performance is managed in a way that motivates them to do outstanding work", https://www.gallup.com/workplace/215927/performance-management.aspx

The block's `sourceUrl` was deliberately **left** on the 2017 report, `https://www.gallup.com/workplace/238085/state-american-workplace-report-2017.aspx`. That is the source that actually states 21%. Pointing it at the 2026 page would make the graphic cite a source carrying a different number.

---

## Byline and updated date (rule 7)

- `author` was already `author-jessica-gertig` on the draft. **Not changed.** The patch was `_key`-selective, so it survived intact.
- `updatedDate` set to `2026-08-06`. The field did not exist on this document before. Schema type is `date` (`studio/schemas/blogPost.js` line 83), so the value is a plain date string.

---

## Deliberately not done

- **No restructuring.** No heading added, moved, merged or reworded. Tab 13 row 8 does not ask for answer-first treatment on this post anyway, and rule 8 rules it out for anything currently ranking.
- **The fold into the onboarding-process AEO play** belongs to a separate content plan.
- **The three `wrk.xyz` links were left alone**: `https://www.wrk.xyz/blog/utc-is-the-timezone-of-the-future` on blocks `7c7f9296c02f` and `d66e2df02099`, `https://www.wrk.xyz/blog/five-things-a-startup-should-keep-in-mind-when-hiring` on `fbd06a303851` and `179c433c7123`, and `https://hire.wrk.xyz/register` on `f0bcd2cbb1ff` and `12f4dff799a9`. All three resolve, all three cost a redirect hop, and all three are tab 16 row 9 material that Phase 3 item 3 explicitly did not action. Question 5 under "Phase 6, item 3" in `QUESTIONS-FOR-JESSICA.md` already covers them.
- **`https://www.notion.so/` 301s to `https://www.notion.com/`.** Same category: a live link costing a hop, tab 16, not this item.
- **"Hybrid and remote work is the new normal for many companies. Others have returned to the office..."** on block `1d64c64f1e49` was read and left. It carries no figure and no date, and it describes both sides of the return-to-office split, so it has not gone stale.
- **`pageTitle`, `editorialTitle` and `metaDescription` untouched.** Tabs 07 and 12 own those.

---

## Re-survey after the work

The patched draft was refetched from Sanity and swept again for four-digit years, percentages, currency, multipliers, vague recency markers ("a recent study", "last year", "research shows"), and every named organisation. Everything dated that remains now states the year it belongs to:

| Where | Reads |
|---|---|
| `1b771e69c4ed` | 3.2 million, June 2026 |
| `1b771e69c4ed` | Gallup 12%, current |
| `75fa6103eaef` | 31%, first half of 2026 |
| `bea6199dd9d0` | 12%, 2015 study, dated in the sentence |
| `26a79b621289` | 56%, Monster 2026 report |
| `cdf6a39ece7d` | 88%, LinkedIn 2025 report |
| `d38d1af07911` | 51%, Q4 2025 |
| `90f05974d885` | $2 trillion a year, Gallup 2026 |
| image `e4d6d7566d1b` | 21%, 2017, held in pixels and recorded |

No multiplier claims remain. No undated study remains. No em-dash was written anywhere; the patch script aborts if one appears in the payload.

---

## Mechanics

Throwaway scripts in the session scratchpad, nothing written into the repo. Patch was a single `client.patch(id).set({...}).commit()` against `drafts.d83eccf5-1cec-4c18-9a29-b65c4ee1570c` with 33 `set` paths, all of them `_key` selectors into `content`, plus `updatedDate` and `featureImage.altText`. No `createOrReplace`, no publish, no write to any id without the `drafts.` prefix.

---

# Fix pass, 2026-08-07

Input: the seven `onboarding` findings in `refresh-findings.json` (1 MED, 6 LOW), plus a full re-read of the patched draft. Draft `drafts.d83eccf5-1cec-4c18-9a29-b65c4ee1570c` only; published document never touched, nothing published, every write a `set` on a `_key` path guarded by `ifRevisionId`.

Revision chain: `kJ3OpIOJnJS2LKJpQpfN0P` → `QzNVnRn1RN9Wy2ys8QuGuN` (four content fixes) → `QzNVnRn1RN9Wy2ys8QuIV5` (six `wrk.xyz` hrefs, later reverted) → `guLb7mLdCgNrjUoWfCFrL3` (two orphaned `markDef` copies) → `guLb7mLdCgNrjUoWfCG3zj` (the `wrk.xyz` revert). Final state is rev `guLb7mLdCgNrjUoWfCG3zj`.

## Finding 1 (MED), the one-week / two-week contradiction: fixed

Both blocks read, and the source read before deciding which one moves.

- Block `3e1c140a5ab5`: "Finally, a week before your new hire is due to start, send them:" followed by bullet `5bd44f7e8708`, "An invite to join any company community channels such as Slack".
- Block `fe4bf7602ec9`: "Slack has seen great results with the latter tactic. Two weeks before the new hire's start date, they invite them to a channel ...".

The source, https://slack.com/blog/productivity/how-to-gently-onboard-new-hires-using-slack , states: "When people accept a job offer at Slack, they get early access (two weeks before their start date) to a special Slack workspace created just for new hires." Two weeks is what the source supports, so the sourced sentence keeps its figure.

Block `3e1c140a5ab5` is not sourced. It is the post's own recommendation, and rewriting a recommendation is not a figure correction, so it was left alone and the exemplar was made to acknowledge the difference instead. Block `fe4bf7602ec9` now reads:

> Slack has seen great results with the latter tactic, and starts earlier still: two weeks before the new hire's start date, they invite them to a channel specifically created for new hires to meet (e.g., #new-hires-08-20-18). Then, share tons of information to help ease them into the role.

The word "latter" still points back at the Slack bullet and no longer contradicts it. Whether the post's own advice should move from one week to two is a one-word patch on `3e1c140a5ab5` and is recorded for Jessica, not made.

## Finding 2 (LOW), the invented channel-name year: fixed

Slack's article prints `#new-hires-08-20-18`. The refresh shipped `#new-hires-08-20-26`, the source's format with the year digits changed. Restored to `#new-hires-08-20-18` in the same `set` as above. `QUESTIONS-FOR-JESSICA.md` item 5 asserted `#new-hires-08-20-26` as the corrected value; that entry is corrected in place.

## Finding 3 (LOW), Warwick's page does not state 2015: fixed by moving the citation

`https://warwick.ac.uk/news/pressreleases/new_study_shows/` fetched and read in full. It states "In the laboratory, they found happiness made people around 12% more productive" and dates nothing: the paper is "to be published in the Journal of Labor Economics" and the only date on the page is the footer "Last revised: Wed 16 Nov 2022". The sentence claims 2015.

The paper's own page was fetched: https://www.journals.uchicago.edu/doi/10.1086/681096 returns 200 and states, on one page, "Journal of Labor Economics, Volume 33, Number 4, October 2015", "Published online August 07, 2015", the author affiliations "University of Warwick and IZA" and "University of Warwick", and in the abstract "The treated individuals have approximately 12% greater productivity." Every element of the sentence, year included, is on that page, so the prose did not change and only `markDefs[_key=="90be12452153"].href` moved. The trade is a journal abstract instead of a press release for the reader; recorded for Jessica.

## Finding 4 (LOW), the questions file misquotes the shipped Gallup sentence: file corrected

Block `d38d1af07911` in Sanity reads "The first three months are a critical time for retaining new hires. In Q4 2025, 51% of U.S. employees told Gallup they were either actively looking for a new job or watching for opportunities." No parentheticals. `QUESTIONS-FOR-JESSICA.md` item 2 quoted it with "(11%)" and "(40%)".

The post is accurate as it stands and Gallup does print the split ("51% of U.S. employees said they were either actively looking for a new job (11%) or watching for opportunities (40%)", https://www.gallup.com/workplace/703280/worker-thriving-declines-job-market-pessimism-grows.aspx , published 23 March 2026), so the defect is in the file, not the draft. The quote in item 2 was corrected to what is in Sanity and the option of adding the split to the sentence was recorded rather than taken.

## Finding 5 (LOW), the "(20%)" conversion in the held-figure entry: already corrected, nothing further done

Grepped the whole build directory for `(20%)`: no hit. The wording the finding quotes does not exist in `QUESTIONS-FOR-JESSICA.md`. What is there is the hedged form at the long entry, "So 21% becomes 2 in 10, or 20% if you want it as a percentage", the table row that already says "Gallup's page does not print a percentage; '20%' would be a conversion, not a quote", and item 4 of "Corrections from verification to entries already in this file", which states the point the finding makes. The file's own convention for that section is that corrections are appended rather than edited in place, so nothing was rewritten.

## Finding 6 (LOW), the alt text reverses the card's layout: fixed

Asset `0645d146932de4ba2983de848f49a8577e775142-1999x1031-png` downloaded from the CDN and viewed. The caption occupies the top of the white card; below it sits the horizontal bar, filled about one fifth of the way, with a small black triangular marker above the fill point, and "Source: Gallup" bottom right. The alt said the bar was "above the caption". It now reads:

> Gallup statistic card: the caption "21% of employees strongly agree their performance is managed in a way that motivates them to do outstanding work.", and below it a horizontal bar filled about one fifth of the way with a small triangular marker above the fill point.

The graphic's own typo ("oustanding") is still not reproduced in the alt, and `sourceUrl` still points at the 2017 report, both as the earlier pass decided.

## Finding 7 (LOW), the Monster 403: the finding is right about the block, and the reason recorded in the questions file was false

`QUESTIONS-FOR-JESSICA.md` item 1 said of `https://www.monster.com/career-advice/job-search/news-and-insights/office-romance-isnt-dead` : "A human browser gets a 200 on that URL." Loaded in a real browser through Playwright, that URL returns **403**. The article has moved to `https://www.monster.com/career-advice/research/office-romance-isnt-dead` , which is the page's own `<link rel="canonical">`, loads at 200 in the browser, is headed "Office Romance Isn't Dead: How Connection, Trust, and Managers Shape Work in 2026", dated "Updated: Jul 1, 2026", and states in Monster's own words:

> Bad management drives exits: 56% have left a job primarily due to a bad manager

and later "56% have left a job primarily because of a bad manager". The block's sentence is therefore now confirmed against Monster directly rather than only against the Illinois Business Journal and Quality Digest reproductions, and `markDefs[_key=="e1a5906265d2"].href` was repointed to the canonical URL.

What the finding is right about and what no patch can fix: `curl` with a full desktop Chrome header set returns 403 on **both** paths, so answer engines still cannot read the citation. That half is Jessica's, and item 1 already offers her the swap.

## Not named by any finding, found in the re-read

Every remaining figure was re-verified at its own cited URL.

| Block | Claim | Verified against |
|---|---|---|
| `1b771e69c4ed` | 3.2 million quits, June 2026 | `jolts.nr0.htm` loaded in the browser: "Job Openings and Labor Turnover Summary, 2026 M06 Results", "In June, the number and rate of quits were unchanged at 3.2 million". Cross-checked at the BLS public API, series `JTS000000000000000QUL`, June 2026 = 3,232 thousand |
| `1b771e69c4ed` | Gallup 12% onboarding | "Gallup finds that only 12% of employees strongly agree that their organization does a great job onboarding new employees" |
| `75fa6103eaef` | 31% engaged, first half of 2026 | "During the first half of 2026, 31% of U.S. employees were engaged at work, unchanged from 2025", published 21 July 2026 |
| `90f05974d885` | $2 trillion a year | "Employees who are not engaged or actively disengaged cost the U.S. economy an estimated $2 trillion annually in lost workplace productivity", same page |
| `cdf6a39ece7d` | LinkedIn 88%, 2025 report | "88% of organizations are concerned about employee retention. Providing learning opportunities is survey respondents' No. 1 retention strategy" |
| `d38d1af07911` | 51%, Q4 2025 | quoted above |
| image `a064aafb19bf` | `sourceUrl` academyocean | 200 |
| image `e4d6d7566d1b` | `sourceUrl` Gallup 2017 report | 200 |

Three further observations, none of them acted on:

1. **The BLS link is a rolling URL.** `jolts.nr0.htm` always serves the newest release. It states June 2026 today and will state July once that publishes, while the sentence names June. `/blog/employee-turnover`, `/blog/a-player` and `/blog/job-rejection-email` cite the same URL, so pinning it to the dated archive copy is one decision across four posts, not a fix for this one. Recorded for Jessica.
2. **The 12% onboarding figure carries no year and its source page is undated.** Every other figure in the post states its year. Gallup's page prints no date, so attaching one would mean inventing it, and dropping the figure would lose the post's opening evidence. Left exactly as it is, noted here because rule 2 is otherwise clean across the post.
3. **Six `wrk.xyz` hrefs were repointed and then reverted.** Blocks `d66e2df02099`, `179c433c7123` and `12f4dff799a9` carry `www.wrk.xyz/blog/utc-is-the-timezone-of-the-future`, `www.wrk.xyz/blog/five-things-a-startup-should-keep-in-mind-when-hiring` and `hire.wrk.xyz/register`; each `markDef` is duplicated onto the preceding block (`7c7f9296c02f`, `fbd06a303851`, `f0bcd2cbb1ff`) with no anchor span, so six paths. All three 301 with one hop to `www.polymer.co/blog/utc-is-the-timezone-of-the-future`, `www.polymer.co/blog/five-things-a-startup-should-keep-in-mind-when-hiring` and `app.polymer.co/register`, all 200. I patched them on tab 16 row 9's "opportunistic during content refreshes" guidance, then read question 5 under "Phase 6, item 3" in `QUESTIONS-FOR-JESSICA.md`, which puts that exact choice to Jessica for all eleven legacy links at once, and reverted. The draft holds its original `wrk.xyz` values.

By contrast, two orphaned `markDef` copies **were** updated, at `75fa6103eaef` (`90be12452153`, the Warwick duplicate) and `b49585f62e57` (`e1a5906265d2`, the Monster duplicate), so no stale source URL is left anywhere in the document. Those are source corrections, not the redirect-hop question.

## Files changed outside Sanity

- `QUESTIONS-FOR-JESSICA.md`: item 1 corrected (the false browser-200 claim, plus the new URL), item 2's quote corrected to the shipped sentence, item 5 corrected (channel name, and the block `3e1c140a5ab5` reconciliation with the decision left open), the section intro's count updated, a new "Fix pass, 2026-08-07, `/blog/onboarding`" subsection added, and the `monster.com` row of the consolidated unreachable index corrected.
- This log.

## Mechanics

Throwaway CJS scripts in the session scratchpad, `@sanity/client` 2.23.2 read from `web/node_modules`, token read from `web/.env.local` at run time and never written anywhere. Five `set`-only patches, all `ifRevisionId`-guarded, no `createOrReplace`, no publish, no write to any id without the `drafts.` prefix. No em-dash written; the final draft was swept for `—` across every block and image field and has none.
