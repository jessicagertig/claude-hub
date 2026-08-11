# Refresh log: `/blog/a-player`

Tab 13 row 9. Refresh order 9. Tab 01 row 12.
Run 2026-08-06. Sanity draft only, nothing published, no repo file touched.

## Document

| | |
|---|---|
| Published id | `934c12d9-28de-4645-8cd7-3b6a504531d5` |
| Draft patched | `drafts.934c12d9-28de-4645-8cd7-3b6a504531d5` |
| Draft rev before | `guLb7mLdCgNrjUoWfC1fHk` (`_updatedAt` 2026-08-07T03:03:40Z) |
| Draft rev after | `kJ3OpIOJnJS2LKJpQphFPB` |
| Published rev after | `i7ljIeEeav1WO3JfFunmjG`, `_updatedAt` 2023-03-02T19:45:42Z, `updatedDate` null |
| Content blocks | 129 before, 129 after |
| `publishDate` | 2023-02-28, unchanged |

The draft already existed and already carried `author` = `author-jessica-gertig`. It was patched with
a single `.patch().set()` keyed on individual `content[_key==...]` paths, never overwritten, so
nothing else pending in the draft was disturbed. The published document was read for comparison and
never mutated; its `_rev` and `_updatedAt` are unchanged from 2023.

## Scope

Tab 13 row 9 says "Merge candidates: could redirect into a broader hiring guide" and tab 01 row 12
says "Link; fold into hiring-ops cluster". **Neither was acted on.** The slug is unchanged, no
redirect was proposed, no internal link was added or removed. Those belong to a separate content
plan. What was done is the refresh: dated figures, byline, updated date, alt text.

## Survey

All 129 blocks were read in order, not skimmed for `%` and four-digit years. That is 4 images
(3 body + `featureImage`), 1 `toc`, 1 `youtube` embed, 2 `table` blocks, and 121 text blocks, plus
`pageTitle`, `editorialTitle`, `metaDescription`, `publishDate` and every `markDefs` href.

Everything carrying a figure, a date, an attribution, an "according to", or a claim about how the
world currently works:

| Block | What it carries | Disposition |
|---|---|---|
| `b5ed5257bccc` (0) | Tom Eisenmann, HBS, "bad bedfellows", *Why Startups Fail*, HBR 2021 link | Unchanged, verified |
| `84bbcc0faeda` (2) | "50% of small business owners struggle to find qualified people" | **REPLACED** |
| `5a15cbe2a01c` (7) | Steve Jobs, "truly gifted people" | Unchanged, historical quotation |
| `d3edd95e0278` (8) | YouTube embed, Jobs interview | Unchanged, 200 |
| `569df76f428e` (9) | Smart and Street, A-player = "top 10% of people" | Unchanged, verified |
| `d549092e76df` (16) | 1997 study; "almost 48 million Americans quitting their jobs in 2021"; "should the situation ever return to normal" | **REPLACED** |
| `acfe9c031572` (65) | Indeed, Monster, Pallet, Lean Hire, Dice; "Pallet groups job seekers into Collectives" | **REPLACED**, practice changed |
| `f215f572ad7b` (66) | Pallet screenshot, `sourceUrl` 404 | alt rewritten, `sourceUrl` repaired, recorded for Jessica |
| `68110bd5d54f` (96) | goal-setting theory of motivation | Unchanged, theory not a figure, link 200 |
| `6238ba74710e` (100) | "63% of people ... very unlikely to seek a new job"; "43% ... extremely likely to leave" | **REPLACED** |
| `171cc63ddc34` (108) | Steve Jobs on A-players managing themselves | Unchanged, historical |
| `c933f33effce` (119) | "A 2022 Harris Poll survey found that 51% of employees are currently burned out" | **REPLACED** |
| `dbb803780254` (121) | "employees without flexible work are twice as likely to have poor mental health"; Linear, ClickUp, Asana | **REPLACED** |
| `3b02d184f49e` / `d5c7f89b8a0b` (127, 128) | `hire.wrk.xyz/register` CTA | Unchanged, not mine, see Links |

Nothing else in the 129 blocks carries a statistic, a study reference, a named report, a "recent
study found", a "last year", or a practice claim. The A-player characteristics list (blocks 25-33),
the job scorecard steps (45-49), the job description steps (55-58), the interview question table
(86), the retention tactics (96-98, 104-106) and the burnout tactics (121-123) were all read end to
end; apart from the figures above none is stale and none was touched.

## Figures replaced

Five, all researched 2026-first, per figure. None was skipped and none was left dated while its
neighbours moved.

### 1. Small business owners who cannot find qualified people

Block `84bbcc0faeda`.

Before:

> But finding these people is easier said than done. In fact, another survey found that **50% of
> small business owners** struggle to find qualified people.
>
> Link on "50% of small business owners" to
> `https://www.surveymonkey.com/curiosity/cnbc-small-business-q2-2022/`

After:

> But finding these people is easier said than done. In **July 2026**, **51% of small business
> owners** reported few or no qualified applicants for the roles they were trying to fill, and
> **36%** had openings they could not fill.
>
> Link on "51% of small business owners" to `https://www.nfib.com/news/monthly_report/jobs-report/`

**The old source no longer states the claim.** The CNBC|SurveyMonkey Q2 2022 page still returns 200,
but the article that renders there today covers inflation, recession expectations, cybersecurity and
presidential approval. It carries no hiring or qualified-applicant figure at all. Fetched and text
searched for `qualified`, `hiring`, `hire`, `workers`, `50%`, `half`, zero relevant matches. So the
figure was not merely old, it was pointing at a page that no longer supports it.

**2026 exists and is the value taken.** CNBC|SurveyMonkey runs quarterly but has moved off this
measure; the Q4 2025 edition (published 16 October 2025) carries no labour-market question. NFIB's
Small Business Economic Trends runs **monthly** and asks exactly this question every month. The July
2026 NFIB Jobs Report, released 6 August 2026, is the current reading:

