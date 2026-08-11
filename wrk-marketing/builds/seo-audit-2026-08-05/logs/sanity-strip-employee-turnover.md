# Sanity strip pass, `/blog/employee-turnover`

2026-08-07. Draft `drafts.e3c6e6d7-5957-49a4-8f28-682b6c21a41e` only. Published document `e3c6e6d7-5957-49a4-8f28-682b6c21a41e` was never mutated: it still reads `_rev: dhFzkRKqK2TcLpN1ogXtX9`, `_updatedAt: 2023-07-05T13:12:39Z`, 130 blocks, and a byte-for-byte comparison against the snapshot taken before the patch returns identical. Nothing was published.

Draft went 128 blocks to 133. One transaction, four patches, `ifRevisionId` guarded on the first against `kJ3OpIOJnJS2LKJpQpr0Q9`, read immediately before commit. New draft `_rev: kJ3OpIOJnJS2LKJpQq2opp`. `author` (`author-jessica-gertig`), `updatedDate` (2026-08-06) and `featureImage.altText` all intact and untouched by this pass.

The published document is the reference for "what was there before": the refresh log records the draft as having matched published in `content` before the 2026-08-06 patch, and published still carries all 130 original blocks.

---

## What authorises what

The Overview tab, issue #13, Recommended fix:

> "Refresh each post (2026 data, updated modified dates, author bylines, downloadable templates), in the order given in the detail tab."

Tab 13 Content Freshness row 2 (E8): "Add 2026 benchmarks, turnover-rate calculator block; biggest strike-distance upside"

Tab 01 Orphaned Pages row 9 (F9): "Link + refresh; formula & benchmark blocks for AEO"

Both are additive. Neither authorises removing anything. Decision 8 of `approved-decisions.md` puts this post, which ranks 18 to 30, outside restructuring.

---

## Restored

### The five deleted prose blocks, back in their original positions with their original text

`cc93a91bea2d`, `b0da87549f0e`, `9a60fcc9bfa4`, `004c66fec7a6`, `72891f6db776` were folded into `turnoverratecalcblock` on 2026-08-06. All five are back, each byte-identical to the published document including `_key`, span `_key`, `marks` and `markDefs`. Verified by `JSON.stringify` equality against published, block by block.

The section under the H3 "How to calculate your employee turnover rate" now reads in its original order:

```
29 8d6a64534ebf   To find out your employee turnover rate, first, calculate the average number of employees ... like so:
30 cc93a91bea2d   ( Number of employees at beginning of period + Number of employees at end of period ) / 2
31 727b02661ae0   [image, new alt kept]
32 b0da87549f0e   From there, you'll want to divide the number of employees who left in that period ...
33 9a60fcc9bfa4   Number of employees who left in that time period / Average number of employees x 100
34 8f853eba0bf8   [image, new alt kept]
35 004c66fec7a6   For example, if four employees left last month and the average number of employees was 50 ...
36 72891f6db776   4/50 x 100 = 8%
37 turnoverratecalcblock   [table, kept]
38 turnoverannualnote      [kept, see uncertain]
39 7ba0e060599a
```

Every published `_key` that was in the document before is present, and the relative order of all published keys is unchanged from published. Verified.

**Which way I went on the table:** kept, and the prose kept too, as the task's default. Tab 13 row 2 says "Add ... turnover-rate calculator block" and tab 01 row 9 says "formula & benchmark blocks for AEO". Both use "Add" or list the blocks as things to have; neither cell says anything about the prose already on the page, and neither says "replace". So the block is authorised and the deletion was not. The page now states the formula in prose and again in the table. That repetition is the price of two additive cells landing on a section that already explained the method, and it is Jessica's to collapse if she wants it collapsed.

`turnoverratecalcblock` and `turnoverannualnote` were lifted out and reinserted after `72891f6db776` rather than left where they sat. They sat in the two gaps the deleted prose had occupied, so leaving them there would have split the restored run. Both blocks are byte-identical to what the refresh pass wrote, including `turnoverannualnote`'s `blsannualmethod` markDef; only their position moved, and neither had an original position to preserve.

### `8d6a64534ebf`, the lead-in

