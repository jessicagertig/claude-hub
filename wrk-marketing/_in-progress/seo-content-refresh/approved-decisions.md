# Approved decisions — SEO content refresh

Tab 01 rows 7-16 and tab 13 rows 7-15 of the MakeReality technical SEO audit. One decision per section, each restated and confirmed before it was written here.

---

## Decision 1 — `/blog/employee-turnover`: replace every dated statistic

**Tab 13 row 2 refresh scope:** "Add 2026 benchmarks, turnover-rate calculator block; biggest strike-distance upside"

**What the post already has, established by reading the live page:** the turnover-rate formula in prose under the H2 "How to calculate your employee turnover rate", with a worked example `4/50 x 100 = 8%`. So the calculator half of the row is largely present as prose.

**Approved:** every dated statistic in the post gets replaced with a current figure AND a current source URL. That covers:

- hospitality quit rate 66.8%
- retail quit rate 50.6%
- financial services quit rate 17.8%
- all-industry employment separation rate 32.7% for 2021
- the PwC Hopes and Fears percentages (62% hybrid preference, 23% environmental impact)
- the Gallup Great Resignation figures
- the DDI figure (57% quit because of their boss)
- the H2 heading "What people want from their employers in 2022"

**Sources:** the four publishers already cited — BLS JOLTS (`bls.gov/news.release/jolts.t18.htm`), Gallup, PwC, DDI — are the first place to look. A different publisher is acceptable if it carries the current equivalent.

**URLs are part of the deliverable**, not optional. Every updated figure ships with the URL of the source that states it.

**"2026 benchmarks" means the most recent figure that exists, whatever year that is.**

Look for 2026 first, every time, for every figure. Some publishers release monthly or quarterly and will have 2026 data; some release annually and will not. Do not assume either way, and do not decide up front which year to target — establish per figure what the most recent published value actually is, and take that one.

Only fall back to an earlier year for a figure where a 2026 value genuinely does not exist yet. Falling back is a per-figure finding, never a starting assumption, and never applied across the post because one figure needed it.

The sentence carries the year the figure belongs to, so nothing reads as more current than it is.

Escalate to `QUESTIONS-FOR-JESSICA.md` only when no reasonably recent equivalent exists at all — not because 2026 specifically is missing.

**Nothing is silently left stale and nothing is silently dropped.** If a current figure cannot be reached directly, search to establish whether one exists:

- exists but unreachable → named entry in `QUESTIONS-FOR-JESSICA.md` stating the figure sought and where it should live
- no longer published at all → same file, stated as such

Leaving an old figure in place while updating its neighbours is not acceptable.

---

## Decision 2 — image alt text is part of the refresh, plus a final pass over everything else

**Why:** an answer engine cannot read a picture. A graphic carrying information — a formula, a scorecard, a rating scale — contributes nothing to AEO unless its alt text carries that information in words. Thin alts like "Screenshot of candidate scorecard example" describe the file, not the content.

**Approved, two parts:**

1. **Per post we refresh** — an agent views that post's images on the Sanity CDN and writes descriptive alt text from what the graphic actually shows, not inferred from the surrounding paragraph. Part of that post's refresh, in the same draft.

2. **A final separate pass** over every remaining post we did not otherwise touch — alt text only. Nothing else in those posts changes.

**Mechanism:** agents in a workflow, one per post, each viewing its own images, followed by a verifier. Not done inline by the orchestrator.

---

## Decision 3 — `/blog/employee-turnover`: verify the formula itself, and make it an extractable block

**Tab 13 row 2:** "Add 2026 benchmarks, turnover-rate **calculator block**"
**Tab 01 row 9:** "Link + refresh; **formula & benchmark blocks for AEO**"

The word in both rows is *block*, and tab 01 says *for AEO*. That is a structural requirement, not a content one: a discrete unit an answer engine can lift whole.

**What is there now:** a paragraph instructing the reader to divide, divide again, then multiply by 100, with the worked example `4/50 x 100 = 8%` in running text, alongside an image of the calculation. Prose plus a picture is not an extractable block.

**Approved:**

1. **Research whether the standard method for calculating employee turnover has changed** before rewriting anything. The post's method may itself be out of date. Findings drive what the block says.
2. Render the formula and the worked example as a discrete block in real text, extractable without reading the paragraph around it.
3. The benchmarks likewise become a block rather than figures scattered through prose.
4. The existing calculation image gets descriptive alt text per Decision 2, so it stops being the only carrier of the method.