> "Fifty-one percent of owners (85% of those hiring or trying to hire) reported few or no qualified
> applicants" and "In July, 36% (seasonally adjusted) of small business owners reported job openings
> they could not fill".

**WITHDRAWN 2026-08-07. The paragraph below is wrong and the link no longer points at the hub. See
"Fix pass" at the end of this file: nfib.com is Cloudflare-gated rather than blocked, it loads in a
browser, and the dated permanent press release
`https://www.nfib.com/news/press-release/nfib-jobs-report-small-business-employment-index-picks-back-up-4/`
exists and states both figures. Search indexing was never the question. Kept here as the record of
what was claimed.**

**Why the link goes to the monthly hub and not a dated permalink.** `nfib.com` returns **403 to every
automated client**, which was verified rather than assumed: `https://www.nfib.com/` itself, a
deliberately fabricated `nfib.com` path, and the candidate press-release URL all return the identical
403, so the status code carries no information about whether a given page exists. The July 2026
press-release slug and PDF path are not yet in any search index (the report is one day old at time of
writing; the June PDF is indexed at `.../uploads/2026/07/NFIB-June-2026-Jobs-Report-Final.pdf`, the
July one is not). `https://www.nfib.com/news/monthly_report/jobs-report/` is NFIB's own permanent
landing page for this exact monthly series and resolves in a browser. The sentence names July 2026 so
the reading is identifiable. **June 2026 gives the same headline number** (51% of owners, 84% of those
hiring, 32% with unfillable openings), so the figure does not hinge on which of the two months is
cited.

**Verified through a reachable third party rather than taken from a snippet.** The Wyoming Tribune
Eagle's syndication of the NFIB release, published **6 August 2026**, quotes both sentences verbatim,
`http://www.wyomingnews.com/news/local_news/nfib-report-shows-small-business-employment-improving/article_7d34334c-da0c-4ee2-a6d6-23eae59b4238.html`.
TD Economics' 14 July 2026 write-up corroborates the June reading,
`https://economics.td.com/us-nfib-small-business-optimism`.

### 2. Quits, and the turnover-performance curve

Block `d549092e76df`.

Before:

> Way back in 1997, **a study demonstrated** that average performers (B-players) tend to stay at the
> same company longer than A or C-players. More recently, burnout during the pandemic has likely
> leveled this trend, with almost 48 million Americans quitting their jobs in 2021. However, it's
> worth being aware of this potential turnover-performance curve should the situation ever "return
> to normal."

After:

> Way back in 1997, **a study demonstrated** that average performers (B-players) tend to stay at the
> same company longer than A or C-players. Burnout during the pandemic likely leveled this trend,
> with almost 48 million Americans quitting their jobs in 2021. That wave has receded: **38.0 million
> Americans quit in 2025**, so the turnover-performance curve is worth watching again.
>
> Link 1 unchanged, on "a study demonstrated"
> Link 2 on "38.0 million Americans quit in 2025" to
> `https://www.bls.gov/news.release/archives/jolts_03132026.pdf`

Three things changed.

**The figure was added, not swapped.** The 2021 number is correct and is kept, because the sentence's
whole point is the contrast. BLS JOLTS not-seasonally-adjusted quits levels, series
`JTU000000000000000QUL`, sum to **47,558 thousand for 2021**, which is the post's "almost 48 million"
to the decimal. The new figure is the 2025 annual total, **38.0 million**, from the BLS JOLTS January
2026 release published 13 March 2026, which states "In 2025, annual quits totaled 38.0 million" and
"accounted for 60.6 percent of total separations". The same API series sums to **38,029 thousand** for
2025, an independent confirmation of the release's figure. Corresponding years: 2022 50.5m, 2023
44.2m, 2024 39.3m.

**WRONG, corrected 2026-08-07: `bls.gov` does not block automated clients.** It 403s a client whose
User-Agent does not identify who is calling and 200s one that does, which is BLS's published
data-access policy. `curl -A "PolymerSEO/1.0 (jessicamgertig@gmail.com)"
https://www.bls.gov/news.release/archives/jolts_03132026.pdf` returns **200**, and the release says
"Annual quits decreased by 1.3 million in 2025 to 38.0 million and accounted for 60.6 percent of
total separations". The cited URL states the figure at source; the paragraph below describes how it
was obtained before that was known.

**`bls.gov` blocks automated clients**, so the release itself was read through search rather than
fetched: `WebFetch` and `curl` with full browser headers both get 403 on
`news.release/archives/jolts_03132026.pdf`, on the `.htm` sibling, and on `fred.stlouisfed.org`'s CSV
endpoint. `api.bls.gov` is a different host and answers normally, which is where the monthly series
came from. The figure therefore has two independent BLS-originated confirmations that agree exactly,
and the linked URL is BLS's own permanent archive path.

**The practice claim was corrected.** "Should the situation ever return to normal" was written when it
had not. It has: quits are 20% below their 2021 peak and below the 2024 level. The clause now says the
curve is worth watching again. This is a currency fix on a claim about the world, not a restructure;
no block was added, removed or reordered.

The 1997 study was verified rather than assumed: Trevor, Gerhart and Boudreau, "Voluntary Turnover and
Job Performance: Curvilinearity and the Moderating Influences of Salary Growth and Promotions",
*Journal of Applied Psychology* 82, 44-61, 1997, n = 5,143. It does find turnover higher for low and
high performers than for average performers, which is what the post says. ResearchGate returns 403 to
automation; the paper is there and the link was left alone.

### 3. Pallet is no longer a hiring product

Block `acfe9c031572`. Not a number, but the clearest stale fact in the post.

Before:

> **Search online.** Job sites like **Indeed** and **Monster** have endless candidates looking for
> work. But you might have better luck finding high-quality candidates on industry-specific candidate
> curation sites like **Pallet**, **Lean Hire**, and **Dice**. For example, Pallet groups job seekers
> by characteristics into "Collectives."
>
> Link on "Pallet" to `https://www.pallet.com/spotlight`

After:

> **Search online.** Job sites like **Indeed** and **Monster** have endless candidates looking for
> work. But you might have better luck finding high-quality candidates on industry-specific candidate
> curation sites like **Lean Hire** and **Dice**. The screenshot below is from **Pallet**, which
> grouped job seekers by characteristics into "Collectives" before it left hiring for supply chain
> software.
>
> Link on "Pallet" to `https://www.pallet.com/`

**AMENDED 2026-08-07.** The clause "before it left hiring for supply chain software" asserts that the
hiring company became the logistics company, which nothing states and which this log contradicts two
paragraphs down by calling pallet.com "a different company's product". The sentence now ends "The
Collectives are gone from pallet.com, which now sells supply chain software." Evidence and reasoning
under "Fix pass".

`https://www.pallet.com/spotlight` returns **404**. `https://www.pallet.com/` returns 200 and is a
different company's product: headline "AI systems that move the physical economy", subhead "The
world's most advanced supply chain and logistics teams run their operations on Pallet", products
Agents, Atlas, Forge, Memory and Intelligence. No job collectives, no community hiring boards
anywhere on the site. So the post was recommending, in the present tense, a product that no longer
exists, and linking readers to a 404.

Pallet stays named because the screenshot immediately below it is a screenshot of Pallet and cannot
be edited. Moving it into the past tense makes the prose and the graphic agree instead of contradict:
the picture shows what Pallet used to do, and the sentence now says that is what it used to do. It is
out of the list of sites to go and use today, which is the part that was actively wrong.

**Lean Hire and Dice were both checked and both survive.** `leanhire.beondeck.com` returns 200 with
the title "Lean Hire, The Contract-to-Hire Platform". Worth knowing: its parent, On Deck, no longer
exists under that brand, `www.beondeck.com` now 301s to `joinodf.com` ("ODF | Founder Fellowship"),
so Lean Hire is a surviving subdomain of a rebranded company. It is live, so it was left. `dice.com`
200.

**Monster survives too, with a caveat that did not change the copy.** CareerBuilder + Monster filed
Chapter 11 in June 2025 with $392.5m of debt and the job boards were sold to Bold in the bankruptcy.
`monster.com` returns 403 to automation but is live and still a job board, so "Job sites like Indeed
and Monster have endless candidates looking for work" is still true in 2026 and was not touched.

### 4. Recognition and retention

Block `6238ba74710e`.

Before:

> Studies have found that **63% of people** who are recognized at work are "very unlikely" to seek a
> new job. The same study shows that 43% of people who don't get recognition are "extremely likely"
> to leave their jobs.
>
> Link on "63% of people" to `https://www.surveymonkey.com/curiosity/employee-recognition-and-retention/`

After:

> **Gallup and Workhuman tracked nearly 3,500 employees from 2022 to 2024** and found that
> **well-recognized employees were 45% less likely** to have left after two years. Those getting
> high-quality recognition were also **65% less likely** to be actively looking or watching for
> another job.
>
> Link on "well-recognized employees were 45% less likely" to
> `https://www.gallup.com/workplace/650174/employee-retention-depends-getting-recognition-right.aspx`

**The old figures are from June 2019 and undated on the page.** The SurveyMonkey article is still live
and still states both, "63% of people who are 'always' or 'usually' recognized at work consider
themselves 'very unlikely' to seek a new job in the next 3-6 months" and "43% of the unrecognized
group are 'extremely likely' to seek work elsewhere", from a survey fielded **5 June 2019**, n = 1,511
employed US adults, +/- 5 points. Seven years old and the post gave no year, so it read as current.

**SurveyMonkey has not re-run it**, so a like-for-like 2026 update of those exact two percentages does
not exist. The most recent published measurement of the recognition-to-retention relationship is
Gallup and Workhuman, "Employee Retention Depends on Getting Recognition Right", published **18
September 2024**, tracking nearly 3,500 employees from 2022 to 2024: "Well-recognized employees were
45% less likely to have turned over after two years" and "These employees are 65% less likely to be
actively looking or watching for another job opportunity compared with those receiving lower-quality
recognition". No 2025 or 2026 edition exists. The sentence names 2022 to 2024 so it cannot read as
newer than it is.

**The claim shape changed** from "how likely people say they are to look" to "whether they actually
left", which is a stronger measure of the same thing but is not the same measure. Recorded in
QUESTIONS-FOR-JESSICA.

### 5. Burnout

Block `c933f33effce`.

Before:

> A **2022 Harris Poll** survey found that **51% of employees** are currently burned out. If you want
> your A-players to stick around, be proactive and prevent burnout before it's too late.
>
> Link on "51% of employees" to `https://www.talkspace.com/research/stress-in-the-workplace`

After:

> **Eagle Hill Consulting's November 2025 workforce survey** found that **55% of U.S. employees** are
> experiencing burnout. If you want your A-players to stick around, be proactive and prevent burnout
> before it's too late.
>
> Link on "55% of U.S. employees" to
> `https://www.eaglehillconsulting.com/news/workforce-burnout-survey-2025/`

**The old source is gone.** `talkspace.com/research/stress-in-the-workplace` 301s to
`talkspace.com/research`; the article stating the 51% no longer exists at any URL. The sentence also
said a 2022 figure meant employees "are currently" burned out, which was four years stale.