Was: "To find out your employee turnover rate, first, calculate the average number of employees to find out your employee turnover rate. Divide the total number of employees at the start and end of your chosen period by two to get the average, like so:"

Refresh pass wrote: "Calculating your employee turnover rate takes two steps: find the average number of employees for the period, then divide the number of people who left by that average."

Restored. No figure, no date and no source is involved in either version. It was rewritten only to introduce the replacement table, and its closing "like so:" is what `cc93a91bea2d` hangs off.

### `2d73625432f1`

Was: "If you want to see how you're doing compared to other companies, keep in mind that average turnover rates differ vastly between industries."

Refresh pass wrote: "Average turnover rates differ sharply between industries, so compare your rate with your own sector rather than with a national average."

Restored, text and `markDefs`. The original sentence carries no figure, no year and no dated claim; it is as true in 2026 as it was in 2023. The rewrite also dropped the block's `markDefs` entry `d0d0392b5aa6` pointing at `https://www.bls.gov/news.release/jolts.t18.htm`, which is back. (That markDef is orphaned in the published document too, no span references it, so restoring it changes nothing visible; it is restored because restoring means putting back what was there.)

### `0c92d94be2f9`

Was: "Let's explore ways to improve employee turnover to avoid your employees jumping ship to any available open roles."

Refresh pass wrote: "Let's explore ways to improve employee turnover so the people you most want to keep have no reason to look."

Restored. The refresh log records this as a knock-on from the labor-market rewrite in `2ccc9bafabb5`. The original clause carries no figure, no year and no market claim: "jumping ship to any available open roles" reads the same in a tight market as in a loose one. New prose with nothing dated behind it.

---

## Kept, because a cell or a decision authorises it