---

## Decision 4 — dated data is found by surveying the post, never from the orchestrator's list

**The orchestrator's reading of a post is a hint, not an inventory.** Skimming rendered HTML for `%` and four-digit years misses "a recent study found", "last year", a named report with no date attached, and practices that have since changed.

**Approved:**

- The agent working a post surveys that post itself and finds everything dated. No prompt narrows what it is allowed to look for, and no list from the orchestrator bounds it.
- After the work is done, a second pass re-surveys the post to confirm nothing dated remains.
- Applies to every post, not only the ones where something dated was already spotted.

---

## Decision 5 — `/blog/problem-solving-interview-questions`: leave the ten examples, update the data

**Tab 13 row 1:** "Update examples, add 2026 context + author byline + dateModified schema; keep URL"
**Tab 01 row 7:** "Link from /blog + related posts; include in sitemap; refresh" · Why it matters: "Site's #1 traffic asset; #1 on five 590-vol terms"

**Established by reading all ten examples in full:** none is stale. They are timeless behavioural questions and reference no dated technology, practice or event. The audit names no defect in them.

**Approved for this post:**

- **The ten example questions and their model answers are not touched.** Rewriting the body of a page ranking #1 on five 590-volume terms risks the ranking for no identified gain.
- Every dated figure found by the survey is replaced with the most recent published value and its current URL, per Decision 1. The Gallup figure "59% of Millennials believe a job that accelerates their professional development is important" is one known instance, not the boundary of the work.
- Author byline and `updatedDate`, per the code and schema decisions.
- Descriptive alt text on every image, per Decision 2.
- Internal links per tab 01.

**Deferred to `QUESTIONS-FOR-SHAWN.md`, and not blocking any of the above:**

- What "add 2026 context" means on a post whose subject is problem-solving interview questions specifically, not interviewing practice generally. Candidates the orchestrator proposed — AI in screening, remote and async interviewing — are off-topic for this page and would dilute it. Replacing old data proceeds regardless; the two are not mutually exclusive.
- Whether "update examples" referred to something specific Shawn saw in those ten.
- Whether to promote "What to look for in a good answer" and "Red flag answers" from paragraphs to H4. **This is the orchestrator's idea, not the audit's, and it does not proceed without Shawn.** We are not SEO experts and an HTML-validity argument is not an SEO argument.

---

## Decision 6 — images carrying figures go stale when the prose is updated, and must be caught

Many images on the blog are graphs, tables and screenshots carrying statistics. An image is pixels: it cannot be edited by an agent. So replacing a figure in the prose while its graph still shows the old one leaves the post contradicting itself, and no text-level check catches it.

**Approved:**

1. The agent working a post **views every image in it** and records what each actually shows — figures, labels, dates, any claim rendered as pixels. This is the same viewing pass as Decision 2 and produces both outputs at once: the alt text, and the record of what the image asserts.
2. For every statistic replaced in the prose, the agent checks whether any image in that post carries the same figure.
3. Where one does, the image is recorded as stale in `QUESTIONS-FOR-JESSICA.md` under a dedicated section — **"Images that need regenerating"** — with, for each entry:
   - the blog post slug
   - which image, and where in the post it sits
   - the statistic being changed, old value → new value
   - the source URL the new value comes from
4. **A figure whose graphic would go stale is held. Every other figure in the same post still gets updated.**

This is per figure, never per post. A post typically carries several dated figures and only one or two of them appear in a graphic. Hold exactly the figures that a graphic would contradict; update everything else in that post normally.

Worked example: a post has four dated figures. One of them also appears inside a bar chart. Three get replaced. The fourth stays as it is, and goes in the "Images that need regenerating" section with its old value, its new value and the source URL, so Jessica can commission the graphic and the text edit together later.

5. **The byline and `updatedDate` always land, on every post, regardless.** They do not depend on any image. A post with a held figure still gets its author and its updated date — those are the point of this work and nothing defers them.

6. **A held figure is fully researched and fully documented, never skipped.** The agent finds the current value and its source URL exactly as it would for a figure it is about to write, then records rather than writes it. The entry carries the post slug, which image and where in the post it sits, the old value, the new value, and the source URL — so when the graphic is commissioned the replacement figure is already established and the text edit ships with it.