**The most recent verified primary measurement is Eagle Hill's**, published **24 November 2025**, run
by **Ipsos in November 2025** on a random national sample of **more than 1,400 US employees**: "More
than half of the U.S. workforce (55%) is experiencing burnout, according to new research from Eagle
Hill Consulting." Fetched directly from Eagle Hill, not from a secondary. The same release gives
Gen Z 66%, Millennials 58%, Gen X 53%, Boomers 37%, fully remote 61%, hybrid 57%, and burned-out
employees nearly three times more likely to plan to leave within a year.

**Where 2026 was looked for.** Burnout percentages in circulation for 2026 run from 44% to 83%
because each survey defines burnout differently. SHRM's 44% traces back to its **2024** Employee
Mental Health Research Series, not 2026. Mercer's 82% measures whether the *conditions* for burnout
exist, not active burnout. Gallup's 67% is a symptom-experience question, not a current-state one.
The DHR Global 83% and the various aggregator figures could not be traced to a primary source that
states methodology. Eagle Hill is the newest figure I could verify at its publisher with field dates,
sample and method attached, and it measures exactly what the sentence claims.

### 6. Flexible working and mental health

Block `dbb803780254`.

Before:

> **Offer flexible working.** Giving your A-players flexibility with their work schedule gives them a
> better work-life balance. Whether you're fully remote, hybrid, or in-office, flexible working is
> better for their overall mental health. In fact, **studies** have found that employees without
> flexible work are **twice as likely** to have poor mental health.
>
> Link on "studies" to `https://www.flexjobs.com/blog/post/flexjobs-mha-survey-flexible-work-improves-mental-health/?utm_source=cj&utm_medium=Skimlinks&utm_campaign=affiliates&cjevent=592e39c340a511eb8329000c0a240614`

After:

> **Offer flexible working.** Giving your A-players flexibility with their work schedule gives them a
> better work-life balance. Whether you're fully remote, hybrid, or in-office, flexible working is
> better for their overall mental health. In the American Psychological Association's **2023 Work in
> America survey**, **67%** of workers who lacked the flexibility to balance work and personal life
> said their work environment had a negative impact on their mental health, against **23%** of those
> who had that flexibility.
>
> Link on "2023 Work in America survey" to
> `https://www.apa.org/pubs/reports/work-in-america/2023-workplace-health-well-being`

**The old claim misstated its own source.** The FlexJobs and Mental Health America survey, fielded
late July 2020 on 800+ employed respondents, says "17 percent of those with flexible work options say
their mental health is poor or very poor but 27 percent of those without flexible work options say
their mental health is poor or very poor". 27 against 17 is 1.6x, not twice as likely. So the
sentence was both six years old and wrong about what the study found. The URL also carried a
Commission Junction affiliate tracking parameter (`cjevent=...`), and returns a broken HTTP/2 stream
to a normal client.

**The replacement is a primary source stating an actual comparison**: APA 2023 Work in America
survey, fielded **17 to 27 April 2023**, n = **2,515** employed adults. Verbatim: "Workers who said
they did not have the flexibility to keep their work and personal life in balance were more likely to
report that their work environment had a negative impact on their mental health (67%) compared with
those who did have that flexibility (23%)."

**Why 2023 and not 2026.** There is no 2026 Work in America survey; APA's most recent is the 2025
edition, published July 2025, fielded 26 March to 4 April 2025, n = 2,017. It was checked and does
**not** carry a flexibility-versus-mental-health comparison at all; it covers job insecurity, policy
change and economic uncertainty. The APA hub lists 2023, 2024 and 2025 only. Searching for a 2026
primary measurement of the same comparison returned only SEO aggregator pages (wifitalents,
hupcfl, deskflex) with no traceable underlying survey, which are not citable. Recorded in
QUESTIONS-FOR-JESSICA. The sentence names 2023 so nothing reads as more current than it is.

## Figures held

**None.** Rule 6 exists for figures a graphic carries, and no figure replaced in this post appears in
any of the four images. The Pallet screenshot carries collective member counts (90+, 80+, 50+, and so
on) but the prose never asserted any of them, so nothing was blocked behind it. All five dated
figures plus the Pallet practice claim were replaced.

The Pallet image is still stale in its own right, as a screenshot of a discontinued product, and is
recorded for Jessica under "Images that need regenerating" as a removal candidate rather than a
figure swap.

## Images

All four were downloaded from `cdn.sanity.io` at `w=1600&fit=max` and viewed, not inferred from
surrounding prose. Two outputs per image: what it actually asserts, and alt written from that.

### `f215f572ad7b`, Pallet Collectives

**What it asserts:** four dark rounded cards on a black field, each with an avatar, a name, a
one-line pitch, a "The Collective" divider and a five-line roster. Card 1, Lenny's Collective,
"Experienced, product-minded people, at your fingertips", 90+ Product Managers, 90+ Startup
Operators, 50+ Growth Marketers, 20+ Data Engineers, 15+ Software Engineers. Card 2, The Not Boring
Collective, "Hire directly from the best of the Not Boring audience", 80+ BizOps People, 60+ Product
People, 25+ Sales People, 20+ Marketers, 20+ Software Engineers. Card 3, Gaby's Web3 Collective,
"Gaby's prominent web3 community, hungry for exciting opportunities", 80+ Product People, 50+
Software Engineers, 50+ Marketers, 40+ Sales & Partnerships, 30+ Creative. Card 4, Old Girl's Club
Collective, "Source from OGC's community of highly experienced women in tech", 50+ BizOps People,
35+ Marketers, 20+ Designers, 20+ Creative People, 15+ Software Engineers. No dates, no source
attribution.