Every one of these replaces a dated figure, a dated claim or thin alt text, which is what the Overview fix cell ("2026 data"), Decision 1 ("replace every dated statistic ... with a current figure AND a current source URL"), Decision 2 (alt text) and Decision 4 (the agent surveys the post itself; the orchestrator's list is a hint, not an inventory) authorise.

| Block | Kept change | Authorising cell or decision |
|---|---|---|
| `1da505a31489` | Gallup replacement-cost figure re-dated to its 2019 origin, link moved | Decision 1, "the Gallup Great Resignation figures" |
| `a68fd60a7b03` | 66.8% / 50.6% / 17.8% replaced with 2025 BLS separations and quits rates, split across Tables 20 and 22 | Decision 1, all three named |
| `turnoverbenchmarkblock` | nine-row industry benchmark table added | Tab 13 row 2 "Add 2026 benchmarks"; tab 01 row 9 "benchmark blocks for AEO" |
| `turnoverratecalcblock` | calculator table added | Tab 13 row 2 "turnover-rate calculator block"; tab 01 row 9 "formula ... blocks for AEO" |
| `fac12d5840cf` | 32.7% for 2021 replaced with Mercer 2025 | Decision 1, "all-industry employment separation rate 32.7% for 2021" |
| `ca295804d4db` | "a global increase in employee turnover rates" replaced with the BLS quits trend, source added | Decision 1 plus Decision 4, a dated claim carrying no number |
| `a532977b3542` | PwC Hopes and Fears 2022 replaced with 2025 | Decision 1, "the PwC Hopes and Fears percentages" |
| `fef31339b688`, `06d17a0ee4b0` | "from the 2022 edition", "in 2022", plus the 2022 PwC source URL | Decision 1, "the sentence carries the year the figure belongs to"; Decision 6, the figure itself is held because the chart above renders it |
| `28606853f0f4` | "retain A-players in 2022" to "in 2026" | Decision 1 |
| `22288b3fd87d` | DDI 57% re-attributed to DDI's own current page | Decision 1, "the DDI figure (57% quit because of their boss)" |
| `3867935e4803` | "median tenures of only one year" replaced with Revelio March 2026 figures | Decision 1, Decision 4 |
| `db6c5e5050a0` | H2 "What people want from their employers in 2022" to "in 2026" | Decision 1 names this heading explicitly in its list |
| `6176945a0a16` | PwC 62% hybrid replaced with Gallup May 2026 | Decision 1, "62% hybrid preference" |
| `5bcd81359269` | PwC 23% environmental replaced with EcoOnline 2026 | Decision 1, "23% environmental impact" |
| `2ccc9bafabb5` | Toronto talent-shortage claim replaced with June 2026 JOLTS figures; `techtalent.ca` link went with the sentence it supported | Decision 1, Decision 4 |
| six image `alt` strings and `featureImage.altText` | rewritten from what each graphic shows | Decision 2 |
| `author`, `updatedDate` | byline and modified date | Overview fix cell, "updated modified dates, author bylines"; Decision 6 item 5 |

The H2 rename at `db6c5e5050a0` was checked specifically. Decision 1 lists "the H2 heading 'What people want from their employers in 2022'" among the dated things to replace, by name. It stays at 2026.

---

## Structural sweep of the rest of the post

- **Deleted blocks:** the five above and no others. Every one of the 130 published `_key`s is present in the draft.
- **Merged blocks:** none beyond the five.
- **Reordering:** none. The sequence of published keys in the draft is identical to the sequence in published.
- **New headings:** none. The three added blocks are two `table`s and one `block/normal`. No block changed `style`, and no `h2` or `h3` was added, moved or merged.
- **Style changes:** none anywhere in the document.

---

## Uncertain, quoted and left alone

Four things where I could not settle whether a cell authorises them. Per the rule that over-removal is worse than a flagged uncertainty, all four are untouched.

**1. `turnoverannualnote`, an added paragraph.** Roughly 90 words of new prose on annual-versus-monthly denominators, added on 2026-08-06 and rewritten in the 2026-08-07 fix pass.

> Tab 13 row 2: "Add 2026 benchmarks, turnover-rate calculator block; biggest strike-distance upside"
> Tab 01 row 9: "Link + refresh; formula & benchmark blocks for AEO"

Both cells ask for blocks, and both name what those blocks are: a calculator, formulas, benchmarks. This paragraph is none of the three. It is a methodological caveat sitting next to them, and it is a new paragraph of prose, which is the thing the strip rule names. Against that, it exists only to keep a reader from comparing an annual figure against the monthly BLS table directly below it, so it is arguably part of delivering the calculator and the benchmarks correctly. Left in place.

**2. `04e1257f279c`, an H3 renamed.** "It's a job seeker's market" became "The market has swung back toward employers". No cell names this heading. Decision 1 does name the other heading in this post, so headings are in scope when they carry dated content, and "It's a job seeker's market" is a market claim the June 2026 JOLTS figures in the paragraph beneath it now contradict. But it carries no figure and no source URL, which is what Decision 1's remedy requires, and Decision 8 keeps this post out of restructuring. Left in place.

**3. `8045769956a6`.** "Employees have the upper hand in the current climate of resignation and skill shortages." became "A slower hiring market does not mean your best people are short of options." Same shape as item 2: the original names a dated market condition, the Great Resignation, so Decision 4 reaches it, but the replacement carries no figure and no source. Left in place.

**4. `8f271ffaea12` `markDefs` emptied.** The refresh pass removed markDef `97a3d1237912` pointing at `hopes-and-fears-2022.html`. No span in that block references it, in published or in the draft, so it was dead data before and after and nothing rendered differently. No cell authorises the removal, and no reader can see it either way. Left removed rather than restored, on the grounds that putting an orphaned markDef back is not restoring content.

---

## Verification

- Published `e3c6e6d7-5957-49a4-8f28-682b6c21a41e`: `_rev` `dhFzkRKqK2TcLpN1ogXtX9`, `_updatedAt` `2023-07-05T13:12:39Z`, 130 blocks, byte-identical to the pre-patch snapshot.
- Draft: 133 blocks. Published keys still missing: none. Added keys: `turnoverratecalcblock`, `turnoverannualnote`, `turnoverbenchmarkblock`. Published-key order preserved: true.
- `cc93a91bea2d`, `b0da87549f0e`, `9a60fcc9bfa4`, `004c66fec7a6`, `72891f6db776`, `8d6a64534ebf`, `2d73625432f1`, `0c92d94be2f9`: each `JSON.stringify`-identical to its published counterpart.
- `author`, `updatedDate`, `featureImage.altText` unchanged by this pass.
- All patches were `set`, `unset` and keyed `insert` on `content[_key=="..."]` paths. The `content` array was never written whole.
