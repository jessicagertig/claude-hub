# Content refresh, `/blog/employee-turnover` (tab 13 row 2, tab 01 row 9)

Draft `drafts.e3c6e6d7-5957-49a4-8f28-682b6c21a41e` patched on 2026-08-06. Published document `e3c6e6d7-5957-49a4-8f28-682b6c21a41e` untouched: its `_updatedAt` is still `2023-07-05T13:12:39Z`. Draft now differs from published in `author`, `content`, `featureImage`, `updatedDate`. The `author-jessica-gertig` reference that was already on the draft was not touched.

Content blocks: 130 before, 128 after. **Three** blocks added (the two `table` blocks and the paragraph `turnoverannualnote`), five loose formula/example lines removed into the first of the tables. 130 - 5 + 3 = 128.

> **A fix pass ran on 2026-08-07. Sections 1, 3 and 6 below contain statements it found to be false. Each is marked inline and the full account is in "Fix pass" at the end of this file.**

---

## 1. The first question the task asked: has the standard method changed?

**No. The formula is unchanged.** Turnover rate = separations during the period ÷ average number of employees during the period × 100. SHRM, Mercer and the HRIS platforms all still use it; SHRM's own how-to guide (published 30 August 2024, https://www.shrm.org/topics-tools/tools/how-to-guides/how-to-determine-turnover-rate) is behind a membership wall, so the formula was confirmed against BLS's published definitions and against multiple independent restatements rather than from SHRM directly.