- Before: `Screenshot of Pallet Website Grouping Job Seekers by Characteristics`
- After: `Screenshot of four Pallet Collectives shown as cards on a black background. Lenny's Collective, experienced product-minded people, lists 90+ product managers, 90+ startup operators, 50+ growth marketers, 20+ data engineers and 15+ software engineers. The Not Boring Collective lists 80+ BizOps people, 60+ product people, 25+ sales people, 20+ marketers and 20+ software engineers. Gaby's Web3 Collective lists 80+ product people, 50+ software engineers, 50+ marketers, 40+ sales and partnerships and 30+ creative. Old Girl's Club Collective, a community of experienced women in tech, lists 50+ BizOps people, 35+ marketers, 20+ designers, 20+ creative people and 15+ software engineers.`

The old alt named the concept and nothing in the picture. Twenty specific role counts and four named
collectives were invisible to anything that cannot see.

**`sourceUrl` repaired.** It was `https://www.pallet.com/spotlight  ` (404, with two trailing spaces)
and is now `https://www.pallet.com/` (200). The prose now tells the reader Pallet left hiring, so the
link does not mislead.

### `e109a42c7f79`, Polymer message thread

**What it asserts:** a white card on a peach-to-pink gradient. Top message from Meg Barnes, "23min",
"Sent via Email": "Hi Riley, Thank you for applying for the Backend Engineer role with us! We were
excited to review your application. It seems like you have a ton of relevant experience. Would you be
available for a phone call sometime this week? Thursday or Friday afternoon? Best regards, Meg."
Second message from Riley Townsend, tagged "Candidate", "13min", "Sent via Email": "Hi Meg! It's
exciting to hear from you. Anytime after 1pm on Friday would work great for me. Just let me know
when! Riley." Below: a "Type your message here..." composer, a black "Send message" button and a grey
"Use template" button. No figures, no dates.

- Before: `Screenshot of Direct Messaging Candidate within the hiring platform`
- After: `Screenshot of a Polymer message thread. Recruiter Meg Barnes emails candidate Riley Townsend to thank him for applying to the Backend Engineer role and ask whether he is free for a phone call on Thursday or Friday afternoon. Riley replies that anytime after 1pm on Friday works. Below the thread sit a message composer and two buttons, Send message and Use template.`

### `b35d8f092e38`, applicant tracking system

**The old alt was not thin, it was wrong.** It read `Screenshot of Direct Messaging Candidate within
the hiring platform`, a verbatim copy of the messaging image's alt, on a picture that shows no
messaging at all.

**What it asserts:** the Polymer app for "Tablespace Games", job "iOS Developer", with a "Search
candidates" bar. Left rail of stages with counts: Inbox 11, Screen 19, Interview 4, Decide 1, Offer
0, Archive 4, then Job setup and Distribution. Candidate list: Ella Patterson, Marie Gordon,
Nathaniel Meyer, Sadie Allen, Nannie O'Moore, Mollie Cruz, Luke Wallace, Ibrahim Diaz, Lillie Howard,
Joshua Castillo, Hugo Gray. Ella Patterson's record, "Applied from job board", tabs Overview, Resume,
Messages, Files, Notes, contact information (242) 336-5620 and hello@lapatters.com, a
github.com/lapatters link, and "Move to Screen" and "Archive" buttons. Right panel: "Application
received, 2d", then two application questions with long written answers, and "Add a comment" and
"Start a review" buttons. No dates, no statistics.

- Before: `Screenshot of Direct Messaging Candidate within the hiring platform`
- After: `Screenshot of the Polymer applicant tracking system for an iOS Developer role at Tablespace Games. The left rail lists the hiring stages with counts, Inbox 11, Screen 19, Interview 4, Decide 1, Offer 0 and Archive 4, plus Job setup and Distribution. The next columns list the candidates in the inbox and open Ella Patterson's record, with tabs for Overview, Resume, Messages, Files and Notes, her contact details and GitHub link, and Move to Screen and Archive buttons. The overview panel shows her written answers to the application questions, with Add a comment and Start a review actions.`

The paragraph above it says "with Polymer you can add new stages to the hiring process, edit your job
boards, and create custom email templates", and the stage rail is exactly what that describes, so the
image is in the right place. Only its alt was wrong.

### `featureImage`, header

**What it asserts:** four circles in a row on a solid black field, drawn in white line art. Three are
empty dashed outlines; the third from the left is a solid continuous flame. No text, no figures.

- Before (`featureImage.altText`): `A-Player Header Image`
- After: `Line-art graphic on a black background: four circles in a row, three drawn as empty dashed outlines and the third drawn as a solid white flame.`

## Byline and updated date

`updatedDate` set to **2026-08-06** on the draft. Field confirmed against
`studio/schemas/blogPost.js`, type `date`, described there as "The editorial last-updated date. Set it
only when the post is genuinely revised. This is separate from Sanity's automatic `_updatedAt`
timestamp, which moves on every save."

`author` was already `author-jessica-gertig` on the draft and was **not changed**, per instruction.
The `author` field is a reference to the `author` document type on the schema.

Both landed regardless of anything else in this post, as required.

## Links checked

Every `markDefs` href in the post, plus the `youtube` embed and the four new URLs.