---

## Decision 8 — "answer-first" defined, and it does not apply to currently ranking posts

**Jessica's definition:** one block of text near the top that answers the question the whole article is asking, immediately.

**Approved:**

- **Currently ranking articles are not restructured to achieve it.** There is no reason to restructure an article that already ranks. Where the audit asks for answer-first treatment on a ranking post, it is recorded and left.
- Answer-first structure is for **new articles**, which can be written that way from the start. That is content-plan work, not this engagement.
- On `/blog/problem-solving-interview-questions` specifically: left alone. One idea recorded and not acted on — linking from the intro paragraph directly to the "10 examples" section, since a table of contents already exists.
- The same reasoning applies to `/blog/interview-feedback-examples`, tab 13 row 4, "Refresh examples; answer-first blocks" — it ranks pos 5-29 across the feedback cluster.

---

## Decision 9 — `/blog/problem-solving-interview-questions`: the SHRM figure is the refresh

Supersedes the data half of Decision 5 for this post.

**The figure to add,** supplied by Jessica:

> Cost to hire: **$5,475**
> Source: https://www.shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports--how-does-your-organizat

**The agent fetches this number from the source itself and uses it.**

**Do NOT describe it as a non-executive average.** The source distinguishes non-executive from executive; the executive figure is roughly $25,000. Most Polymer users are not hiring executives, so the qualifier is noise. State the figure plainly as the cost to hire.

**The Gallup millennial statistic is HELD, not updated.** It appears in a graphic, so under Decision 6 it is researched, recorded in "Images that need regenerating", and left in the prose. Jessica does not want that graphic touched in this pass.

---

## Decision 10 — `/contact`: research Intercom, fall back to email

Supersedes the master prompt's "ship the 301 and log the page build". Shawn's own prioritised action list, item 2, says restore `/contact` flatly and calls it Claude-automatable, with no "if a design exists" qualifier.

**Approved:**

1. **Research whether Intercom can back a contact form** — whether a form on `/contact` can submit into Intercom as a conversation.
2. **If it cannot, build the email version:** the form composes a formatted email and sends it to `contact@polymer.co`.
3. **Jessica wants the message in her email either way.** Intercom's tracking is not a substitute for that. If Intercom is used, email delivery still has to happen.
4. The `/contact` entry in `redirects()` in `web/next.config.js` is removed in the same change that adds the page — a redirect shadows a page of the same path.

---

## Decision 11 — the best-ATS listicle refresh

`/blog/best-applicant-tracking-software`. From Shawn's supplementary material: *"2026 refresh with a real comparison table — and Polymer's honest placement in it."*

**Jessica's direction:** honest placement, with a slight upward nudge. Choosing what counts as a small-business ATS matters and is part of the work.

**Not yet decided, and needed before this one can be written:** which ATSs appear in the comparison table, and which columns it compares.

---

## Decision 7 — `/blog` gets URL-based pagination, 5 posts per page

**Overview issue #1, Recommended fix:**
> "Add full blog pagination/archive to /blog, add related-post links from crawlable posts, and include every post in the new XML sitemap. Then refresh the assets (see Content Freshness)."

**What shipped in PR #47 and why it is wrong.** An agent deleted `POSTS_PER_PAGE`, the `visibleCount` state, the `loadMore` handler, the `ButtonNew` import and `Styled.LoadMoreWrapper`, leaving `/blog` rendering all 26 posts in one list. That is a removal, not an addition. The fix says *add*, and names two options — pagination or archive. Neither exists on the branch. `/blog` is simply back to what it was before the Load more button was written.

The choice between the two options was Jessica's to make and an agent made it.

**What the audit was actually complaining about:** not that pagination existed, but that it had no URLs. The Load more button paginates with JavaScript, so a crawler saw five post links and no `/blog/page/2` to follow. Nine legacy posts plus `/blog/best-job-board-software` had no incoming internal link from anywhere on the site.

**Approved:**

1. **URL-based pagination on `/blog`.** Real routes a crawler can follow, server-rendered.
2. **Five posts per page**, unchanged from `POSTS_PER_PAGE`. That is the number that fits the layout.
3. **Every page URL goes in the sitemap**, alongside every post URL.
4. The full-archive-on-one-page state currently on the branch is replaced by this.

