# Handoff — Polymer SEO engagement

State as of 2026-08-06. Written because context is running out mid-session.

**Read these three first, in this order:**

1. `SHAWN-SOURCES.md` — the reading rules, and the definitions that are easy to miss
2. `JESSICA-TODO.md` — what Jessica has to do, none of it blocking
3. This file

---

## The one thing that cost the most time today

**The Overview tab's "Recommended fix" column defines the terms every detail tab then uses bare.** It was not read for hours, and an hour of Jessica's morning went on inferring a definition that was sitting in one cell.

**Overview K23, the fix for issue #13:**

> "Refresh each post (2026 data, updated modified dates, author bylines, downloadable templates), in the order given in the detail tab."

That is what "refresh" means everywhere it appears on tabs 01 and 13. Four things. No new prose.

**Read the Overview's columns J and K before touching any detail tab.**

Two more rules from the same lesson:

- **Overview describes, detail tab specifies.** Where both mention a thing, the Overview gives the shape and the detail tab gives the exact value. They are not two sources to reconcile. Overview #17 says "'Plato AI candidate review' phrasing"; tab 17 row 7 gives the string. The tab's string ships.
- **Nothing in the workbook is optional.** Tab 08 labels `llms-full.txt` "Optional second file" and that was read as permission to skip. Overview K8 says publish it. It is now built.

---

## How Jessica works, learned the hard way

- **Quote the tab. Never paraphrase an instruction into a plan.** Say what the cell says, then act. "The tab asks for X" when the tab does not say X is the single worst failure mode here, and it happened repeatedly.
- **Never dress up your own idea as the audit's.** If it is not in the workbook, say so plainly and put it in `QUESTIONS-FOR-SHAWN.md`. We are not SEO experts. An HTML-validity argument is not an SEO argument.
- **State what you are about to do, then do it.** Do not announce work as started and then not start it. That happened three times today.
- **Do not go off and act mid-discussion.** While a plan is being talked through, nothing runs.
- **Dispatch, do not do.** The orchestrator's job is agents, judgment and commits. Not hand-editing.
- **Under-informing and over-informing are both failures.** Say the issue in one line. When asked a question, answer that question.
- **Minutiae that a judgment call can settle do not go to her.** She has said this explicitly.
- **Do not present a decision the workbook already made.** Several "questions" today were answerable from the tab.

---

## Current state

### Branches, stacked, each PR based on the one below

| PR | Branch | Contains |
|---|---|---|
| #47 | `seo-phase-1-2-deorphan-crawl` | de-orphaning, URL pagination, sitemap, robots.txt, llms.txt, llms-full.txt |
| #48 | `seo-phase-3-redirects-canonicals` | canonicals, /contact 301, apex-to-www hrefs |
| #49 | `seo-phase-4-metadata-headings` | title and meta rewrites, /plato H1, heading outlines, **and the Sanity schema work** |
| #50 | `seo-phase-5-structured-data` | JSON-LD across every template |
| #51 | `seo-phase-6-images-links-headers` | image delivery, dead links, security headers |
| #52 | `seo-phase-7-final-report` | SEO-FINAL-REPORT.md |
| #53 | `seo-phase-8-faq` | the FAQ page, plus the industry-page copy fix |
| #54 | `contact-page` | /contact with a working form. Own worktree. Base is #53 |
| #55 | `small-business-industry-page` | the eighth industry page. Own worktree. Base is #53 |

**Cascade rule:** a change to a lower branch must be merged forward through every branch above it, in order, or the stack diverges. Conflicts have happened at `next.config.js`, `blog.js` and `blog/[slug].js`.

### Ready to merge

**#47 has no open questions.** All seven closed. Jessica may merge it.

#48 and #49 were called ready prematurely — their `QUESTIONS-FOR-JESSICA.md` entries had not been walked through. #47's have been. #48's and #49's have not.

### The cascade trap, now closed