| URL | Result |
|---|---|
| `hbr.org/2021/05/why-start-ups-fail` | 200 |
| `surveymonkey.com/curiosity/cnbc-small-business-q2-2022/` | 200 but no longer states the claim, **replaced** |
| `scaling4growth.com/wp-content/uploads/2015/10/Who.pdf` | 200 |
| `researchgate.net/publication/37149443_...` | 403 to automation, **not dead**, paper verified to exist |
| `youtube.com/embed/wTgQ2PBiz-g` | 200 |
| `linkedin.com/` | 200 |
| `indeed.com` | 403 to automation, live |
| `monster.com` | 403 to automation, live |
| `pallet.com/spotlight` | **404**, replaced with `pallet.com/` (200) |
| `leanhire.beondeck.com/` | 200 |
| `dice.com/` | 200 |
| `polymer.co/blog/best-applicant-tracking-software` | 200 |
| `managementstudyguide.com/goal-setting-theory-motivation.htm` | 200 |
| `surveymonkey.com/curiosity/employee-recognition-and-retention/` | 200, June 2019 data, **replaced** |
| `talkspace.com/research/stress-in-the-workplace` | 301 to `/research`, article gone, **replaced** |
| `flexjobs.com/blog/post/flexjobs-mha-survey-...` | HTTP/2 stream error, July 2020 data, misstated, **replaced** |
| `linear.app/`, `clickup.com/`, `asana.com` | 200, 200, 200 |
| `hire.wrk.xyz/register` (x2) | 200 via 301 to `app.polymer.co/register`, **left alone** |
| ~~`nfib.com/news/monthly_report/jobs-report/`~~ **replaced 2026-08-07 by `nfib.com/news/press-release/nfib-jobs-report-small-business-employment-index-picks-back-up-4/`** | Cloudflare interstitial to curl, 200 in a browser, datelined August 6 2026, states both figures |
| `bls.gov/news.release/archives/jolts_03132026.pdf` (new) | **200 to curl with an identifying User-Agent**; states "Annual quits decreased by 1.3 million in 2025 to 38.0 million" |
| `gallup.com/workplace/650174/...` (new) | 200 |
| `eaglehillconsulting.com/news/workforce-burnout-survey-2025/` (new) | 200 |
| `apa.org/pubs/reports/work-in-america/2023-workplace-health-well-being` (new) | 200 |

The `hire.wrk.xyz/register` CTA at blocks 127 and 128 was deliberately **not** touched. It is alive
and 301s correctly to `app.polymer.co/register`; `logs/phase-6-wrk-legacy.md` line 136 already
records it and assigns it to `item-16-redirect-links`, which owns redirect hops. Changing it here
would have stepped on that item.

## Not done, deliberately

- **The merge and the redirect.** Tab 13 row 9 and tab 01 row 12 both point at folding this post into
  a broader hiring guide or a hiring-ops cluster. Out of scope by instruction. Slug unchanged, no
  redirect proposed, no internal link added or removed.
- **Answer-first restructuring.** Nothing was reordered, no heading changed, no section added or
  removed. Block count is 129 before and 129 after, and the `toc` block is untouched, so the
  generated table of contents is identical.
- **No new prose.** Every edit is a replacement inside an existing sentence or an existing block.
  No paragraph, list item, table row or image was added.
- **No downloadable template.** Tab 13 row 9's scope does not ask for one, unlike rows 1, 3 and 9's
  neighbours. The post describes a job scorecard in blocks 42 to 50 and a template would fit there
  naturally, but that is new content, not a refresh. Noted for Jessica rather than built.
- **Three pre-existing em-dashes were left in place.** Blocks `b5ed5257bccc` (0), `0145cbdbec92`
  (117) and `ac800687989f` (123) contain them. None is in a block this run touched, and rewriting
  untouched prose to strip them is the restructuring the brief forbids. Nothing written this run
  contains one; the patch script was scanned for em-dashes before it ran.
- **~~One orphan `markDef`~~ SEVEN orphan `markDefs` left alone. The count below was wrong;
  corrected 2026-08-07, see "Fix pass".** Block `05ad4cf09253` (118) declares markDef `c959b8cb2e3a`
  pointing at the dead Talkspace URL, but no span in that block carries the mark, so it renders
  nothing. The live copy of that markDef, on block 119, was repointed at Eagle Hill. Patching a
  block for zero rendered effect was not worth the diff. The same is true of six others, all
  pre-existing and all listed in the Fix pass.
- **Metadata not touched.** `pageTitle`, `editorialTitle`, `metaDescription` and `publishDate` are
  unchanged. Tabs 07 and 12 own those and `logs/phase-4-fixes-round-3.md` already records this
  post's title.

---

# Fix pass

Run 2026-08-07, after an independent verifier read the draft. Five findings came back for this post,
one MED and four LOW. All five were worked. Four edits landed on the draft and four more things
surfaced on the closing re-read. Sanity draft only, published document still on its 2023 revision.

## Document

| | |
|---|---|
| Draft patched | `drafts.934c12d9-28de-4645-8cd7-3b6a504531d5` |
| Rev in | `kJ3OpIOJnJS2LKJpQphFPB` |
| Rev out | `QzNVnRn1RN9Wy2ys8Qux1F` |
| Published, unchanged | `i7ljIeEeav1WO3JfFunmjG`, `_updatedAt` 2023-03-02T19:45:42Z, and its block 2 still reads "another survey found that 50% of small business owners" |
| Content blocks | 129 in, 129 out |
| `author` | `author-jessica-gertig`, untouched |
| `updatedDate` | 2026-08-06, untouched |

Three narrow `.patch().set()` calls, each guarded with `ifRevisionId` against the rev it read, each
keyed on a single `content[_key==...]` path. No array was rewritten.

## MED. The NFIB citation pointed at a rolling hub on a false claim of unreachability

**Defect. Fixed.** The verifier is right on both counts and the reason recorded in this log was
fabricated. What the withdrawn paragraph claimed: `nfib.com` "returns 403 to every automated client"
and the July press release "is not yet in any search index", so no permanent URL was available.

What is actually true, checked this pass:

- `https://www.nfib.com/wp-content/uploads/2026/08/July-2026-Jobs-Report_FINAL.pdf` returns **200 to
  plain curl**, 460,938 bytes of `application/pdf`. Its text extracts with
  `gs -q -dNOPAUSE -dBATCH -sDEVICE=txtwrite -sOutputFile=- file.pdf` and reads "Fifty-one percent
  (85% of those hiring or trying to hire) of owners reported few or no qualified applicants for the
  positions they were trying to fill (unchanged)" and "In July, 36% (seasonally adjusted) of small
  business owners reported job openings they could not fill in the current period, up 4 points from
  June". Both figures, verbatim, in a URL with the month in its path.
