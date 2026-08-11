# Refresh log: `/blog/first-impression-bias`

Tab 01 row 15 ("Strengthen internal links; base for interview-bias guide", #1 for "first impression bias", 140 vol, crawlable only via one depth-4 path). Not on tab 13.

Sanity draft `drafts.a239b0d1-bad6-459f-98d1-b809d5a82dc7`, project `a6d1clb1`, dataset `production`. Patched, never published. Rev before `QzNVnRn1RN9Wy2ys8QjqeT`, rev after `guLb7mLdCgNrjUoWfCBlRW`.

"Base for interview-bias guide" was read as a note about future content, not an instruction. No new guide was written.

---

## What was already on the draft before this pass

`author` = `{_ref: "author-jessica-gertig"}`, left untouched per the brief. No `updatedDate`. `metaDescription` carried the phase-4 tab 12 rewrite ("How to identify and overcome first impression bias in hiring - plus how structured scoring and anonymized review reduce it.") and was not touched. `pageTitle` carried the phase-4 rewrite ("Overcome First Impression Bias When Hiring") and was not touched. `publishDate` `2023-05-09`. 123 content blocks.

## Survey

All 123 blocks were read in order, including the `toc` block and the `youtube` block, not skimmed for `%` and four-digit years. What the survey turned up:

| Where | What it said | Verdict |
|---|---|---|
| block `ceef6e30abd8` | "almost 3x more likely to innovate successfully", "1.6 times more likely to satisfy and retain their customers", "more likely to outperform their peers financially" | figures accurate but undated and one unlinked; dated and sourced |
| block `29b817a21a0c` | "assume they are intelligent", Wiley EJSP link | 1994 social-psychology paper, no figure in prose, timeless, left |
| block `bcf26dae2a8a` / `3f766250a1fc` | thedecisionlab affinity bias | 200, no figure, left |
| block `3bbc0fb8886b` | "Researchers in the UK ran a field experiment", no year, `http://` link | undated and insecure scheme; dated and upgraded |
| block `d014405cb1cf` | "60% more applications ... as many callbacks" | still the current published figure; source URL added |
| block `0a5c3f877326` / `de48f427d938` | thedecisionlab confirmation bias | 200, no figure, left |
| block `88b004f5d4ec` | "In 1951, Solomon Asch conducted a series of experiments" | historical, correctly dated, left |
| block `fc2deaa924e5` | "Even though the footage is now vintage, the findings are still relevant today" | claim about relevance, carries no figure, left |
| block `3127bca2b3bb` | cognitive debiasing, NCBI PMC6338148 | 200, academic, no figure, left |
| block `91b715dceefb` | miro.com brainwriting template | 200, product still exists, left |
| block `d1b777b256c0` | HBR 2016 candidate scorecards | 200, evergreen, left |
| block `83d2dc6faca7` / `4d4d117579c6` | "AI-powered technology will help you filter your candidates" and "The technology ignores demographic information" | a practice claim that has aged; recorded, not rewritten |
| block `713ccab2d174` | "interview scorecard" with no internal link | internal link added |
| block `d6d54406b5a0` | "interview questions" with no internal link | internal link added |
| block `b778cd1a9935` | NFP People 2016 scorecard image + `sourceUrl` | 200, image carries no figure the prose asserts, left |
| internal links | `polymer.co`, `/features`, `/blog/talent-acquisition`, `/blog/best-applicant-tracking-software` | all 200 |
| em-dashes | none in the post, before or after | nothing to fix |

## Figures replaced

**1. Intro, block `ceef6e30abd8`.**

Old: "Diversity is ideal for innovation. In fact, diverse companies are [almost 3x] more likely to innovate successfully. They're also 1.6 times more likely to satisfy and retain their customers and [more likely] to outperform their peers financially." The "almost 3x" linked to the DEI report PDF; the 1.6x had **no link at all**; "more likely" linked to McKinsey's *Diversity Wins* PDF.

New: "Diversity is ideal for innovation. In fact, [2021 research covering more than 800 organizations] found the companies with the strongest diversity and inclusion practices were 2.9x more likely to innovate successfully and [1.6x more likely] to satisfy and retain their customers. Diverse companies are also [more likely] to outperform their peers financially."

- **Both figures were verified against the linked source rather than taken on trust.** The linked PDF is *Elevating Equity: The Real Story of Diversity and Inclusion*, Josh Bersin Academy with Perceptyx, February 2021, survey fielded October and November 2020. WebFetch could not read it (binary) so the PDF was downloaded and its per-page text extracted with Ghostscript. **Figure 12 on page 20 states verbatim: "2.9x MORE LIKELY TO Innovate successfully", "1.6x MORE LIKELY TO Satisfy and retain customers", "1.6x MORE LIKELY TO Meet or exceed financial targets", "3.1x ... Effectively adapt to change", "2.6x ... Engage and retain the workforce", "4.3x ... Create a sense of belonging", "8.4x ... Be recognized for DEI by stakeholders", "21.1x ... Have diverse leaders, industry-leading DEI".** So "almost 3x" was 2.9x and the unlinked 1.6x was real. Methodology, page 3: "We surveyed more than 800 organizations, analyzed more than 80 different practices, and correlated them against a variety of outcomes". URL: https://ss-usa.s3.amazonaws.com/c/308463326/media/27436024f0b84dfd274918375735238/202102%20-%20DEI%20Report.pdf (200).
- **The 1.6x now carries the source URL it never had.** Same report, same figure, same link as the 2.9x.
- **The sentence now carries the year.** Both figures are 2021, and the page previously read as though they were current.
- **No 2026 figure exists for either claim.** The Bersin study has not been re-run. Searched for a newer edition and for 2026-published diversity-and-innovation or diversity-and-customer research: nothing. The nearest live alternatives are all older, not newer: BCG's 45%-vs-26% innovation-revenue split (2018), Kantar's Brand Inclusion Index (75% of consumers, 15 July 2024, 23,000 people in 18 countries, verified at https://www.kantar.com/north-america/company-news/three-quarters-of-consumers-say-inclusion-and-diversity-influence-their-purchase-decisions), McKinsey's *Diversity Matters Even More* (December 2023). Per-figure finding, recorded, not applied across the post.
- **The McKinsey clause and its link were left exactly as they were, deliberately.** See "Sources that could not be reached" below.

**2. Block `3bbc0fb8886b`, the UK field experiment.**

Old: "[Researchers in the UK ran a field experiment] sending resumes from hypothetical minority applicants..." with the link on `http://csi.nuff.ox.ac.uk/...`

New: "[Researchers in the UK ran a field experiment] **in 2016 and 2017**, sending resumes from hypothetical minority applicants..."

The study is the GEMM correspondence audit, Di Stasio and Heath, fieldwork 2016/17, reported by Oxford's Centre for Social Investigation in January 2019. The prose never said when. The link was also upgraded from `http://` to `https://csi.nuff.ox.ac.uk/wp-content/uploads/2019/01/Are-employers-in-Britain-discriminating-against-ethnic-minorities_final.pdf`, which returns 200 over TLS. The same orphaned `cf0e7bea5c1b` markDef sitting unused on block `7abaa7e9442e` was upgraded with it so the document does not carry two different hrefs under one key. **That reason is wrong, corrected 2026-08-07 in the Fix pass section below: markDefs are block-scoped, so two blocks holding the same key with different hrefs would have been legal and invisible.**

**3. Block `d014405cb1cf`, the 60% figure.**

Old: "The study found the minority group had to send 60% more applications to receive as many callbacks as the majority group based solely on their resume." No link, no year.

New: same sentence, with **"60% more applications" now linked** to https://www.compas.ox.ac.uk/article/whats-in-a-name-wage-inequalities-based-on-the-ethnic-minority-name-of-a-job-applicant

- **60% is still the current published value, and this is the most recent source that states it.** COMPAS (Oxford), 5 February 2025, Di Stasio, Fernández-Reino, van Oosten and Velásquez, exact wording: "Overall, ethnic minority applicants had to submit 60% more applications to receive the same number of positive callbacks as white British applicants."
- **No newer measurement exists.** The 2025 article restates the 2016/17 GEMM audit rather than reporting new fieldwork; its own successor study (EqualStrength) says results "will be published on the COMPAS website once our fieldwork is complete". The LSE blog covering the same research (19 January 2021, Zwysen, Di Stasio and Heath) gives odds ratios, not an applications multiplier. The year now sits on the sentence before it, so the figure cannot read as newer than it is.

## Figures held behind a graphic

**None.** All nine images (the feature image plus eight in-content) were downloaded from the Sanity CDN at 1400px wide and viewed at full size. **Not one of them carries a figure the prose asserts**, so no figure on this post is held and there is no entry for it under "Images that need regenerating" in QUESTIONS-FOR-JESSICA.md. All three replaced or dated figures live in prose only.

What the images do assert as pixels, recorded for completeness:

- feature image: no text, no figures. A white outlined eye with a stopwatch in place of its iris, on black.
- `4da691a2c677`: yourbias.is card, "The halo effect", definition text, no numbers.
- `84e46dbb9c04`: yourbias.is card, "Groupthink", definition text, no numbers.
- `6ca7d14a09b8`: Asch line task. Reference bar labelled "Line"; comparison bars A, B, C. **A is the same height as the reference, B taller, C shorter, which is what block `dabd18b1b565` claims ("the matching line is line A"). Verified against the picture, not assumed.** No numbers.
- `f7e38b6725ad`: yourbias.is card, "The framing effect", definition text, no numbers.
- `8148b3a933ea`: Miro board, sticky notes labelled Participant 1 to Participant 6, Idea #1 to #3, two "Improvement" notes. No numbers the prose uses.
- `ba7117080b81`: Polymer pipeline, iOS Developer at Tablespace Games. Stage counts Inbox 11, Screen 19, Interview 4, Decide 1, Offer 0, Archive 4. Eleven candidate names. "Application received · 2d". These are demo data, not claims the prose makes.
- `11fdd9fa43c8`: Polymer Account settings, job board content. "Seeking new adventurers!", the 280-character intro cap, "Display when jobs were published: Yes". Demo data.
- `b778cd1a9935`: NFP People scorecard. Four columns, eleven criteria rows, every scoring cell blank, final row "FINAL SCORE:". No numbers at all.

## Alt text written

All written from what the graphic shows, not from the surrounding paragraph. Eight of the nine had alt starting "Screenshot of ..." and naming the source rather than describing the picture, which tells an answer engine nothing.

| Block | Before | After (opening) |
|---|---|---|
| `featureImage.altText` | "First Impression Bias Header Image" | "A white outlined eye with a stopwatch face in place of its iris, its needle pointing straight up, on a solid black background..." (185 chars) |
| `4da691a2c677` | "Screenshot of The Halo Effect by Sourcebias.is" | "Card from yourbias.is titled 'The halo effect', with a smiling-face-with-halo emoji above the definition..." (256 chars, carries the definition verbatim) |
| `84e46dbb9c04` | "Screenshot of Groupthink by Sourcebias.is " | "Card from yourbias.is titled 'Groupthink', with a sheep emoji above the definition..." (214 chars, carries the definition verbatim) |
| `6ca7d14a09b8` | "Screenshot of The Result of Asch experiments on the individual's tendency to conform to the group's opinion" | "Diagram of the Asch conformity task, headed 'Which line is the same length as the line on the left?'..." (402 chars, states which bar matches, which is the whole point of the graphic and was previously invisible to a screen reader) |
| `f7e38b6725ad` | "Screenshot of The Framing Effect by Sourcebias.is " | "Card from yourbias.is titled 'The framing effect', with a framed-picture emoji above the definition..." (222 chars, carries the definition verbatim) |
| `8148b3a933ea` | "Screenshot of Miro Brainwriting Template" | "Screenshot of a Miro whiteboard set up for brainwriting. Sticky notes are laid out in a grid six columns wide..." (596 chars, carries every note label) |
| `ba7117080b81` | "Screenshot of Polymer Hiring Platform Inbox Page " | "Screenshot of the Polymer hiring pipeline for an iOS Developer role at Tablespace Games..." (767 chars, carries all six stage counts and the panel contents) |
| `11fdd9fa43c8` | "Screenshot of Polymer Hiring Platform Job Board Content " | "Screenshot of Polymer's Account settings, open on the Content tab for the job board at jobs.tablespace.games..." (722 chars, carries every field value including the intro copy verbatim) |
| `b778cd1a9935` | "Screenshot of Interview Scorecard that includes predetermined criteria" | "A blank interview scorecard laid out as a table with four columns: Job Criteria, Criteria Weighting, Candidate Assessment and Total Score..." (846 chars, carries all eleven criteria rows) |

The three original alt strings said "Sourcebias.is", which is not a real domain. The site is `yourbias.is`, which is what the graphics themselves say and what their `sourceUrl` fields point at. Two of them also carried a trailing space. Both fixed by the rewrite.

## Internal links added

Tab 01 row 15's instruction. Two links added where the existing prose already supported one. No sentence was invented to hang a link on, and no existing link was repointed.

| Block | Anchor | Target | Why |
|---|---|---|---|
| `d6d54406b5a0` | "interview questions" | https://www.polymer.co/blog/problem-solving-interview-questions | The bullet already says "Prepare your interview questions in advance". The target is tab 01 row 7, the site's #1 traffic asset and itself orphaned. |
| `713ccab2d174` | "interview scorecard" | https://www.polymer.co/blog/behavioral-interview-scoring-matrix | The bullet is entirely about interview scorecards and already links out to the ATS post. The target is tab 01 row 8, orphaned, and now carries the downloadable scorecard template. |

Both targets return 200. Both are on tab 01's orphan list, so the links do double duty: they strengthen this page and they add an inbound link to a page that needed one.

Candidates considered and rejected as forced: `/blog/interview-feedback-examples` on block `cc9c3cc239be` ("everyone discusses the feedback" is committee discussion, not candidate feedback); `/blog/a-player` on block `7abaa7e9442e` ("another more-qualified jobseeker"); `/blog/employee-turnover` on block `0a5c3f877326` ("resentment starts to fester").

## Byline and date

`updatedDate` set to `2026-08-06`. `author` left as `author-jessica-gertig`, the assignment already on the draft. `publishDate` left at `2023-05-09`.

## Not done, deliberately

- **No restructuring.** The post is #1 for "first impression bias". No answer-first blocks, no new sections, no new prose beyond the sentences carrying the dated or replaced figures.
- **No interview-bias guide.** Tab 01 row 15's "base for interview-bias guide" is a note about future content.
- **The AI-screening passage was not rewritten.** Blocks `83d2dc6faca7` and `4d4d117579c6` claim AI filtering "ignores demographic information that humans may unintentionally discriminate against, such as race, gender, and age". That is a product claim and a claim about AI hiring tools generally, and the regulatory and evidence picture around it has moved since 2023. It carries no dated figure, so it is not a staleness fix; it is an editorial and product decision. Recorded in QUESTIONS-FOR-JESSICA.md.
- **The "A-players" anchor was left pointing at `/blog/talent-acquisition`.** Block `d1b777b256c0`'s anchor text is "A-players" and `/blog/a-player` exists and returns 200. Repointing an existing link is a change to editorial work someone already did, not the addition tab 01 asked for. Recorded rather than done.
- **An orphaned markDef was left in place.** Block `7abaa7e9442e` carries markDef `cf0e7bea5c1b` that no span in that block uses, so it renders nothing. Its href was upgraded to https alongside the live one; the entry itself was not deleted. **The reason given for the upgrade was wrong; see the Fix pass section.**

## Sources that could not be reached

**`mckinsey.com` is completely unreachable from this environment.** Both the article page and the PDF were tried repeatedly:

- https://www.mckinsey.com/~/media/mckinsey/featured%20insights/diversity%20and%20inclusion/diversity%20wins%20how%20inclusion%20matters/diversity-wins-how-inclusion-matters-vf.pdf (the link currently in block `ceef6e30abd8`): curl fails with `HTTP/2 stream 1 was not closed cleanly: INTERNAL_ERROR`.
- https://www.mckinsey.com/featured-insights/diversity-and-inclusion/diversity-matters-even-more-the-case-for-holistic-impact: WebFetch times out at 60s; curl over HTTP/2, over HTTP/1.1, with full browser headers, and a bare HEAD request all time out at 45 to 90 seconds with zero bytes received.

That matters twice over. It means **the existing link was not repointed** at the newer report, because pointing a live page at a URL that cannot be verified is worse than leaving a working one. And it means **McKinsey's current figure was not written into the post**, because rule 1 says a figure you cannot reach a source for does not get written. Recorded in QUESTIONS-FOR-JESSICA.md with the figure and where it lives.

Also blocked, none of them load-bearing:

| URL | Status | Consequence |
|---|---|---|
| https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.2420240606 | 403 to curl with a desktop Chrome UA | bot block, not a dead page; no figure hangs on it; left |
| https://www.bcg.com/publications/2018/how-diverse-leadership-teams-boost-innovation | 403 to WebFetch | not cited by this post; was checked only as a possible replacement figure |
| https://instituteforpr.org/why-diversity-matters-more-than-ever/ | 403 to WebFetch | secondary source for the McKinsey figure; not used |

## Sources reached and their status

| URL | Status |
|---|---|
| https://ss-usa.s3.amazonaws.com/c/308463326/media/27436024f0b84dfd274918375735238/202102%20-%20DEI%20Report.pdf | 200, Bersin/Perceptyx Feb 2021, Figure 12 read directly, both figures confirmed |
| https://csi.nuff.ox.ac.uk/wp-content/uploads/2019/01/Are-employers-in-Britain-discriminating-against-ethnic-minorities_final.pdf | 200 over https, link upgraded from http |
| https://www.compas.ox.ac.uk/article/whats-in-a-name-wage-inequalities-based-on-the-ethnic-minority-name-of-a-job-applicant | 200, 5 Feb 2025, new citation on the 60% |
| https://blogs.lse.ac.uk/politicsandpolicy/ethnic-penalties-and-hiring-discrimination/ | 200, 19 Jan 2021, checked for a newer figure, gives odds ratios only |
| https://www.kantar.com/north-america/company-news/three-quarters-of-consumers-say-inclusion-and-diversity-influence-their-purchase-decisions | 200, 15 July 2024, checked as a replacement, not used |
| https://thedecisionlab.com/insights/business/one-unconscious-bias-is-keeping-women-out-of-senior-roles | 200 |
| https://thedecisionlab.com/biases/confirmation-bias | 200 |
| https://yourbias.is/the-halo-effect | 200 |
| https://yourbias.is/groupthink | 200 |
| https://yourbias.is/the-framing-effect | 200 |
| https://practicalpie.com/asch-line-study/ | 200 |
| https://www.youtube.com/watch?v=TYIh4MkcfJA | 200 |
| https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6338148/ | 200 |
| https://miro.com/templates/brainwriting/ | 200 |
| https://hbr.org/2016/02/a-scorecard-for-making-better-hiring-decisions | 200 |
| https://nfppeople.com.au/2016/09/the-best-way-to-rate-candidate-interviews-at-your-nfp/ | 200 |
| https://www.polymer.co/ | 200 |
| https://www.polymer.co/features | 200 |
| https://www.polymer.co/blog/talent-acquisition | 200 |
| https://www.polymer.co/blog/best-applicant-tracking-software | 200 |
| https://www.polymer.co/blog/problem-solving-interview-questions | 200, new internal link |
| https://www.polymer.co/blog/behavioral-interview-scoring-matrix | 200, new internal link |
| https://www.polymer.co/blog/a-player | 200, considered, not linked |
| https://www.polymer.co/blog/interview-feedback-examples | 200, considered, not linked |
| https://www.polymer.co/blog/employee-turnover | 200, considered, not linked |

---

## Fix pass

2026-08-07. Four verifier findings on this post, all LOW. One fixed, one rejected with evidence, one left as Jessica's decision, one corrected as a wrong rationale in this log. One thing the findings did not name was found on the re-read and fixed, and one false statement in `QUESTIONS-FOR-JESSICA.md` was found and corrected.

Draft `drafts.a239b0d1-bad6-459f-98d1-b809d5a82dc7`. Rev before `guLb7mLdCgNrjUoWfCBlRW`, which is the rev this log recorded yesterday, so nothing had touched the draft in between. Rev after `guLb7mLdCgNrjUoWfCGTa1`. One patch, two `set` operations on keyed paths inside `content`, guarded with `ifRevisionId`. The published document was not touched and nothing was published.

### Finding 1, the intro rewrite changed meaning as well as date. Jessica's call, already recorded, nothing changed

The verifier is right that block `ceef6e30abd8` moved from "diverse companies are almost 3x more likely to innovate successfully" to "the companies with the strongest diversity and inclusion practices were 2.9x more likely", and that this is a change of subject (headcount diversity to DEI practice maturity), not only a date. It is also right that this is not a defect: it is the faithful reading of the source, and it was disclosed as an explicit decision rather than made silently.

Both of the source findings the verifier cites were confirmed directly in the PDF text, not taken on trust: `gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite` on the downloaded report prints "Finding 9. DEI excellence absolutely does drive" and "Finding 10. Inclusion is the goal; diversity is the", and page 2 of the report reads "inclusion is the goal and diversity is the result".

`QUESTIONS-FOR-JESSICA.md` item 2 already states the change, names the source's own reasoning for it, and ends "If you would rather it kept the looser 'diverse companies' phrasing, say so." That is the whole decision, correctly framed, so nothing was rewritten into a preferred shape. The post is unchanged.

### Finding 2, "more than 800 organizations" overstates the sample. Rejected, with the source text

The verifier read two of the report's four statements about its own sample and concluded the survey unit is respondents rather than organizations. The other two say the opposite, and one of them ties responses to organizations one-to-one. All four, extracted from the PDF with Ghostscript:

- Executive summary: "We surveyed more than 800 organizations, analyzed more than 80 different practices, and correlated them against a variety of outcomes"
- Maturity model section: "We arrived at these levels based on the more than 800 responses we received to our survey and the practices implemented by their organizations"
- Conclusion: "the database of over 800 organizations globally"
- Methodology appendix: "We received responses from more than 800 people across all industries, geographies and company sizes"

So the report describes its sample as more than 800 organizations three times, once in the same sentence as the responses, and as more than 800 people once. "2021 research covering more than 800 organizations" is the source's own framing of its own sample, not an overstatement the post introduced. No change.

### Finding 3, two clauses in the scorecard alt assert things the pixels do not show. Fixed

Verified rather than accepted: the asset was downloaded from the Sanity CDN at 1400px and viewed at full size, and the serializer was read. `SourceRenderer` in `/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/blog/[slug].js` renders `<figcaption>Source: <a href={value.sourceUrl}>{value.source}</a></figcaption>` for any image block carrying both fields, and `ImageRenderer` passes `alt={value.alt}` and then renders `SourceRenderer` beneath it. So the attribution is already a caption in the DOM, and repeating it in the alt makes a screen reader say it twice. The picture also carries no visible credit of any kind, and it names no role: the eleven criteria rows describe youth residential work, but "for a youth residential support role" is an inference the graphic never states.

Both clauses removed. `content[_key=="b778cd1a9935"].alt` before and after differ only by the deletion of ` for a youth residential support role` and ` Credited to NFP People.`; the eleven criteria rows, the four column headings and the "FINAL SCORE:" row are unchanged, and all eleven were checked against the image again.

The four `yourbias.is` and `practicalpie.com` cards were checked for the same defect and do not have it. The halo effect card was downloaded and viewed: it prints "Source: yourbias.is" in its own bottom right corner, in the pixels, which is what its alt says. Describing a credit that is part of the picture is what alt text is for. Left alone.

### Finding 4, the markDef rationale was wrong. Correct, and the log is fixed

Portable Text markDefs live on their own block and are addressed by span `marks` within that block, so "the document does not hold two different hrefs under one key" was never a real risk. This document proves it: seven markDef keys are already duplicated across adjacent block pairs, carrying identical hrefs but with no mechanism that would have required them to match. `c43caec5300a` on blocks `b3c2debc6147` and `29b817a21a0c`, `3a37307e6195` on `bcf26dae2a8a` and `3f766250a1fc`, `855495e4f2f5` on `0a5c3f877326` and `de48f427d938`, `0f4c69677bce` on `be8624a60a08` and `91b715dceefb`, `42c920db08c2` and `c642133abb9c` on `b03155f62015` and `d1b777b256c0`, `1b0310bbac4d` on `1ab533f772b7` and `6a271df63bfe`, `34b98f33562b` on `2d9688bcab23` and `f5c745ffd994`.

The write itself was harmless and http to https is an improvement, so it was not reverted; reverting a working scheme upgrade to satisfy a bad reason would be the wrong fix. The two places in this log that stated the bad reason now say so inline.

### Found on the re-read, not named by any finding

**1. The live page prints "Source: Source: NFP People". Fixed.** Block `b778cd1a9935` carried `source: "Source: NFP People"`, and `SourceRenderer` prefixes "Source: " itself. Confirmed on the published page: `curl https://www.polymer.co/blog/first-impression-bias | grep -o "Source: [^<]*"` returns five bare `Source: ` figcaption prefixes and then `Source: NFP People` as the anchor text inside one of them. Every other image block on this post holds a bare name in that field ("Yourbias.is", "Practical Psychology"). Set to `NFP People`. The published document still holds the doubled value; it goes away when the draft is approved.

**2. `mckinsey.com` is not unreachable, and `QUESTIONS-FOR-JESSICA.md` said it was in two places. Corrected.** This log's "Sources that could not be reached" section, item 1 of the post's section in `QUESTIONS-FOR-JESSICA.md`, and the post's row in that file's "Figures that could not be reached" table all said McKinsey could not be verified. curl does still fail on both URLs with `HTTP/2 stream 1 was not closed cleanly: INTERNAL_ERROR`, retested today. A browser gets both:

- `https://www.mckinsey.com/featured-insights/diversity-and-inclusion/diversity-matters-even-more-the-case-for-holistic-impact` loads, title "Why diversity matters even more | McKinsey", byline and `itemdate` meta both **2023-12-05**. Read off the page: the report "drew on our largest dataset yet", "spanning 1,265 companies, 23 countries, and six global regions"; "Our 2015 report found top-quartile companies had a 15 percent greater likelihood of financial outperformance versus their bottom-quartile peers; this year, that figure hits 39 percent"; and "A strong business case for ethnic diversity is also consistent over time, with a 39 percent increased likelihood of outperformance for those in the top quartile of ethnic representation versus the bottom quartile".
- The *Diversity Wins* PDF the post currently links, fetched from within a page on mckinsey.com, returns **200, `application/pdf`, 11,207,111 bytes, no redirect**. The citation the post carries is live.

**The post was not changed.** The clause reads "Diverse companies are also more likely to outperform their peers financially" and carries no figure, so nothing about it is stale and rule 2 does not bite. Putting "39%" into the opening paragraph of the site's number one ranking post is an editorial call, and the item in `QUESTIONS-FOR-JESSICA.md` has been rewritten so that it is now the only thing left in it. Both false entries in that file are corrected in place, and a fifth entry has been added under "Corrections from verification to entries already in this file" so the record of what was believed when survives.

### Re-read of the whole draft, everything else

All 123 blocks read again in order against the current draft, not the yesterday's dump.

- Em-dashes: zero. `—` and `–` both return 0 occurrences across the serialized document.
- Every source URL re-fetched today: `compas.ox.ac.uk` 200, `csi.nuff.ox.ac.uk` 200, `nfppeople.com.au` 200, `ncbi.nlm.nih.gov` 200, `hbr.org` 200, `polymer.co/blog/problem-solving-interview-questions` 200, `polymer.co/blog/behavioral-interview-scoring-matrix` 200.
- The COMPAS page still states the claim the sentence makes, verbatim: "Overall, ethnic minority applicants had to submit 60% more applications to receive the same number of positive callbacks as white British applicants."
- Both Bersin figures re-read in the PDF text, not from yesterday's note: Figure 12 prints "2.9x MORE LIKELY TO Innovate successfully" and "1.6x MORE LIKELY TO Satisfy and retain customers".
- Product and plan names: Polymer, Miro and the yourbias.is cards are all current. No plan or tier name appears anywhere on the post.
- `updatedDate` left at `2026-08-06`. This pass corrected an alt text and a caption field and changed no prose, so moving the visible "Updated" byline would overstate it.
- `author` still `author-jessica-gertig`, `publishDate` still `2023-05-09`, `metaDescription` and `pageTitle` untouched.