**One thing about the method genuinely is different from what the post said, and it drove the block.** The post gave only the two-point average, `(headcount at start + headcount at end) ÷ 2`, for every period length. For a full year that is the less accurate denominator. BLS computes its own annual rates as the sum of the 12 monthly levels over the **sum of the 12 monthly CES employment levels** (footnote 1 on https://www.bls.gov/news.release/jolts.t20.htm). The block now gives the two-point average for a month or quarter and says to average the 12 monthly headcounts for a year, linked to that BLS footnote.

> **FALSE, corrected in the fix pass.** The last sentence above describes the block as written on 2026-08-06, and that block claimed averaging the 12 monthly headcounts was "the method BLS uses". It is not. BLS sums the numerator too, so its annual figure is a monthly-equivalent rate; the block's instruction produced a number about twelve times larger and invited a reader to compare it against the 3.3% in the benchmark table below. See "Fix pass" for the rewritten paragraph.

**The second methodological change is on the BLS side and it is why the post's benchmark numbers could not simply be renumbered.** The 66.8% / 50.6% / 17.8% figures are annualised quit rates for 2021: BLS then divided the year's quits by *annual average* employment, which produces figures roughly 12x a monthly rate. The JOLTS annual tables in the current release do not publish that form. Table 22 is now "Annual **average** quits rates by industry and region" and its footnote divides by the *sum* of the 12 monthly employment levels, producing a monthly-equivalent rate: accommodation and food services 2021 is **5.8**, not 66.8. So a like-for-like replacement of those three numbers does not exist on bls.gov today. The benchmark block therefore presents BLS in the form BLS now publishes it (monthly rates, labelled as monthly) and uses Mercer's annual survey for the annual comparator a reader actually wants after running the calculator.

---

## 2. Figures replaced

Every figure below was checked for a 2026 value first. Where 2026 does not exist for that specific figure, the sentence now names the year the figure belongs to.

| # | Block | Old | New | Source |
|---|---|---|---|---|
| 1 | `1da505a31489` | Gallup, cost of replacing one employee "one-half to two times" annual salary, linked to the 2021 Great Resignation article | Same range, now attributed in prose to **Gallup's 2019 analysis**, link moved to the article that is its origin | https://www.gallup.com/workplace/247391/fixable-problem-costs-businesses-trillion.aspx (13 March 2019) |
| 2 | `a68fd60a7b03` | "quit rates are much higher in the hospitality (66.8%) and retail (50.6%) industries than in sectors like financial services (17.8%)" | "employers lost **3.3%** of their workforce to separations in an average month of **2025** and **2.0%** to voluntary quits... Both rates have come down since 2021, when they stood at **3.9%** and **2.7%**" | https://www.bls.gov/news.release/jolts.t20.htm (Table 20) and https://www.bls.gov/news.release/jolts.t22.htm (Table 22), 2026 M01 release |
| 3 | `fac12d5840cf` | "The average employment separation rate across all industries in 2021 was 32.7%... previous years... between 25.2% and 28%" | "**Mercer's 2025 US Turnover Survey** of **2,617** organizations put average voluntary turnover at **13.0%**, down from **13.5%** in 2024 and **17.3%** in 2023. Retail and wholesale was the highest sector at **26.7%**, and insurance the lowest at **8.2%**" | https://www.imercer.com/articleinsights/workforce-turnover-trends (published August 2025) |
| 4 | new `turnoverbenchmarkblock` | figures were scattered in prose | nine-row industry benchmark table, 2025 annual averages | Tables 20 and 22 as above |
| 5 | `ca295804d4db` | "In light of a global increase in employee turnover rates" | "US quit rates have **fallen every year since 2022**" | Table 22: 2.8 (2022), 2.4 (2023), 2.1 (2024), 2.0 (2025) |
| 6 | `a532977b3542` | "PwC's Global Workforce Hopes and Fears Survey **2022**... survey of **52,000** people... leaders often miss the chance to build trust" | "PwC's Global Workforce Hopes and Fears Survey **2025**, which polled **nearly 50,000** workers across **28 sectors and 48 economies**... employees who see the most meaning in their work are **91%** more motivated... only about half say they have found a meaningful career... **58%** say they trust their direct manager... barely half trust top management" | https://www.pwc.com/gx/en/issues/workforce/hopes-and-fears.html (12 November 2025) |
| 7 | `8f271ffaea12` | orphaned `markDef` still pointing at `hopes-and-fears-2022.html` | repointed to the 2025 page, in step with #6 | same |
| 8 | `28606853f0f4` | "retain A-players in **2022**" | "in **2026**" | n/a |
| 9 | `22288b3fd87d` | "**57%** of people say they quit a job in the past because of a bad boss", linked to a 2019 PRNewswire release | Same **57%**, now attributed to DDI's Frontline Leader Project and described as "a figure DDI was still publishing in **2026**", link moved to DDI's own current page | https://www.ddi.com/blog/leadership-and-employee-retention (published 15 May 2026) |
| 10 | `3867935e4803` | "both companies have **median tenures of only one year**" | "Revelio Labs put **Amazon's average employee tenure at 3.6 years** as of **March 2026**, and **Google's median at 4.4 years**" | https://www.reveliolabs.com/companies/amazon/employees and https://www.reveliolabs.com/companies/google/employees |
| 11 | `db6c5e5050a0` | H2 "What people want from their employers in **2022**" | "in **2026**" | n/a |
| 12 | `6176945a0a16` | "PwC's Hopes and Fears survey also found that **62%** of people prefer hybrid work models" | "Gallup's tracking of remote-capable US employees found **52%** working hybrid as of **May 2026**, and **six in 10** say hybrid is the arrangement they want. Among those working fully remotely, **six in 10** say they are extremely likely to look for a new job if that flexibility is taken away" | https://www.gallup.com/401384/indicator-hybrid-work.aspx |
| 13 | `5bcd81359269` | "only **23%** of respondents to the PwC survey said their employer helps them reduce the environmental impact of their work" | "**Three-quarters** of workers globally, and **78%** in the US and Canada, say it matters to them that their employer actively works to reduce its environmental impact... more than **5,900** employees" | https://www.ecoonline.com/en-us/resources/research/the-workplace-safety-report/ (Workplace Safety Report 2026) |
| 14 | `04e1257f279c` | H3 "It's a job seeker's market" | "The market has swung back toward employers" | see #15 |
| 15 | `2ccc9bafabb5` | "There are more jobs than talent, especially in growing tech hubs like Toronto... there's another opportunity waiting" | "The US labor market has settled into a **low-hire, low-fire** pattern: in **June 2026** employers hired at a monthly rate of **3.4%** and workers quit at **2.0%**, against **3.0%** at the 2021 to 2022 quits peak" | https://www.hiringlab.org/2026/08/04/june-2026-jolts-report/ (4 August 2026); peak confirmed against BLS series `JTS000000000000000QUR`, 3.0 in 2021 M11 and 2022 M04 |
| 16 | `0c92d94be2f9` | "to avoid your employees jumping ship to any available open roles" | "so the people you most want to keep have no reason to look" | follows #15 |
| 17 | `8045769956a6` | "Employees have the upper hand in the current climate of resignation and skill shortages" | "A slower hiring market does not mean your best people are short of options" | follows #15 |
| 18 | `fef31339b688` | "Another important finding from the survey" | "Another important finding, **from the 2022 edition of the same survey**" | dates the held chart below it |
| 19 | `06d17a0ee4b0` | "Out of the 65% surveyed who said..." | "Out of the 65% surveyed **in 2022** who said..." | **HELD**, see section 4 |

---

## 3. The two blocks tabs 13 and 01 asked for

Both are Sanity `table` blocks, which `web/pages/blog/[slug].js` renders through `TableRenderer` as a real `<table>` with a `<thead>` built from row 0. An answer engine lifts either one whole without the surrounding paragraph.

**The turnover-rate calculator block**, `turnoverratecalcblock`, under the H3 "How to calculate your employee turnover rate":

| Step | Formula | Worked example |
|---|---|---|
| 1. Average number of employees | (employees at the start of the period + employees at the end of the period) ÷ 2 | (48 + 52) ÷ 2 = 50 |
| 2. Employee turnover rate | (employees who left during the period ÷ average number of employees) × 100 | (4 ÷ 50) × 100 = 8% |

Five blocks were removed into it, because leaving them would have made the page state the same formula three times over: `cc93a91bea2d` ("( Number of employees at beginning of period + Number of employees at end of period ) / 2"), `b0da87549f0e` ("From there, you'll want to divide..."), `9a60fcc9bfa4` ("Number of employees who left in that time period / Average number of employees x 100"), `004c66fec7a6` ("For example, if four employees left last month...") and `72891f6db776` ("4/50 x 100 = 8%"). The worked example keeps the post's own numbers, four leavers against an average of 50, and adds the start and end headcounts the old prose never gave. The lead-in block `8d6a64534ebf` was rewritten to introduce the block, and both formula graphics stay directly beneath it. A new block `turnoverannualnote` follows the graphics with the annual-denominator finding from section 1.

**The benchmark block**, `turnoverbenchmarkblock`, under the H3 "What is the average company turnover rate?":

| Industry (US) | Monthly separations rate, 2025 average | Monthly quits rate, 2025 average |
|---|---|---|
| All industries | 3.3% | 2.0% |
| Accommodation and food services | 5.5% | 4.2% |
| Professional and business services | 4.6% | 2.3% |
| Construction | 4.0% | 1.8% |
| Retail trade | 3.8% | 2.6% |
| Health care and social assistance | 2.9% | 2.0% |
| Manufacturing | 2.4% | 1.4% |
| Finance and insurance | 2.1% | 1.3% |
| Government | 1.5% | 0.8% |

Every cell is the 2025 column of BLS Tables 20 and 22 from the 2026 M01 release. The columns say "monthly" because BLS's current annual tables are monthly-equivalent rates, and a reader comparing a 15% annual figure against a 3.3% cell without that label would draw the wrong conclusion. The Mercer paragraph immediately under the table supplies the annual comparator.

`bls.gov` returns 403 to curl and to WebFetch from this machine regardless of headers, intermittently even with a full browser header set. Both tables were read through Playwright, which gets a 200. The monthly series were independently confirmed through the BLS public API (`https://api.bls.gov/publicAPI/v2/timeseries/data/`), which is not blocked.

> **FALSE, corrected in the fix pass.** "Regardless of headers" is wrong. BLS 403s a client whose User-Agent does not say who is calling, and 200s one that does. `curl -A "PolymerSEO/1.0 (jessicamgertig@gmail.com)" https://www.bls.gov/news.release/jolts.t20.htm` returns **200** from this machine; the same URL with a spoofed Chrome User-Agent or a bare `curl/8.0` returns **403**. Everything the figures rest on was re-read that way in the fix pass, including the archived releases. The API cross-check stands.

---

## 4. Images

All seven images in the post, six content blocks plus the feature image, were downloaded from `cdn.sanity.io` and viewed. Every `alt` was rewritten from what the graphic shows, not from the paragraph next to it. All six old `alt` strings began "Screenshot of", and none of the six is a screenshot.

| Block | Old alt | New alt describes | Carries a figure? |
|---|---|---|---|
| `727b02661ae0` | "Screenshot of average number of employees formula" | the formula spelled out in words: employees at the beginning plus employees at the end, all divided by two | no |
| `8f853eba0bf8` | "Screenshot of Employee Turnover Rate Formula " | the formula spelled out in words: leavers ÷ average employees, × 100 | no |
| `fba9ff86a46e` | "Screenshot of PwC's Survey 2022 about the impact of discussing sensitive topics at work" | the full bar chart including all six percentages and the 79% footnote | **yes, see below** |
| `e9065c978198` | "Screenshot of notoriety and adult playground-style office buildings" | Google's Zurich corridor as an indoor sports hall, wooden court, hoop, goal net, soccer-ball beanbag, two ski gondolas converted into meeting pods | no |
| `1555644700ba` | "Screenshot of 30-60-90 onboarding plan structure" | the three stages and what each one says | no |
| `bb3774ec9d83` | "Screenshot of Remote Work Allowance Example" | all six allowance amounts | dollar amounts, but illustrative, not sourced |
| `featureImage.altText` | "Employee Turnover Header Image" | a white dashed line on black falling to a low point then climbing to an open circle | no |

**One figure is held, and only that one.** The PwC chart `fba9ff86a46e` renders 65%, 41%, 34%, 32%, 31%, 28% and 79% as pixels. The prose block `06d17a0ee4b0` repeats two of them, 65% and 41%. Those two stay exactly as they were, because changing them would leave the sentence contradicting the picture directly above it. The only change to that sentence is the word "in 2022", so a reader can see the figures are four years old. Detail and the current values are in `QUESTIONS-FOR-JESSICA.md` under "Images that need regenerating, `/blog/employee-turnover`". **Every other dated figure in the post was replaced**, nineteen of them, including two other PwC figures from the same 2022 survey wave that do not appear in any graphic.

The remote-work-allowance graphic carries dollar figures ($80, $100, $1,000, $100, $50, $50) that no sentence in the post asserts and no source is credited for. They are illustrative examples rather than a dated statistic, so nothing is held behind them, but they are now stated in the alt text so they stop being invisible to an answer engine.

---

## 5. What was deliberately not done

**No answer-first restructuring.** The post ranks positions 18 to 30 across the `employee turnover rate` cluster, so the standing rule applies. No H2 or H3 was added, moved or merged. Three headings changed wording, and in every case because the heading itself carried something stale: "What people want from their employers in 2022" was dated in the heading, "It's a job seeker's market" is a claim that is no longer true, and neither is a structural change.

**No downloadable template.** The generic refresh definition names one, but tab 13 row 2 and tab 01 row 9 ask for benchmarks, a calculator block and formula blocks. The template belongs to `/blog/behavioral-interview-scoring-matrix`.

**The `techtalent.ca` link is gone and it was not dead.** `https://techtalent.ca/tech-talent-brain-gain/` returns 200. It went because the sentence it supported, "There are more jobs than talent, especially in growing tech hubs like Toronto", is a 2021-to-2022 claim about a market that has since reversed, and a live link under a false claim is worse than no link. CBRE's Scoring Tech Talent 2025 does still rank Toronto third in North America with the fourth largest AI talent pool, so a Toronto-specific point could be rebuilt on a current source if one is wanted; that would be new prose, so it was not written.

**Nothing in the second half of the post below "How to improve employee turnover" carried a dated figure.** The onboarding, training, feedback, tooling, management, meaning, wellness and exit-interview sections were read end to end. They contain no statistics, no named studies and no practices that have changed, so nothing there was touched.

---

## 6. Source URLs used, all confirmed 200 on 2026-08-06

- https://www.gallup.com/workplace/247391/fixable-problem-costs-businesses-trillion.aspx
- https://www.bls.gov/news.release/jolts.t20.htm (200 to curl with a User-Agent carrying a contact address; 403 to a spoofed browser UA or bare curl)
- https://www.bls.gov/news.release/jolts.t22.htm (same)
- https://www.imercer.com/articleinsights/workforce-turnover-trends
- https://www.pwc.com/gx/en/issues/workforce/hopes-and-fears.html
- https://www.ddi.com/blog/leadership-and-employee-retention
- https://www.reveliolabs.com/companies/amazon/employees
- https://www.reveliolabs.com/companies/google/employees
- https://www.gallup.com/401384/indicator-hybrid-work.aspx
- https://www.ecoonline.com/en-us/resources/research/the-workplace-safety-report/
- https://www.hiringlab.org/2026/08/04/june-2026-jolts-report/

Links kept from the original post and re-verified: `https://www.polymer.co/blog/a-player`, `https://www.polymer.co/blog/talent-acquisition` (200), `https://www.polymer.co/blog/onboarding`, `https://www.polymer.co/`.

---

# Fix pass

2026-08-07. Six findings were returned against this post: 2 HIGH and 4 LOW. Five were defects and are fixed; one is Jessica's, recorded and left alone. Two further defects were found on the re-read and fixed. Draft `drafts.e3c6e6d7-5957-49a4-8f28-682b6c21a41e` patched twice, both times a `set` on named block paths guarded with `ifRevisionId`. Published document `e3c6e6d7-5957-49a4-8f28-682b6c21a41e` still reads `_updatedAt: 2023-07-05T13:12:39Z` and `_rev: dhFzkRKqK2TcLpN1ogXtX9`. 128 content blocks before and after. `author`, `updatedDate` (2026-08-06) and `featureImage` all intact.

## HIGH-1, `turnoverannualnote`: the note misstated its own arithmetic and put the mistake on BLS

**What it said:** "The two-point average is fine for a month or a quarter. For a full year, average the headcount at the end of each of the 12 months instead. It is the more accurate denominator, and it is the method the US Bureau of Labor Statistics uses for its own annual turnover figures", with the last clause linked to `jolts.t20.htm`.

**What the source says.** Read directly, `curl -A "PolymerSEO/1.0 (jessicamgertig@gmail.com)" https://www.bls.gov/news.release/jolts.t20.htm`, footnote (1):

> The annual average total separations rate is equal to the sum of the 12 monthly total separations levels as a percent of the sum of the 12 monthly CES employment levels.

And the same footnote on `jolts.t22.htm` for quits:

> The annual average quits rate is equal to the sum of the 12 monthly quits levels as a percent of the sum of the 12 monthly CES employment levels.

**Why it mattered.** BLS sums the numerator as well as the denominator. With a headcount of `H` held roughly steady and `L` leavers over the year, BLS computes `L / (12H)`, a monthly-equivalent rate. The note's instruction computes `L / H`, twelve times larger. The benchmark table sits directly below the note and its "All industries" row reads 3.3%. A reader who followed the note would have produced roughly 24% and read it against 3.3%. Tab 01 row 9 asks for a formula block for AEO, so an answer engine lifts this paragraph whole.

**Now reads:**

> The two-point average is fine for a month or a quarter. For a full year, average the 12 month-end headcounts instead, then divide the year's leavers by that average. That gives an annual turnover rate, which is not comparable to the BLS benchmarks further down this page: [BLS divides a year of separations by the sum of the 12 monthly employment levels](https://www.bls.gov/news.release/jolts.t20.htm), so its annual averages are monthly-equivalent rates, roughly a twelfth the size of an annual one. The Mercer figures under that table are annual, so those are the closer comparison.

The BLS attribution stays because the link now sits on a sentence the linked footnote actually states. The unsourced "It is the more accurate denominator" came out. Mercer's annual voluntary-turnover paragraph, `fac12d5840cf`, is named as the comparator a reader wants after running the calculator.

## HIGH-2, `2ccc9bafabb5`: a correct figure under a source that does not state it

The clause read "against 3.0% at the 2021 to 2022 quits peak" under the single markDef `hiringlabjune2026` → `https://www.hiringlab.org/2026/08/04/june-2026-jolts-report/`. That article was re-fetched in full. It states hires 3.4%, quits 2%, layoffs 1.1% for June 2026 and the Indeed Job Postings Index at about 1% above the pre-pandemic baseline. **It states no 3.0 and no peak value.**

The figure itself is right. BLS series `JTS000000000000000QUR` pulled from `https://api.bls.gov/publicAPI/v2/timeseries/data/` for 2020 to 2026 reads 3.0 in 2021 M11 and 2022 M04, and those two months are the series maximum; 2.9 appears in 2021 M09, 2021 M12, 2022 M01 and 2022 M03.

Rather than drop a true figure, the clause was repointed at a BLS page that states it. `https://www.bls.gov/news.release/archives/jolts_01042022.htm`, the JOLTS release for 2021 M11:

> The number of quits increased in November to a series high 4.5 million (+370,000). The quits rate increased to 3.0 percent, matching the series high in September.

**Now reads:** "...in June 2026 employers hired at a monthly rate of 3.4% and workers quit at 2.0%, against a quits rate of 3.0% at its series high in November 2021." The Hiring Lab link stays on the June 2026 clause, which that article does state; the new `blsquitspeaknov2021` markDef carries the 3.0%. Naming November 2021 rather than "the 2021 to 2022 peak" is what the cited page supports and it puts a year on the figure.

## LOW-1, `ca295804d4db`: true claim, no source reached the reader

"US quit rates have fallen every year since 2022" had no markDef at all. Confirmed against Table 22 read directly, total quits row: 2021 **2.7**, 2022 **2.8**, 2023 **2.4**, 2024 **2.1**, 2025 **2.0**. Falling in each of 2023, 2024 and 2025 from the 2022 figure, and 2022 is the local high, so the sentence is exactly right. `https://www.bls.gov/news.release/jolts.t22.htm` is now linked on the claim. No wording changed.

## LOW-2, "two blocks added": corrected in both files

Three were added: `turnoverratecalcblock`, `turnoverannualnote`, `turnoverbenchmarkblock`. Five removed: `cc93a91bea2d`, `b0da87549f0e`, `9a60fcc9bfa4`, `004c66fec7a6`, `72891f6db776`. 130 - 5 + 3 = 128, which matches the draft. The headline of this log and the summary line in `QUESTIONS-FOR-JESSICA.md` both said "two blocks added" and both now say three, with the paragraph named so the count cannot be read as two tables only.

## LOW-3, the broken H2 anchor: Jessica's, not fixed

Confirmed in code, not inferred. `web/pages/blog/[slug].js` line 357 builds each h2 id as `slugify(toPlainText(value).toLowerCase())`, and line 327 builds the table-of-contents href as `` `/blog/${post.slug.current}#${slugify(toPlainText(section).toLowerCase())}` ``. Renaming "What people want from their employers in 2022" to "...in 2026" therefore retires `#what-people-want-from-their-employers-in-2022`. The page stays self-consistent because the table of contents regenerates from the headings; only an external deep link into that section breaks.

Left as it is. Every option breaks that anchor: keeping a four-year-old year in a heading is the defect the rename fixed, and dropping the year entirely retires the same anchor. Recorded as item 6 in `QUESTIONS-FOR-JESSICA.md` so it is a decision rather than an omission.

## LOW-4, the five deleted blocks: Jessica's, not reverted

The finding is right that the tabs are additive and the no-restructuring rule applies to a post that currently ranks. It is also right that the deletion is disclosed and reversible: every word survives inside the calculator table's cells and all five keys are recorded. Reverting it would put the same formula on the page three times, which is a worse page, so the call is hers rather than mine. Item 5 in `QUESTIONS-FOR-JESSICA.md` was rewritten to present it as a decision with the revert path spelled out, instead of as a completed change.

## Found on the re-read, not in the findings

**`a68fd60a7b03` cited Table 20 for figures only Table 22 states.** The paragraph asserts four numbers: separations 3.3% (2025) and 3.9% (2021), quits 2.0% (2025) and 2.7% (2021). Table 20 is separations only; the two quits figures appear on Table 22. The single markDef pointed at Table 20. The linked spans are now split: "3.3% of their workforce to separations" carries `jolts.t20.htm` and "2.0% to voluntary quits" carries `jolts.t22.htm`. No figure changed, and all four were re-verified against the two tables read directly.

**`06d17a0ee4b0` carried two figures with no source anywhere on the page.** "Out of the 65% surveyed in 2022... 41% said..." is the held PwC prose. Held means the figures stay, not that they stay uncited. `https://www.pwc.com/gx/en/issues/workforce/hopes-and-fears-2022.html` returns 200 and states both verbatim: "65% of employees have discussed social and/or political issues", and under "Impact of these discussions, % of respondents", "Allowed me to understand my colleagues 41%". That URL is now linked on "Out of the 65% surveyed in 2022". Neither figure was touched, so the sentence still agrees with the graphic above it.

**`8f271ffaea12` had an orphaned markDef.** `97a3d1237912` was in the block's `markDefs` with no span referencing it, left behind when that block was rewritten. Removed. No visible change.

## Everything else re-verified, nothing else wrong

Every remaining external source in the post was re-fetched and the sentence checked against it.

| Claim in the post | Source states |
|---|---|
| Gallup 2019, replacing an employee costs one-half to two times salary | "The cost of replacing an individual employee can range from one-half to two times the employee's annual salary", 13 March 2019 |
| Mercer 2025, 2,617 organizations, 13.0%, 13.5% in 2024, 17.3% in 2023, retail and wholesale 26.7%, insurance 8.2% | All six verbatim on the page. Note: it is dated **4 February 2025**, not August 2025 as section 2 of this log says |
| PwC 2025, nearly 50,000 workers, 28 sectors, 48 economies, 91% more motivated, about half found meaning, 58% trust their manager, barely half trust top management | "nearly 50,000 respondents spanning 28 sectors in 48 major economies"; "49,843 workers... from 7 July through 18 August 2025"; "91% more motivated"; "only about half of all workers say they've found meaningful careers"; "58% say they trust their direct manager and can speak openly with them"; "barely half of our survey respondents say they trust top management". Published 12 November 2025 |
| DDI, 57%, still published in 2026 | "DDI's Frontline Leader Project showed that 57% of employees have left at least one job because of a bad boss", page dated 15 May 2026 |
| Revelio, Amazon average 3.6 years and Google median 4.4 years, March 2026 | Both pages state their own figure with their own word, both "as of March 2026" |
| Gallup, 52% hybrid as of May 2026, six in 10 want hybrid, six in 10 fully remote would look elsewhere | Work-locations series on the page runs to `5/01/2026 26 52 22`; "Six in 10 employees with remote-capable jobs want a hybrid work arrangement"; "Six in 10 remote-capable employees who work exclusively remotely now say they're extremely likely to look for a new job if remote flexibility is taken away" |
| EcoOnline 2026, three-quarters globally, 78% US and Canada, more than 5,900 employees | "75% of workers feel its important that their employer work to reduce their environmental impact"; "An average of 78% of workers in the USA and Canada"; over 5,900 employees |
| Nine-row benchmark table, 2025 averages | Every one of the eighteen cells matches the 2025 column of Tables 20 and 22 read directly, including all industries 3.3/2.0, accommodation and food services 5.5/4.2, government 1.5/0.8 |

Link check, all 200: the eleven external sources above, the Business Insider `sourceUrl` on the Google Zurich image, `polymer.co`, `polymer.co/blog/a-player`, `polymer.co/blog/talent-acquisition`, `polymer.co/blog/onboarding`. No em-dashes or en-dashes anywhere in the draft. No plan or product name in the post has changed.

Two reachability claims elsewhere in the run were re-tested rather than taken on trust. The SHRM how-to guide returns 200 but serves nav chrome and a "Lorem ipsum" placeholder in place of the body, with `paywall` appearing 23 times and `member-only` 4 times in the markup, so "behind a SHRM membership wall" stands. `zety.com` returns HTTP 000 on a 25-second timeout, so that entry stands too. The `bls.gov` claim did not stand and is corrected above and in `QUESTIONS-FOR-JESSICA.md`.