- `nfib.com` is Cloudflare-gated, not blocked. Loaded in a browser it serves the whole site,
  including its own search at `https://www.nfib.com/?s=July+2026+Jobs+Report`, which returns the
  dated press release.
- Search indexing has nothing to do with whether a URL resolves. That was the load-bearing error.

**The link now points at `https://www.nfib.com/news/press-release/nfib-jobs-report-small-business-employment-index-picks-back-up-4/`.**
Read in a browser: datelined "August 6, 2026", `<link rel=canonical>` to itself, and it states
"In July, 36% (seasonally adjusted) of small business owners reported job openings they could not
fill" and "Fifty-one percent of owners (85% of those hiring or trying to hire) reported few or no
qualified applicants for the positions they were trying to fill". The HTML release was taken over
the PDF because a link in body copy that opens a PDF is worse for a reader; the PDF is recorded here
as the equally valid alternative.

Patch: `content[_key=="84bbcc0faeda"].markDefs[_key=="6a95596523ae"].href`. Prose untouched, so the
sentence still names July 2026 and now sits under a page that will still say 51% and 36% next month.

## LOW. The orphan `markDef` count was 1 and is 7

**The report was wrong; the document is as the verifier describes. Report fixed, document left
alone.** Every one of the seven is pre-existing and every one renders nothing, because no span in
its block carries the mark:

| Block index | Block `_key` | markDef `_key` | href |
|---|---|---|---|
| 15 | `9fa179b34601` | `81afa7412631` | researchgate.net Trevor, Gerhart and Boudreau 1997 |
| 62 | `3bbad75d33fa` | `85e1084fad03` | `https://www.linkedin.com/` |
| 81 | `e6251f2dffcc` | `f812faa81e67` | `https://www.polymer.co/blog/best-applicant-tracking-software` |
| 95 | `b7c2f0aa00af` | `e6758cf6e1b4` | `https://www.managementstudyguide.com/goal-setting-theory-motivation.htm` |
| 118 | `05ad4cf09253` | `c959b8cb2e3a` | `https://www.talkspace.com/research/stress-in-the-workplace` |
| 120 | `e6fddaf3e6d6` | `3f762bd195b6` | the FlexJobs URL with its `cjevent=` affiliate parameter |
| 127 | `3b02d184f49e` | `61b36de90dad` | `https://hire.wrk.xyz/register` |

The shape is consistent and explains itself: in every case the block immediately after it carries a
live markDef with the same `_key`, so these are copies left behind when the post was imported, not
anything this build made. Five of the seven mirror links that are still live in the post. Two,
blocks 118 and 120, mirror the two URLs the refresh retired.

Left in place, deliberately. They render nothing, they were not created by this build, and stripping
two of seven leaves an inconsistent document while stripping all seven is a cleanup nobody asked
for. Recorded so it is not silent: if you want the two retired URLs out of the stored content, it is
`set` on `content[_key=="05ad4cf09253"].markDefs` and `content[_key=="e6fddaf3e6d6"].markDefs` to
`[]`, with no rendered change either way.

## LOW. Gallup's 65% is narrower at source than the sentence said

**Half right, and the half that is right was worth fixing.** Read at source this pass, 200 to curl.
Gallup's sentence: "These employees are 65% less likely to be actively looking or watching for
another job opportunity compared with those receiving lower-quality recognition." The post stopped
at "another job", which drops the comparison group and invites the reader to assume the comparison
is against people getting no recognition. The clause now ends "than those getting lower-quality
recognition".

The verifier's other point, that "high-quality recognition" compresses "recognition meeting at least
four of its five pillars", is compression rather than misstatement and was left: "high-quality
recognition" is Gallup's own label, used in its own headline sentence. The companion figures verify
verbatim on the same page: "tracking the career paths of nearly 3,500 employees from 2022 to 2024"
and "well-recognized employees are 45% less likely to have turned over after two years".

Patch: `content[_key=="6238ba74710e"].children[_key=="2c0fc798f1502"].text`. The link mark on
"well-recognized employees were 45% less likely" is on a different span and was not touched.

## LOW. Tab 01 row 12's link column was treated one way here and another way on another post

**Jessica's call. Nothing changed here.** The verifier is right that declining both halves of
"Link; fold into hiring-ops cluster" is correct for this post and right that another post in this
build acted on the same column. Both readings are defensible, because that instruction can mean "add
internal links" or "fold this post into the cluster". The slug is unchanged, no redirect is
proposed, no internal link was added or removed, per instruction. Recorded in QUESTIONS-FOR-JESSICA
under this post's item 1 so the difference is hers to settle rather than something two agents each
decided quietly.

## LOW. The Pallet sentence is the one place this run authored prose

**Correct, and re-reading it found a claim underneath that nothing supports. Fixed.** The rewritten
sentence ended "before it left hiring for supply chain software". That asserts the community-hiring
Pallet became the logistics Pallet. Its cited page, `https://www.pallet.com/`, does not say so, and
this log contradicted itself about it, calling the site "a different company's product" in the same
section.

What the record actually shows:

- Internet Archive, `https://web.archive.org/web/20220601175755/https://www.pallet.com/`: "Pallet,
  Unlocking Talent In Internet Communities".
- Internet Archive, `https://web.archive.org/web/20240614015604/https://www.pallet.com/`: "Pallet: We
  help you make key hires, faster", still hiring, "a search firm trusted by the world's best
  professionals".
- Internet Archive, `https://web.archive.org/web/20250710010814/https://www.pallet.com/`: "Pallet |
  AI Logistics Workforce", with a $27M Series B announcement.
- `https://www.pallet.com/company` today: "We started Pallet because too much of supply chain still
  runs on legacy systems and tribal knowledge." No hiring past anywhere on it.
