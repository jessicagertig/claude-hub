# Refresh log, `/blog/interview-feedback-examples`

Tab 13 row 4. Published 2022-09-06, ranks pos 5-29 across the feedback cluster. Refresh order 4.
Tab 13 refresh scope as written: "Refresh examples; answer-first blocks".

Sanity document `a4d5d182-0025-4911-8bf7-d7b8e888e62a`. All work landed on `drafts.a4d5d182-0025-4911-8bf7-d7b8e888e62a`. The published document was read only and its `_updatedAt` is still `2022-09-06T15:18:10Z`. Nothing was published.

The existing draft carried an author assignment (`author-corey-daniels`) from an earlier phase. It was read, patched in place, and the author reference was not touched.

---

## What the post is, and what "refresh examples" turned out to mean here

100 content blocks. Three images. The eight numbered "interview feedback examples" in the second half are scripted "Instead of saying / Say" pairs. None of them carries a date, a statistic, a named study or a practice that has changed. Refreshing them would have meant rewriting them, which is not what refresh means. They were read end to end and left alone.

Everything dated in this post sits in the first half, in the "Why is providing interview feedback important?" and "Creating a standardized feedback system" sections. That is where the work happened.

## Answer-first: asked for, deliberately not done

Tab 13 row 4 asks for "answer-first blocks". This post currently ranks positions 5 to 29 across the feedback cluster, so rule 8 applies and it was not restructured. No H2 or H3 was added, moved, merged or reworded. No new sections. The heading tree is byte-for-byte what it was.

---

## Survey: everything dated, statistical or practice-bearing in the post

The whole post was read block by block, not scanned for `%` and four-digit years. Six items came out of it.

| # | Block | What it is | Outcome |
|---|---|---|---|
| 1 | `5b715b852846` | 36% willingness to increase relationship, 24% more likely to refer, on a dead 2021 Talent Board PDF | REPLACED |
| 2 | `f32d26a09fd0` + image `d7ef9507c4ee` | "referrals are the top way people discover a new job" | HELD (graphic carries it) |
| 3 | `0721197a0496` | "four times as likely qualified people will apply to your company again" | REPLACED |
| 4 | `205f502889fe` | "Aim to provide feedback within a week" | REPLACED (practice has changed) |
| 5 | `f41fbdd7cfee`, `5852e2591824`, image `0b71061d61c5` | `careers.google.com/how-we-hire/` source URL, now a 301 | URL UPDATED |
| 6 | `dcc88500412f` | EEOC prohibited employment policies/practices link | LEFT (still 200 at its original URL) |

---

## 1. Block `5b715b852846`, the two CandE figures

**Was:**