The `Article` JSON-LD in `web/pages/blog/[slug].js` on **#50** read `dateModified: post._updatedAt` and named the Organization as `author`. #49 added the real `updatedDate` and `author` fields but could not fix #50's code from #49's branch, so a clean merge would have silently kept the wrong values.

Fixed on `seo-phase-5-structured-data` in commit `9bc7917`, and cascaded through #51, #52, #53, #54 and #55:

```js
dateModified: post.updatedDate || post.publishDate,
author: post.author ? { "@type": "Person", name: post.author.name } : { "@id": ORGANIZATION_ID },
```

`publisher` stays as the Organization. The now-false comment claiming `blogPost` has no author field was corrected in the same commit.

**The general lesson:** a clean git merge is not evidence the stack is consistent. When a lower branch adds a field an upper branch's code should read, the merge will not connect them. Check by hand.

---

## Decisions made today

Full text in `_in-progress/seo-content-refresh/approved-decisions.md`. Eleven decisions, each restated and confirmed before being written. Summary:

1. **`/blog/employee-turnover`** — every dated statistic replaced with the most recent published figure AND its current source URL. Look for 2026 first for every figure; fall back per figure only where 2026 genuinely does not exist, never as a starting assumption. Nothing silently stale, nothing silently dropped.
2. **Image alt text** — part of each post's refresh, plus a final pass over every post not otherwise touched. Agents view the images; an answer engine cannot read a picture.
3. **`/blog/employee-turnover` formula** — research whether the standard turnover calculation has changed, then render formula and benchmarks as extractable blocks. Tab 01 F9 says "formula & benchmark blocks for AEO".
4. **Dated data is found by surveying the post**, never from the orchestrator's list. A skim for `%` and four-digit years misses "a recent study found". A second pass re-surveys after the work.
5. **`/blog/problem-solving-interview-questions`** — the ten example questions are NOT touched. None is stale, and it ranks #1 on five 590-volume terms.
6. **Images carrying figures** — hold that figure, update every other figure in the post, record the stale image in a dedicated "Images that need regenerating" section with post slug, old value, new value and source URL. **Per figure, never per post.** Byline and `updatedDate` always land regardless. Not a blocker; publishing is Jessica's.
7. **`/blog` pagination** — URL-based, five per page, every page URL in the sitemap. Done.
8. **"Answer-first"** means one block near the top answering the article's core question. **Currently ranking articles are not restructured for it.** That is for new articles.
9. **`/blog/problem-solving-interview-questions`** — the SHRM cost-to-hire figure is the refresh: **$5,475**, source `https://www.shrm.org/about/press-room/shrm-releases-2025-benchmarking-reports--how-does-your-organizat`. **Do NOT call it a non-executive average.** The Gallup millennial stat is HELD — it appears in a graphic.
10. **`/contact`** — built with a form, PR #54.
11. **The best-ATS listicle** — instruction is in `_in-progress/seo-content-refresh/listicle-comparison-table.md`, supplied verbatim by Jessica. Needs her seat-structure wording.

---

## Outstanding work, in order

### 1. The `/features/jobboard` link — DO THIS CAREFULLY

Tab 01 row 16: **"Link from /features/jobboard + blog index; refresh"**

The blog-index half is done. The other half is not, and it has now been built and removed once.

**What was wrong the first time:** an agent added a whole "Keep reading" section — heading, aside, the post's description, a `getStaticProps`, thirty lines of styled components. The row asked for a link.

**Jessica's direction:** bury it in one of the existing sections. **NOT the intro** — she said explicitly that is not buried. **Do not edit existing copy** — she said that too, and it is out of scope.

**What is on the page**, from `web/components/jobBoard/`:

- `intro.js` — H1 "The best job boards around" plus one paragraph. Ruled out.
- `basics.js` — three cards, each with `linkTo` / `linkType` / `linkLabel`. One already points internally at `/features/candidate-management-software` with `linkType: "link"`. **A fourth card here is the closest fit: the link mechanism already exists, and nothing existing gets edited.**
- `features.js` — two blocks with multi-paragraph `description` arrays and an optional `link` object.
- `other.js` — eight short feature tiles, no links.

**The post being linked to** is `/blog/best-job-board-software`, "Best Job Board Software to Improve your Hiring Process" — a roundup comparing Polymer against Niceboard, BambooHR, Notion, Google Sheets, Webflow and WordPress. The comparison angle is the natural hook from a page selling Polymer's job board.

**Confirm the placement with Jessica before building it again.**

### 2. The post refresh

Ten posts on tab 01, nine on tab 13, overlapping. All as Sanity drafts. Per post: survey for everything dated, replace with current figures and current URLs, view every image for alt text and to catch figures a graphic carries, byline, `updatedDate`. Then a re-survey pass.

**Blocked on nothing.** #49 gives it the fields.

### 3. The alt-text-only pass

Every post not touched by the refresh. Alts only.

### 4. The listicle

`/blog/best-applicant-tracking-software`. Instruction file is complete and verbatim. **Needs Jessica's seat-structure wording** for the Polymer collaboration bullet.

### 5. The small business page

Built, sitting uncommitted in `/Users/jessica/wrk/wrk-corp/wrk-marketing.small-business-industry-page`. Needs committing and a PR based on #53.

### 6. `SEO-FINAL-REPORT.md` gets rewritten last

It compiles from everything else.

---

## Two content errors found today, not in the audit

**The dead pricing model is still in live blog posts.** `/blog/best-job-board-software` says "Polymer uses a per-job pricing framework... $10 per published job post per month" and "With no user limit on Polymer accounts". Both false. The same model appears in the help centre and in other posts. The refresh should catch these; they are not on any tab.

**Six industry pages claimed "unlimited team members"**, contradicting the 5/20/50 caps. Fixed on #53. Fintech had already been corrected at some point and the other six were missed. They now name roles rather than count seats, following the healthcare page's pattern.

---

## Mechanics worth not rediscovering

- **The workbook reader:** `python3 read-workbook.py "<tab name substring>"` in the build directory. Surfaces every cell with its coordinate and any meaning-bearing formatting.
- **Sanity:** project `a6d1clb1`, dataset `production`. Write token is `SANITY_API_WRITE_TOKEN` in `web/.env.local`. **Never modify that file. Never copy the token anywhere.** Everything is drafts — patch `drafts.<id>`, never publish, and read an existing draft before patching or you destroy pending changes.
- **The build only works on Node 16.20.2.** `.nvmrc` says 18, `engines` says 22, and Next 12.1.0's squoosh loader fails under undici on both. Jessica has said `.nvmrc` is authoritative and `engines` should be reconciled to it. **That reconciliation has not been done.**
- **Worktrees:** `wt switch --create <branch> --base <base>`. Only for genuinely separate pieces of work — the small business page and the contact page. Everything else is a branch in the base checkout. **Never create one unprompted;** they cost about 10GB each.
- **Worktrees have no `node_modules`.** Symlink the main checkout's `web/node_modules` to run eslint, then remove it.
- **Watchdogs:** every background workflow gets a stall monitor. Stop it when the workflow completes or it fires a false alarm on the silence afterwards.

---

## Pre-existing defects noticed, none of them ours

- `web/components/section.js` line 23 reads `${t.mq[56]} {aer` — a stray token that discards the first declaration of that media-query block, which is where the `thin` prop's only rule lives. On `main`. Affects every page using `Section`.
- A stale `author` document in Sanity, id `ea4ae747-92a5-4fe6-a58b-087efb163f82`, named "Corey Daniels", created 2022, no photo, no role, referenced by nothing.
- A Next dev server has been running on port 3000 since 2026-07-27 serving stale compiled output. Restart it before trusting any rendered-HTML check.