- `trypallet.com` 301s to the logistics site; `pallet.ai` is a parked domain for sale.

A pivot and a domain changing hands both fit that, and no page states which. So the clause goes,
per the rule that a claim whose cited page does not state it is a defect even when the claim might
be right. The sentence now reads:

> The screenshot below is from **Pallet**, which grouped job seekers by characteristics into
> "Collectives". The Collectives are gone from pallet.com, which now sells supply chain software.

Both halves are checkable: `pallet.com/spotlight` is a 404 and `pallet.com` sells supply chain
software. Patch: `content[_key=="acfe9c031572"].children[_key=="1df1c51e3bf612"].text`. The "Pallet"
link still points at `https://www.pallet.com/`, which is now exactly what the sentence tells the
reader they will find.

## Not named by any finding: the Pallet screenshot's credit is rendered on the page

`web/pages/blog/[slug].js:151-174` defines `SourceRenderer`, which prints a `figcaption` under any
body image carrying `source` or `sourceUrl`, and with a `sourceUrl` alone it prints the bare URL as
both the link and its text. The image credit under the Collectives screenshot was therefore rendering
as "Source: https://www.pallet.com/", pointing a reader at a page that has never shown that
screenshot.

The page that did show it is archived. `https://web.archive.org/web/20220702211721/https://www.pallet.com/spotlight`
returns 200, is titled "Spotlight, Curated Candidates In Your Inbox", and carries all four
collectives with every count the alt text lists: Lenny's Collective "90+ Product Managers, 90+
Startup Operators, 50+ Growth Marketers, 20+ Data Engineers, 15+ Software Engineers", The Not Boring
Collective, Gaby's Web3 Collective and Old Girl's Club Collective, each matching.

Set `content[_key=="f215f572ad7b"].sourceUrl` to that capture and
`content[_key=="f215f572ad7b"].source` to "Pallet Spotlight, archived July 2022", so the rendered
credit is a short readable label rather than a bare URL. The image is still recorded for Jessica as
a removal candidate; if she drops the block the credit goes with it.

## Re-read of the whole draft, everything else

All 129 blocks read again end to end, plus `pageTitle`, `editorialTitle`, `metaDescription`,
`publishDate`, `featureImage` and every `markDefs` href.

Every source that carries a figure was opened again and checked against the sentence it supports.
This is the check the original run could not complete on three of them:

| Sentence | Source | Result |
|---|---|---|
| 51% and 36%, July 2026 | NFIB press release, in a browser | States both verbatim, datelined August 6 2026 |
| "38.0 million Americans quit in 2025" | `bls.gov/news.release/archives/jolts_03132026.pdf`, **200 to curl with an identifying User-Agent** | "Annual quits decreased by 1.3 million in 2025 to 38.0 million and accounted for 60.6 percent of total separations" |
| 45% and 65%, recognition | Gallup, 200 to curl | Both verbatim, plus "nearly 3,500 employees from 2022 to 2024" |
| 55% burnout | Eagle Hill, 200 to curl | "More than half of the U.S. workforce (55%) is experiencing burnout", dated Arlington, Va., November 24, 2025 |
| 67% against 23%, flexibility | APA 2023 Work in America, **Incapsula interstitial to curl, 200 in a browser** | "Workers who said they did not have the flexibility to keep their work and personal life in balance were more likely to report that their work environment had a negative impact on their mental health (67%) compared with those who did have that flexibility (23%)" |

Every other outbound link re-tested and live: `hbr.org/2021/05/why-start-ups-fail` 200,
`scaling4growth.com/.../Who.pdf` 200, `youtube.com/embed/wTgQ2PBiz-g` 200,
`polymer.co/blog/best-applicant-tracking-software` 200, `managementstudyguide.com` 200,
`leanhire.beondeck.com` 200, `dice.com` 200, `pallet.com` 200, `linear.app` 200, `clickup.com` 200,
`asana.com` 200, `hire.wrk.xyz/register` 200 via 301 to `app.polymer.co/register` and still owned by
`item-16-redirect-links`.

Checked and found sound, so not changed:

- **"Sign up for a free trial" in the closing CTA.** `logs/phase-5-pricing.md` records
  `web/pages/pricing.js:194`, "a 14-day free trial when you publish your first job", so the offer the
  sentence names still exists.
- **"Job sites like Indeed and Monster".** Monster went through Chapter 11 in June 2025 and the job
  boards were sold to Bold, but the site is live and still a job board.
- **The three pre-existing em-dashes**, blocks `b5ed5257bccc` (0), `0145cbdbec92` (117) and
  `ac800687989f` (123). None is in a block either pass touched. Both patch scripts were scanned for
  em-dashes before they ran and neither contained one.
- **`pageTitle`, `editorialTitle`, `metaDescription`, `publishDate`, slug.** Untouched, and the slug
  is unchanged per instruction.

## What this pass changed in QUESTIONS-FOR-JESSICA.md

Two entries were stating things that are not true, and both were rewritten in place rather than
annotated below the fold, because she reads that file to decide:

1. This post's item 2 said the link goes to NFIB's monthly hub because nfib.com 403s every automated
   client and the dated URLs are not indexed. Rewritten: the reason was false, the dated press
   release is cited now, and the withdrawn claim is quoted so the change is visible.
2. The "Images that need regenerating" entry and the images table both said "Pallet is a supply
   chain and logistics AI company", asserting the same continuity the post's sentence asserted.
   Corrected to what the archive record supports, with that record set out.

Also amended there: the fix-pass summary at the head of this post's section, the note that the
Gallup clause gained its comparator, the note that the image credit is rendered text and now points
at the archived page, the tab 01 row 12 inconsistency for her to settle, and a new row in the
blocked-hosts table for `apa.org`, which serves an Incapsula interstitial to curl and loads normally
in a browser.