> [Research shows](https://3cmsd11vskgf1d8ir311irgt-wpengine.netdna-ssl.com/wp-content/uploads/2021/12/2021-North-America-CandEs-Research-Report_12-14-2021.Final_.pdf) that when candidates receive post-interview feedback, their willingness to increase their relationship with the employer increases by 36%. Further, when candidates do receive feedback, they are 24% more likely to refer others. Feedback creates a sense of honesty and trust candidates relay to their peers.

**Source state.** The href is the 2021 North America CandE Research Report on Talent Board's old WP Engine CDN. It resolves 200 but only because `netdna-ssl.com` now answers everything with a parked page: the request ends at `https://netdna-ssl.com/en-6`. The PDF is gone. Talent Board itself no longer runs the research; Survale acquired the CandE Benchmark Research and Awards Program from ERE Media, and Survale now publishes it.

**2026 check, per figure.** The 2026 CandE Benchmark Research and Award Program has opened for registration but has published no results; the page billed as the 2026 CandE Day results webinar presents the 2025 findings. So there is no 2026 value for either figure. The 2025 Global CandE Benchmark Research Report exists (published 14 May 2025, 66,000 candidates at 110 companies) but every figure in it sits behind a lead-capture form, so its numbers are not reachable. See the QUESTIONS entry.

The most recent published, reachable, one-for-one values are from the 2024 CandE Benchmark Research, written up by Kevin Grossman on ERE, 23 January 2025, which states both of the exact measures the old sentence used:

> "When specific feedback was given to candidates, their willingness to refer others NPS rating increased by over 50% in 2024."
>
> "Their willingness to increase their relationship with the employer NPS rating increased by 20%."

**Now:**

> [The 2024 CandE Benchmark Research](https://www.ere.net/articles/12-key-takeaways-from-the-2024-candidate-experience-benchmark-research) found that when specific feedback was given to candidates, their willingness to increase their relationship with the employer rose 20%, and their willingness to refer others rose by over 50%. Feedback creates a sense of honesty and trust candidates relay to their peers.

36% → 20%. 24% → over 50%. Source URL swapped from the dead PDF to the live ERE write-up. The sentence names the year, so it does not read as newer than it is.

The second markDef on this block, `48ac5f0c7663` (the LinkedIn PDF), was already orphaned before this pass, with no span referencing it. It was left as found.

## 2. Block `f32d26a09fd0` and image `d7ef9507c4ee`: HELD

> According to a [LinkedIn survey,](https://business.linkedin.com/content/dam/business/talent-solutions/global/en_us/c/pdfs/Ultimate-List-of-Hiring-Stats-v02.04.pdf) referrals are the top way people discover a new job.

The image immediately below renders, in pixels, "The #1 way people discover new jobs is **through a referral**". Replacing the claim in the prose would leave the graphic contradicting the text directly beneath it, so this one figure is held under rule 6. Fully researched anyway and written up in QUESTIONS-FOR-JESSICA.md under "Images that need regenerating".

Held per figure, not per post: the other three dated items in this post were all replaced.

The LinkedIn PDF href still resolves (301 to an Adobe AEM delivery URL, 200). It is the source of the graphic, so it stays until the graphic is regenerated. The PDF itself is undated and its text could not be extracted for verification (font-subset compressed streams; `pdftotext` and `pypdf` are not installed on this machine, and the Read tool's PDF path needs `pdftoppm`).

## 3. Block `0721197a0496`, the "four times" claim

**Was:**

> Leaving a positive impression on candidates is integral to filling your talent pipeline. The LinkedIn study above found constructive feedback makes it four times as likely qualified people will apply to your company again.

**Why it could not stand.** Two problems. The claim is attributed to "the LinkedIn study above", and I could not verify it appears in that PDF at all; every secondary source that repeats "4x more likely to consider your company" attributes it to HCI or to Lever, not to LinkedIn's hiring statistics list. And the figure is undated everywhere it appears, so it cannot carry a year.

**Now:**

> Leaving a positive impression on candidates is integral to filling your talent pipeline. [The CandE Benchmark Research](https://survale.com/candes/) reports that candidates at CandE award-winning employers are 26% more likely to apply to your other jobs.

Same claim shape, feedback and a good experience bringing people back to apply again, now from a source that states it: Survale's CandE Research and Awards page, under "What the Research Shows", "26% Candidates at CandE winner companies are 26% more likely to apply to your other jobs". The page is © 2026 Survale and is the program's current published figure.

The sentence deliberately does not name a year, because the source does not date that figure. Noted in QUESTIONS-FOR-JESSICA.md so the omission is a decision rather than an oversight.

## 4. Block `205f502889fe`, "within a week"

A practice that has since changed, which is why the survey was a read rather than a keyword scan.

**Was:** "Aim to provide feedback within a week, as waiting too long can feel impersonal and harm your reputation."

**Now:** "Aim to provide feedback within three to five days, the disposition window the [2025 CandE Benchmark Research](https://www.candidate-experience-institute.com/cande-2025-benchmark-the-3-to-5-day-decision-rule-that-separates-award-winners-from-everyone-else) links to higher offer acceptance and stronger re-application rates. Waiting too long can feel impersonal and harm your reputation."

Source: Candidate Experience Institute, "CandE 2025 Benchmark: The 3-to-5 Day Decision Rule That Separates Award Winners From Everyone Else", published 27 April 2026, on the 2025 CandE benchmark cycle. It states that award-winning employers consistently hit a three- to five-day go or no-go disposition after interviews, and that organisations inside that window see higher offer acceptance, stronger re-application rates and more positive post-rejection feedback. This is a 2026-published source, which is why it beat the older material.

## 5. `careers.google.com` source URL

`https://careers.google.com/how-we-hire/` 301s to `https://www.google.com/about/careers/applications/how-we-hire/`. The href on markDef `dce644e2ccc4` in blocks `f41fbdd7cfee` and `5852e2591824`, and the `sourceUrl` on image `0b71061d61c5`, were all moved to the destination. No prose changed.

The practice the block cites is still current: Google still describes structured interviewing with clear rubrics applied to everyone considered for a role, and open-ended questions, on its own re:Work guide to structured interviewing.

The how-we-hire page renders client-side, so its static HTML carries no body text and the exact wording in the screenshot could not be confirmed against the live page. Recorded in QUESTIONS-FOR-JESSICA.md.

## 6. EEOC link, left alone

`https://www.eeoc.gov/prohibited-employment-policiespractices` on markDef `5d3a533994ac` still returns 200 at its original URL, no redirect. Left as found.

---

## Images: all three viewed, alt text written from the pixels

Every image was pulled from the Sanity CDN and viewed. Alt text below is written from what the graphic shows, not from the paragraph beside it.

### Image `d7ef9507c4ee`, the LinkedIn referrals card

**What it asserts, every figure and label rendered as pixels:**

- Heading: "Referrals"
- "The #1 way people discover new jobs is **through a referral**"
- "Companies can expand their talent pool by **10x** by recruiting through their employees' networks."
- "**35% of employees** refer to help their friends. 32% do it to help their company. 26% do it to be seen as a valuable colleague. Only 6% do it for money and recognition." (the graphic misspells "colleague" as "colleaque")
- "Candidates are **46% more likely** to accept InMails when they're connected to your employees."
- "Employee referrals are a top source of **quality hires** along with social networks and internet job boards."
- Bottom right: "Source: business.linkedIn.com"
- No date appears anywhere in the graphic.

**Alt was:** "Screenshot of LinkedIn survey result that referrals are the top way people discover a new job\n"

**Alt now:** "LinkedIn statistics card headed "Referrals" listing five findings: the number one way people discover new jobs is through a referral; companies can expand their talent pool by 10x by recruiting through their employees' networks; 35% of employees refer to help their friends, 32% to help their company, 26% to be seen as a valuable colleague and only 6% for money and recognition; candidates are 46% more likely to accept InMails when they are connected to your employees; and employee referrals are a top source of quality hires along with social networks and internet job boards. Source: business.linkedin.com."

The old alt named one of the five findings and left the other four, including every percentage, invisible to anything that cannot see the picture.

### Image `0b71061d61c5`, the Google how-we-hire card

**What it asserts:** Google wordmark, then "In the end, we want above all to assess your skills and see if you and this role are a match (there aren't any brain teasers, and who knows, you might even have some fun). So we conduct our interviews using these guiding lights:" followed by two bullets, "Structured interviewing: Every candidate is assessed using clear rubrics, and we use those rubrics for all folks being considered for that role, so that everyone is evaluated from the same perspective, allowing their distinctiveness to emerge." and "Open-ended questions: We ask open-ended questions to learn how you solve problems. We want to understand how your mind works, how you interact with a team, and what your strengths are." No figures, no date.

**Alt was:** "Screenshot of Google Interview Process"

**Alt now:** "Google careers card, under the Google logo, stating that Google wants above all to assess your skills and see if you and the role are a match, that there are no brain teasers, and listing the two guiding lights it conducts interviews by: structured interviewing, where every candidate is assessed using clear rubrics and those same rubrics are used for everyone considered for that role so that everyone is evaluated from the same perspective; and open-ended questions, asked to learn how you solve problems, how your mind works, how you interact with a team and what your strengths are."

The block above it says Google "uses clear rubrics", which is the point the graphic exists to evidence. The old alt did not say it.

### Feature image (`featureImage.altText`)

**What it asserts:** a black field with two white outlined circles, one upper left with a dashed white line running right from it, one lower right with a dashed white line running left into it. Abstract. No text, no figures, no date.

**Alt was:** "Interview Feedback Header Image"

**Alt now:** "Header graphic on a black background showing two white outlined circles linked by dashed white lines, one line running right from the upper circle and one running left into the lower circle."

---

## Byline and updated date

`updatedDate` set to `2026-08-06`. The author reference `author-corey-daniels` was already on the draft and was not changed.

## Nothing was dropped

Every figure in the post is now either replaced with a current sourced value, or held with its research written up in QUESTIONS-FOR-JESSICA.md. No sentence lost a claim. No block was deleted, added, merged or reordered; the draft still has exactly 100 content blocks.

## Files

- Draft patched: `drafts.a4d5d182-0025-4911-8bf7-d7b8e888e62a`, revision `QzNVnRn1RN9Wy2ys8Qp9n3`
- Questions appended to `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
- No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was touched

---

# Fix pass, 2026-08-07

Six verifier findings on this post: two HIGH, two MED, two LOW. All six worked. Draft `drafts.a4d5d182-0025-4911-8bf7-d7b8e888e62a` patched from revision `QzNVnRn1RN9Wy2ys8Qp9n3` to `QzNVnRn1RN9Wy2ys8Qu8WV` in a single guarded patch of narrow `set` operations on specific block and span paths. Nothing was published. Block count is still 100, key order unchanged, `author` still `author-corey-daniels`, `updatedDate` still `2026-08-06`, and the document still contains zero em-dashes and zero en-dashes.

## The stop that caused four of the six findings

The refresh reported the LinkedIn PDF's text as unextractable, citing the absence of `pdftotext`, `pypdf` and `pdftoppm`. Ghostscript is installed at `/opt/homebrew/bin/gs`. This extracted all seven pages in one command:

```
curl -sL -A "<browser UA>" -o linkedin.pdf "https://business.linkedin.com/content/dam/business/talent-solutions/global/en_us/c/pdfs/Ultimate-List-of-Hiring-Stats-v02.04.pdf"
/opt/homebrew/bin/gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite -sOutputFile=linkedin.txt linkedin.pdf
```

The URL 301s to `https://delivery-p143253-e1476319.adobeaemcloud.com/adobe/assets/urn:aaid:aem:6af3957c-5b75-43f4-8bcc-e108cee9b401/original/as/original.pdf`, HTTP 200, 314,131 bytes, seven pages.

Two facts the extraction settled, both of which the refresh had reported the opposite of:

1. **The 4x figure is in the PDF**, page 4, under the "Candidate Experience" heading: "Talent is 4x more likely to consider your company for a future opportunity when you offer them constructive feedback."
2. **The PDF dates itself throughout.** Page 3 (Referrals) prints "Global Talent Trends, 2015" and "Why & How People Change Jobs, 2015". Page 4 prints "Global Talent Trends, 2015". Page 5 adds "LinkedIn data, 2015" and "Savvy Recruiter's Career Guide, 2015". Page 6 prints "The Recruiter's Guide To Writing Effective InMails, 2014" and "LinkedIn data, 2014".

## HIGH 1, block `0721197a0496`: the sourced claim is restored

The refresh had replaced a claim about **giving feedback** with one about **holding an award**, inside a paragraph whose whole point is that giving feedback fills your pipeline. Different subject.

**Was, after the refresh:** "Leaving a positive impression on candidates is integral to filling your talent pipeline. [The CandE Benchmark Research](https://survale.com/candes/) reports that candidates at CandE award-winning employers are 26% more likely to apply to your other jobs."

**Now:** "Leaving a positive impression on candidates is integral to filling your talent pipeline. [The LinkedIn study above](PDF), on 2015 Global Talent Trends data, found talent is 4x more likely to consider your company for a future opportunity when you offer them constructive feedback."

Three notes on the wording. The anchor is back to "LinkedIn study above", the 2022 original's phrasing, so this reads as a restoration rather than new prose. The claim now takes the source's own words, "consider your company for a future opportunity"; the 2022 original said "apply to your company again", which is a stronger claim than LinkedIn makes, so the restoration is the source's version, not the original's. And the sentence carries 2015, per rule 2.

markDefs on this block were set to the single entry `48ac5f0c7663` holding the LinkedIn PDF, reusing the key this document already gives that URL on blocks `5b715b852846` and `f32d26a09fd0`. The Survale markDef `c4e1a7b90d32` went with the claim it supported rather than being left as an orphan.

The Survale 26% was verified before being retired, and it is real: `https://survale.com/candes/` states "26% Candidates at CandE winner companies are 26% more likely to apply to your other jobs" under "What the Research Shows". It was retired for being the wrong subject, not for being wrong. It was also added by the refresh and never in the published post, so retiring it drops nothing the post originally carried. Recorded in QUESTIONS as the alternative if Jessica would rather not carry a 2015 figure.

## HIGH 2, the 2015 data presented as undated

Two places, both fixed.

**Block `f32d26a09fd0`**, the held referrals claim. The figure is held under rule 4 and is untouched; only the year was added. The link span lost its trailing comma so the year could sit outside the anchor.

- Was: "According to a [LinkedIn survey,](PDF) referrals are the top way people discover a new job."
- Now: "According to a [LinkedIn survey](PDF) from 2015, referrals are the top way people discover a new job."

**Image `d7ef9507c4ee`, altText.** The refresh's new alt was accurate to the pixels but wrote five 2015 statistics into the accessible text layer with no date, where an answer engine reads them as current: 10x talent pool, 35/32/26/6% referral motives, 46% InMail acceptance. The alt now opens "carrying five 2015 findings" and closes by separating what the card shows from where the date comes from: "The card prints "Source: business.linkedin.com" and no date; the PDF it is taken from attributes this page to LinkedIn Global Talent Trends 2015 and Why & How People Change Jobs 2015." That keeps rule 5 intact, the alt still states only what the graphic shows as the graphic's content, and sources the date to the document rather than to the pixels.

## MED 1, block `205f502889fe`: the anchor now names what it links to

The finding is right that `candidate-experience-institute.com` is an editorial content site rather than Talent Board, Survale or ERE, and that the article cites no primary CandE figure. Re-fetched and re-read in full: the page **does** state the claim verbatim, "organisations with a three- to five-day disposition window see higher offer acceptance, stronger re-application rates and more positive post-rejection feedback", so rule 1 is met and the sentence is not a fabrication.

What was a defect on its own terms is the anchor. It read "2025 CandE Benchmark Research", which promises the reader the research and delivers a third-party blog. Span `965eb406276c` now reads "Candidate Experience Institute's write-up of the 2025 CandE Benchmark Research". One span, no other change to the sentence.

One more thing the re-read turned up that the finding did not name: the article's own body calls its underlying report "the 2023-2024 research cycle" (66,000 candidates across 110 companies) while its headline calls it the 2025 benchmark. Recorded in QUESTIONS.

Whether the added clause should be on the page at all is left to Jessica. It is the one edit in this pass that added a claim rather than swapping a number, and the source is not primary. Three options are written out in QUESTIONS item 3: keep as it now stands, cut the clause and keep the bare "within three to five days", or revert to "within a week".

## MED 2, the false unreachability in QUESTIONS

Corrected at source. See the QUESTIONS changes below.

## LOW 1, the second copy of the dead Talent Board URL

Confirmed: markDef `a5cd19734542` on block `9bf4517e8e64` still holds `https://3cmsd11vskgf1d8ir311irgt-wpengine.netdna-ssl.com/wp-content/uploads/2021/12/2021-North-America-CandEs-Research-Report_12-14-2021.Final_.pdf`. That block has one child span carrying `marks: []`, so no span references the mark and it renders nothing. It is pre-existing, byte-identical to the published document.

**Not patched, deliberately.** Writing to a block to change something no reader can see is a write with no effect, and this build already has a finding against exactly that pattern on `/blog/first-impression-bias`. The defect is in this log's assertion that the dead URL was replaced, which is corrected here: **the refresh replaced the dead URL on block `5b715b852846` only; the orphaned copy on block `9bf4517e8e64` survives and was left as found.** QUESTIONS already carries this in its external-links section, so Jessica is not missing it.

## LOW 2, block `5b715b852846`: both ERE figures are NPS moves

ERE re-fetched and the quotes confirmed verbatim: "When specific feedback was given to candidates, their willingness to refer others **NPS rating** increased by over 50% in 2024. Their willingness to increase their relationship with the employer **NPS rating** increased by 20%."

The refresh's prose dropped "NPS rating" from both, which turns a move in a score into a move in the thing the score measures. The same article shows an NPS of 13 to 23 described as "56% higher", so the two are not interchangeable. The sentence now reads "their **NPS rating for** willingness to increase their relationship with the employer rose 20%, and their **NPS rating for** willingness to refer others rose by over 50%". The year stays on the anchor, "The 2024 CandE Benchmark Research".

Carried-over imprecision from the 2022 original rather than something the refresh introduced, but it is a rule 1 problem either way: the cited page does not state what the sentence said.

## LOW 3, the template link and the missing space

Two separate things in block `4ceb87a4d79a`.

**Fixed:** span `73ae0ff5f8dd2` was `"template."` following a link span ending `"matrix"`, rendering "interview scoring matrixtemplate". Now `" template."`. Pre-existing, one character, no risk.

**Not fixed, and recorded as Jessica's call:** the link still points at `https://www.polymer.co/blog/behavioral-interview-scoring-matrix`, a post, while the sibling refresh repointed its own call to action at `https://www.polymer.co/behavioral-interview-scoring-matrix.xlsx`. Repointing now would ship a dead link, because that .xlsx returns 404 until `seo-phase-8-faq` deploys, and tab 13 row 4's scope for this post is "Refresh examples; answer-first blocks", which does not cover templates. QUESTIONS item 7.

## Full re-read of the draft, for anything the findings did not name

Whole document read again block by block after patching, plus these mechanical checks.

- **Every href resolved.** All 13 distinct hrefs and image `sourceUrl`s fetched: EEOC 200 with no redirect, `google.com/about/careers/applications/how-we-hire/` 200 with no redirect, the LinkedIn PDF 200 through its Adobe AEM 301, ERE 200, Survale 200, Candidate Experience Institute 200, and all seven `polymer.co` internal links 200 with zero redirects.
- **Em-dashes and en-dashes: zero**, across all 100 blocks and both alt-text fields, before and after the patch.
- **Nothing else stale.** No plan name, product name or pricing tier appears anywhere in this post. The eight "Instead of saying / Say" pairs carry no date, figure or named study, as the refresh found. Metadata untouched: `pageTitle` "8 Interview Feedback Examples and When to Use Them", `metaDescription` unchanged.
- **No neighbour moved under a figure.** The only paragraph whose figure changed subject is `0721197a0496`, and the restored claim is the one its surrounding sentences were written for: block `75699443ea8d` immediately after still reads "A diplomatic approach makes it possible to turn down a candidate and attract them for future roles that are a better fit", which follows from the feedback claim and did not follow from the award claim.
- **Diff verified.** A before-and-after dump of all 100 blocks differs in exactly the six intended places and nowhere else.

## QUESTIONS-FOR-JESSICA.md changes

Five entries corrected in place, plus two added. Every one of them was something Jessica would otherwise have decided on.

| Entry | Was | Now |
|---|---|---|
| "Images that need regenerating", the LinkedIn card, "Where the old figure comes from" | "the PDF carries no publication date, and its text could not be extracted for verification on this machine" | Both statements marked false and corrected, with the PDF's own printed source lines quoted and the Ghostscript command named. States that the card is 2015 data and that both consequences are fixed |
| Same entry, "The decision that is yours" | "the sentence was left exactly as it was" | Amended: the claim is still held, but the sentence now carries "from 2015" |
| "Content refresh" item 2 | "One replacement figure deliberately carries no year", built on the false reason that the 4x could not be verified | Withdrawn and reversed. Quotes the PDF page 4 line, explains why the Survale 26% was a different subject, prints the restored sentence, and leaves Jessica only the real question: whether a 2015 figure belongs on the page |
| "Content refresh" item 3 | Disclosed the source's independence | Amended: the claim is confirmed verbatim on the page, the anchor now names the publisher, the article's own 2023-2024 cycle wording is surfaced, and three options are spelled out |
| Held-figure table row for `d7ef9507c4ee` | Quoted the prose without a year; old value undated | Row updated to the shipped prose, and the old value now states the figures are 2015 with the PDF's printed attribution |
| "Corrections from verification" items 1 and 2 | Open findings | Marked RESOLVED with what shipped |
| "Content refresh" items 6 and 7 | Did not exist | New: the NPS fix, and the template-link divergence as Jessica's call |

## Files

- Draft patched: `drafts.a4d5d182-0025-4911-8bf7-d7b8e888e62a`, revision `QzNVnRn1RN9Wy2ys8Qp9n3` to `QzNVnRn1RN9Wy2ys8Qu8WV`
- `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
- No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was touched
