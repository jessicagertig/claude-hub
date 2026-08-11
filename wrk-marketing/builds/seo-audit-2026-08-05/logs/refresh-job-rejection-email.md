# Refresh log: `/blog/job-rejection-email`

Tab 13 row 6 ("Light touch; keep rankings", #1 for "sample job rejection email", 140 vol). Tab 01 row 11 ("Link + light refresh").

Sanity draft `drafts.35e36b52-728b-4eb1-b7d9-ed2003c4d1a5`, project `a6d1clb1`, dataset `production`. Patched, never published. Rev before `QzNVnRn1RN9Wy2ys8Qjpr7`, rev after `kJ3OpIOJnJS2LKJpQpeqfF`.

---

## What was already on the draft before this pass

`author` = `{_ref: "author-corey-daniels"}`, left untouched per the brief. No `updatedDate`. `pageTitle`, `editorialTitle`, `metaDescription` and `slug` all carried their published values and were not touched. 117 content blocks.

(This sentence originally read "all carried earlier-phase values", which implied a phase-4 metadata rewrite this post never received. Corrected in the fix pass; see "Reporting error corrected" below.)

## Survey

The whole post was read block by block, all 117 blocks including the four `quote` template blocks and the `toc` block, not skimmed for `%` and four-digit years. What the survey turned up:

| Where | What it said | Verdict |
|---|---|---|
| block `548a11a76a45` | "60% of candidates never hearing back after a job interview and 75% never receiving a reply" | dated, replaced |
| block `fb02c10dfe45` / `ce38bb809382` | Edelman 2021 brand trust link, no figure in prose | source unverifiable, no figure, left, recorded |
| block `989d8b0e9827` | "as many as six applications before getting an interview", BLS 2020 | dated, replaced |
| block `91667522cc48` | brandingreference.com core values, no figure | live (200), no figure, left |
| block `299dec2a9e58` | Virgin Media "$5 million annually", no year | wrong figure and undated, corrected and dated |
| block `3b8862ea1efb` | Virgin Media 18% / two-thirds / 6% | 18% and 6% correct; two-thirds misattributed, corrected |
| block `57035b239c1c` | Grammarly tone detector | live (200), product still exists, practice unchanged, left |
| blocks `29516148696b`-`8fe8ca25cb0d` | Intel case study, Shira Ben-Cohen | Medium source live, 2 June 2020, no figures, left |
| blocks `a5d23fc46827`, `bf35991a0e5e`, `5bbe2d27fd6a`, `57c2bb88d8b5` | the four email templates | timeless, no dated content, left |
| block `e595dfb64422` | "went viral on Twitter" | true of a July 2021 post, left; date now in the alt text |
| internal links | `/blog/a-player`, `/blog/talent-acquisition`, `/features`, `/blog/behavioral-interview-scoring-matrix` | all 200 |

## Figures replaced

**1. Intro, block `548a11a76a45`.**

Old: "With 60% of candidates never hearing back after a job interview and 75% never receiving a reply to their application, most job seekers report a negative experience with potential employers." The 60% was linked to https://www.hci.org/blog/statistics-rethink-your-candidate-experience-or-ruin-your-brand (live, 200, but undated and citing mid-2010s research). The 75% had no source.

New: "With 53% of job seekers ghosted by an employer in the past year and 67% of applications getting no response at all in 2026, most job seekers report a negative experience with potential employers."

- **53%**. Criteria's 2026 Candidate Experience Report, a three-year high, up from 38% in 2024. Stated at https://www.entrepreneur.com/business-news/job-seekers-are-getting-ghosted-in-record-numbers (2 April 2026). Criteria's own public pages do not state it: https://www.criteriacorp.com/research/2026-candidate-experience-report, https://www.criteriacorp.com/candidate-experience-report-findings-2026 and the 10 March 2026 press release all carry the 68% resume figure and the 20% optimism figure and stop short of the ghosting number, which is inside the gated PDF. Fortune published the same figure on 20 March 2026.
- **67%**. United Way of the National Capital Area, survey of 1,000 U.S. job seekers fielded 26 February to 7 March 2026, https://unitedwaynca.org/blog/how-long-does-it-take-to-find-a-job-2026-survey/, exact wording "on average, they said 67% of their applications got no response at all".

The first clause changed scope, from post-interview to any stage, because no general 2026 post-interview figure is published. What exists: 61% post-interview, but that is Greenhouse **December 2024**, which every 2026 aggregator recycles without saying so; and 51% never heard back after an **AI** interview, Greenhouse's 2026 Candidate AI Interview Report, 1 May 2026, https://www.greenhouse.com/newsroom/63-of-job-seekers-have-faced-an-ai-interview-most-havent-had-a-good-one-yet, n=2,950. Also checked: LiveCareer via HR Brew 30 July 2026, 45% ghosted at some point with 22% after at least one interview, https://www.hr-brew.com/stories/nearly-half-of-job-seekers-say-theyve-been-ghosted-by-employers. The 53% was chosen as the only 2026 figure that carries the same "employers go silent" claim across the whole funnel. Recorded as a decision in QUESTIONS-FOR-JESSICA.md.

(**"No general 2026 post-interview figure is published" is false**, and the LiveCareer 22% named two sentences earlier in this same paragraph is one of the two that are. The clause has been reverted to a post-interview measure and the 53% is off the page; see "MED: the categorical negative in QUESTIONS-FOR-JESSICA.md was false" under "Fix pass" below.)

**2. Block `989d8b0e9827`.**

Old: "With the average U.S. job applicant sending as many as six applications before getting an interview, people dedicate a lot of time to finding a new role." Linked to https://www.bls.gov/opub/btn/volume-9/how-do-jobseekers-search-for-jobs.htm, BLS Beyond the Numbers vol. 9, 2020. That URL returns 403 to curl with a browser user agent and to WebFetch, which is bls.gov blocking automated traffic, not proof the page is gone.

New: "With the average U.S. job seeker submitting 62.6 applications and landing just five interviews in 2026, people dedicate a lot of time to finding a new role." Same United Way 2026 survey, exact wording "job seekers submitted 62.6 applications, but landed just five interviews". Link repointed from BLS to United Way.

This also fixed a run-together typo the original carried: "six applicationsbefore getting an interview".

**3. Block `299dec2a9e58`.**

Old: "Graeme Johnson, Virgin Media's Head of Resourcing, discovered a lousy candidate experience cost the business $5 million annually in lost revenue." No year. Figure linked to the YouTube talk.

New: "In 2016, Graeme Johnson, Virgin Media's Head of Resourcing, revealed that a lousy candidate experience cost the business $5.4 million annually in lost revenue."

Source: https://www.linkedin.com/business/talent/blog/talent-acquisition/bad-candidate-experience-cost-virgin-media-5m-annually-and-how-they-turned-that-around (LinkedIn Talent Blog, 15 March 2017), which states "£4.4 million per year, the equivalent of $5.4 million" and "123,000 rejected candidates each year". The year comes from the talk's own title, confirmed at https://www.youtube.com/watch?v=SfnQWPHGH8A: "The Commercial Impact of Candidate Experience - Graeme Johnson - Talent Connect 2016".

The link on the figure was repointed from the YouTube URL to the LinkedIn article, because the YouTube embed already sits in the next block (`d0ef9f076429`) and a text source is what the figure needs.

**4. Block `3b8862ea1efb`.**

Old: "Out of rejected candidates, 18% were also customers, and two-thirds of those applicants were detractors."
New: "Out of rejected candidates, 18% were also customers, and around two-thirds were detractors."

The source says around two-thirds of all rejected candidates were detractors, not two-thirds of the 18% who were customers. The 18% and the 6% who cancelled within a month are both correct as the post had them and were left.

## Figures held behind a graphic

**None.** All seven images were viewed at full size from the Sanity CDN. None of them carries a figure the prose asserts, so no figure on this post is held and there is no entry for it under "Images that need regenerating" in QUESTIONS-FOR-JESSICA.md. The four replaced figures appear in prose only.

What the images do assert as pixels, recorded for completeness:

- `e595dfb64422`: tweet timestamp 4:10 PM Jul 29, 2021; 960.5K likes; 4.7K replies.
- `2ff5f43f9538`: Polymer stage counts Inbox 1, Screen 3, all other stages 0.
- `f49ddff86623`: Grammarly Tone Detector rating a sample message Confident, Joyful, Optimistic.
- `2297adf503aa`: Google Sheets sample Date cell reads 7/11/2022; scoring scale 1 to 5.
- `a58002381e76`: Intel email, Job Application Date 2019 Jan 26.
- `d5b9d1f15ccd`: Intel rewritten email, Job Application Date 2019 Jan 25, plus seven annotation labels.
- feature image: no text, no figures.

The 7/11/2022 in the scoring matrix screenshot and the 2019 dates in the Intel emails are sample data inside screenshots, not claims the prose makes, so nothing is held on them. The scoring matrix screenshot is the same asset flagged for regeneration under `/blog/problem-solving-interview-questions` (a different asset ref, same template, same 7/11/2022 date), so if that one gets reshot this one can use the new capture.

## Alt text written

All from what the graphic shows, not from the surrounding paragraph.

| Block | Before | After (opening) |
|---|---|---|
| `featureImage.altText` | "Job Rejection Header Image" | "A white outlined speech bubble with an X inside it, on a black background, the header graphic for this article on job rejection emails." (146 chars) |
| `e595dfb64422` | "Screenshot of a viral tweet on job rejection email\n" | "Screenshot of a tweet by @dzzzny posted at 4:10 PM on July 29, 2021 with 960.5K likes and 4.7K replies, captioned ..." (764 chars, carries both emails verbatim) |
| `2ff5f43f9538` | "Screenshot of Polymer Candidate Message Template" | "Screenshot of the Polymer hiring pipeline for a Senior Front-end Developer role at Tablespace Games ..." (705 chars, carries the full template body) |
| `f49ddff86623` | "Screenshot of Grammarly Website" | "Screenshot of Grammarly's tone page, headed 'Say What You Mean, Exactly How You Mean It' ..." (463 chars, carries the Tone Detector ratings) |
| `2297adf503aa` | "Screenshot of Polymer interview scoring matrix template" | "Screenshot of Polymer's interview scoring matrix template in Google Sheets ..." (723 chars, carries all eight criteria and the five-point scale) |
| `a58002381e76` | "Screenshot of Intel Rejection Email" | "Screenshot of Intel's original rejection email, headed by a blue 'Hiring at Intel' banner ..." (643 chars, carries the email body) |
| `d5b9d1f15ccd` | "Screenshot of Intel Rejection Email with description" | "Screenshot of Intel's rewritten rejection email with annotations arrowed at each change ..." (1,088 chars, carries all seven annotation labels) |

## Byline and date

`updatedDate` set to `2026-08-06`. `author` left as `author-corey-daniels`, the assignment already on the draft. `publishDate` left at `2022-08-09`.

## Not done, deliberately

- **No restructuring.** The post is #1 for its head term and tab 13 says light touch. No answer-first blocks, no new sections, no new prose beyond the sentences carrying the replaced figures.
- **Two pre-existing em-dashes left in place**, blocks `ce38bb809382` and `319c8d64ffb9`. They are from the 2022 original, not from this pass, and the brief was to change nothing beyond dated figures. Recorded in QUESTIONS-FOR-JESSICA.md.
- **An orphaned markDef left in place.** Block `ed3f08ff3cd5` carries a `markDefs` entry `db7ef0ef2290` pointing at the old BLS URL that no span in that block uses, so it renders nothing. Left rather than touched.

## Sources reached and their status

| URL | Status |
|---|---|
| https://www.hci.org/blog/statistics-rethink-your-candidate-experience-or-ruin-your-brand | 200, undated, citation removed |
| https://www.edelman.com/trust/2021-brand-trust/brand-equity | 403 to curl and WebFetch, left in place, no figure hangs on it |
| https://www.bls.gov/opub/btn/volume-9/how-do-jobseekers-search-for-jobs.htm | 403 to curl and WebFetch, citation replaced |
| https://brandingreference.com/core-values-of-famous-companies/ | 200 |
| https://www.grammarly.com/tone | 200 |
| https://www.newsweek.com/womans-sassy-email-reply-too-weak-bodybuilder-job-viral-twitter-discrimination-1614629 | 406 to curl, image `sourceUrl` only, left |
| https://medium.com/@shirabc/how-we-have-improved-the-candidate-rejection-experience-at-intel-using-ux-research-techniques-b2b88159bafa | live via WebFetch, 2 June 2020 |
| https://www.youtube.com/watch?v=SfnQWPHGH8A | 200, "The Commercial Impact of Candidate Experience - Graeme Johnson - Talent Connect 2016" |
| https://www.entrepreneur.com/business-news/job-seekers-are-getting-ghosted-in-record-numbers | 200, new citation |
| https://unitedwaynca.org/blog/how-long-does-it-take-to-find-a-job-2026-survey/ | 200, new citation, used twice |
| https://www.linkedin.com/business/talent/blog/talent-acquisition/bad-candidate-experience-cost-virgin-media-5m-annually-and-how-they-turned-that-around | 200, new citation |

---

# Fix pass

Three verifier findings, all worked. Draft `drafts.35e36b52-728b-4eb1-b7d9-ed2003c4d1a5`, rev before `kJ3OpIOJnJS2LKJpQpeqfF`, rev after `guLb7mLdCgNrjUoWfCFija`. Seven `set` operations in one patch, guarded with `ifRevisionID`. Nothing published; `author`, `updatedDate`, `pageTitle`, `editorialTitle`, `metaDescription`, `slug` and every other block untouched.

## MED: the categorical negative in QUESTIONS-FOR-JESSICA.md was false, and the clause it justified is reverted

The refresh wrote "There is no general 2026 post-interview figure in public" and used that to widen the intro's first clause from post-interview ghosting (old 60%) to any-stage ghosting (53%). Two general 2026 post-interview figures are published. Both were read on the publisher's own page, in a browser, not through an aggregator.

| Source | Figure, verbatim | Published | Fielded | n | Population | What it counts |
|---|---|---|---|---|---|---|
| LiveCareer, Ghosting Consequences Report, https://www.livecareer.com/resources/careers/ghosting-consequences | "Ghosted after one or more interviews: 22%" | 1 July 2026 | 14 April 2026, Pollfish | 1,008 | U.S. adults currently in work | the event |
| Resume Genius, 2026 Job Seeker Insights Report, https://resumegenius.com/blog/job-hunting/job-seeker-insights-report-2026 | "Not hearing back after completing one or more interviews (44%)" | 8 April 2026 | 16 March 2026, Pollfish | 1,000 | active U.S. job seekers | naming it a top frustration |

Reaching them: `curl` with a desktop Chrome user agent returns 403 from resumegenius.com and dies with `HTTP/2 stream 1 was not closed cleanly: INTERNAL_ERROR` on livecareer.com. Both serve full pages to a real browser. The LiveCareer page renders client-side and returns an empty `document.body.innerText` on first read, so it needs a wait before the text is there.

**LiveCareer's 22% is what went on the page,** because the old clause measured the event and 22% measures the event. The Resume Genius 44% is closer on population and bigger as a number, but it is a multi-select "top hiring frustrations" item, so it counts people who name post-interview silence as a frustration rather than people it happened to. Both are recorded for Jessica in QUESTIONS-FOR-JESSICA.md; swapping to the 44% is a one-line patch if she prefers it, with the sentence reworded to say "name it as a top frustration".

Block `548a11a76a45`, four span texts and one `markDefs` href:

Before: "In the current struggle to attract top talent, employers must rethink their recruitment communication strategies. With **53% of job seekers ghosted by an employer** in the past year and **67% of applications getting no response at all** in 2026, most job seekers report a negative experience with potential employers." First figure linked to `https://www.entrepreneur.com/business-news/job-seekers-are-getting-ghosted-in-record-numbers`.

After: "In the current struggle to attract top talent, employers must rethink their recruitment communication strategies. With 2026 surveys finding **22% of U.S. workers ghosted by an employer after one or more interviews** and **67% of applications getting no response at all**, most job seekers report a negative experience with potential employers." First figure linked to `https://www.livecareer.com/resources/careers/ghosting-consequences`.

Paths set: `content[_key=="548a11a76a45"].children[_key=="b7060cbf8d170"].text`, `[_key=="b7060cbf8d171"].text`, `[_key=="b7060cbf8d173"].text`, `[_key=="b7060cbf8d172"].text`, `content[_key=="548a11a76a45"].markDefs[_key=="a41c9e7b5d02"].href`.

**Why the year moved to the front of the clause.** LiveCareer's ghosting question carries no time window, so 22% is an experience reported in a 2026 survey, not ghosting that occurred during 2026. "in the past year" (which belonged to the Criteria 53%) is gone and "2026 surveys finding" governs both figures, which dates each one without claiming either event happened inside the year. The trailing "in 2026" came out for the same reason: left where it was it would have dated only the 67%.

The 67% and its United Way link are untouched and were re-verified at source during this pass: "67% of their applications got no response at all", survey of 1,000 U.S. job seekers fielded 26 February to 7 March 2026. Same page still states "job seekers submitted 62.6 applications, but landed just five interviews", which is block `989d8b0e9827`.

Also corrected in QUESTIONS-FOR-JESSICA.md: item 1 under "Content refresh, `/blog/job-rejection-email`", and the `/blog/job-rejection-email` row under "Open: no current figure was obtained, and the reason", which said "Not published in the form sought".

## LOW: two alt texts asserted detail the pixels do not carry

Both images were re-downloaded from the Sanity CDN and read at full size, the Grammarly panel cropped and enlarged 4x to count the dots.

**Block `f49ddff86623`, Grammarly.** The panel shows Confident 4 filled of 5, Joyful 4 of 5, **Optimistic 3 of 5**. The alt said "rates the message Confident, Joyful and Optimistic on four-of-five dot scales". The tail now reads "which rates the message Confident four dots of five, Joyful four of five and Optimistic three of five." Nothing else in that alt changed.

**Block `d5b9d1f15ccd`, Intel rewritten email.** The signature block reads "Kind regards, / **(RECRUITER NAME)** / Intel Talent Acquisition team". The alt said the email "is signed by a named recruiter for the Intel Talent Acquisition team", which the graphic does not show. That clause now reads "closes "Kind regards" above the placeholder "(RECRUITER NAME)" and "Intel Talent Acquisition team"". One quoted string in the same alt was also off by two commas against the pixels and is now verbatim: "I hope you will keep us in mind, too, and apply again in the future". Nothing else changed, including all seven annotation labels.

This does not change the "Images that need regenerating" position: neither graphic carries a figure the prose asserts, so nothing on this post is held and there is still no entry for it.

## LOW: reporting error corrected

The survey section said `pageTitle`, `editorialTitle`, `metaDescription` and `slug` "all carried earlier-phase values". They carried their **published** values. Queried during this pass, the published document `35e36b52-728b-4eb1-b7d9-ed2003c4d1a5` (`_rev` `l0bLyT137Vusgfcue9ZUuu`) holds `pageTitle` "Job Rejection Emails: How to Get it Right + Sample Templates " and `editorialTitle` "How to Write Personalized Job Rejection Emails" and the same `metaDescription`, all byte-identical to the draft including trailing whitespace, with `author` null and `updatedDate` null. This post received no phase-4 metadata rewrite; the only thing the pre-existing draft added over published was the `author` reference. The operative claim, that none of them was touched, was and is true. Sentence corrected in place above.

## Full re-read of the draft, for anything the findings did not name

All 117 blocks read again after the patch, plus every `markDefs` entry, every image `alt`, `source` and `sourceUrl`, the four `quote` template blocks and the `toc` block. Nothing new to fix. Four things worth having on the record:

- **`updatedDate` still reads `2026-08-06`** and the fix pass ran on 2026-08-07. Left alone deliberately: all eleven refreshed posts carry the same date and a one-day split across the batch is worse than the day being off.
- **The orphaned `markDef` on block `ed3f08ff3cd5` is still there**, key `db7ef0ef2290`, still pointing at the old BLS URL, still referenced by no span, so it renders nothing. Recorded in the original pass; left again.
- **Block `548a11a76a45` carries a second orphan**, `markDefs` key `20e7fad24c2b` pointing at `/blog/a-player`, which no span in that block uses either. It predates the refresh (block `fb02c10dfe45` carries the same key and does use it) and renders nothing. Untouched.
- **The two pre-existing em-dashes stand**, blocks `ce38bb809382` and `319c8d64ffb9`. Nothing written in the refresh or in this fix pass contains one.
