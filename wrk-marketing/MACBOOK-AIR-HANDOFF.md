# Handoff — wrk-marketing SEO engagement

Written 2026-08-10, to continue on Jessica's MacBook Air.

Read this file first. Then `builds/seo-audit-2026-08-05/JESSICA-TODO.md` for what only she can do, and `builds/seo-audit-2026-08-05/visual-check.md` for what to look at in each PR.

---

## What this is

Shawn at MakeReality.io delivered a technical SEO audit of `www.polymer.co` as a 19-tab workbook plus a master prompt. The work is executing that audit against `wrk-corp/wrk-marketing`, delivered as reviewable PRs. Jessica merges; agents never do.

**The workbook is the source of truth**, at `builds/seo-audit-2026-08-05/Polymer-Technical-SEO-Audit_MakeReality.xlsx`. Read it with:

    python3 builds/seo-audit-2026-08-05/read-workbook.py "<tab name substring>"

**The master prompt** is `builds/seo-audit-2026-08-05/master-prompt-pages-router.md`. That is the edited copy: the original assumed the App Router, and three things were changed for the Pages Router — `app/sitemap.ts` became `pages/sitemap.xml.js`, `metadata.alternates.canonical` became a `<link rel="canonical">` in `components/seo.js`, and "root layout" became `pages/_app.js`. The untouched original sits beside it.

---

## Where the work stands

`main` is at `a6eeb62`. Nine PRs merged: **#47, #48, #49, #50, #51, #52, #56, #57, #58**.

**Three open, all ours, all based on `main`:**

| PR | Branch | What it is |
|---|---|---|
| #53 | `seo-phase-8-faq` | the FAQ page, the industry-page copy fix, the hosted `.xlsx` scorecard |
| #54 | `contact-page` | `/contact`, redesigned from a Claude Design handoff, plus react-select and the form primitives |
| #55 | `small-business-industry-page` | the eighth industry page |

**#24 (`fix-pages-for-mobile-72925`) is not ours.** It predates this engagement and has conflicted with `main` since #47 landed.

Nothing is uncommitted anywhere. Every branch is in sync with origin.

### Worktrees

    /Users/jessica/wrk/wrk-corp/wrk-marketing                               main checkout
    /Users/jessica/wrk/wrk-corp/wrk-marketing.contact-page
    /Users/jessica/wrk/wrk-corp/wrk-marketing.privacy-markup                #57 merged, can be removed
    /Users/jessica/wrk/wrk-corp/wrk-marketing.small-business-industry-page

Use `wt` for all worktree operations, never raw `git worktree`. Each costs about 10GB, so never create one unprompted.

---

## Things that will bite on a fresh machine

**The build only works on Node 16.20.2.** `.nvmrc` says 18 and `engines` says 22, and both fail: Next 12.1.0's squoosh loader dies under undici. Reconciling those three is an open item nobody has done.

    export PATH="/Users/jessica/.nvm/versions/node/v16.20.2/bin:$PATH"
    cd web && npx next build

**Worktrees have no `node_modules` and no `.env.local`.** To build in one, source the main checkout's env and symlink its modules, then remove the symlink:

    set -a; . /Users/jessica/wrk/wrk-corp/wrk-marketing/web/.env.local; set +a
    ln -sfn /Users/jessica/wrk/wrk-corp/wrk-marketing/web/node_modules <worktree>/web/node_modules
    ...build...
    rm -f <worktree>/web/node_modules

`contact-page` is the exception: it has a real `npm install` because it adds react-select. Without the env you get `dataset must be provided to perform queries`, which is the harness, not the code.

**Never modify `.env.local`, never copy it anywhere, never write the Sanity token into a file, log or commit.**

**A stale dev server has been running on port 3000 since 2026-07-27** serving old compiled output. Restart it before trusting anything rendered.

---

## Sanity

Project `a6d1clb1`, dataset `production`. Studio v2, not v3 — `sanity.json`, `part:` imports, no `defineType`.

**Everything this engagement did in Sanity is a draft. Nothing has been published.** 26 blogPost drafts and 5 changelog drafts are waiting.

The one exception, and Jessica has accepted it: three published documents were created — the `author-jessica-gertig` and `author-corey-daniels` records and the placeholder headshot they share. New records, nothing overwritten, and an author renders nothing until a post referencing it is published.

**Every one of the 26 drafts carries an author.** Twelve carry `updatedDate: 2026-08-06` — the eleven refreshed posts plus the ATS listicle.

**The byline will not appear in a preview deploy**, because previews read published content. It needs the drafts published and #53 deployed.

**The Studio cannot run locally.** `studio/node_modules` is broken well past the table plugin: `@sanity/base`, `@sanity/schema`, `@sanity/form-builder` and `react` all have no `package.json`. It needs a reinstall before any Studio work.

Before opening the drafts: **do not click Generate on the slug field.** `blogPost.slug` derives from `pageTitle`, and several drafts change `pageTitle`. One of them is the Webflow post, whose URL carries 8 referring domains.

---

## Decisions that are settled, so nobody re-opens them

- **Shawn's three over-length titles ship exactly as written**, untrimmed. 61, 62 and 61 characters against his own `<=60` rule. His copy, not ours to edit.
- **`editorialTitle` is not changed on any post.** Tab 07 rewrites `<title>` only.
- **`noBrandSuffix` is gone.** `components/seo.js` appends " | Polymer" unless `pageTitle` already contains "Polymer". Jessica's design.
- **`https://ca.la` is alive and its link stays.** A local resolver returning SERVFAIL is not evidence. It 301s to `mercer.design`; CALA became Mercer. Makelog and Bodeswell are genuinely dead and correctly unlinked.
- **Breezy's niche board count is `40+`**, from Jessica counting inside the Breezy app. It is not published anywhere on breezy.hr. **Do not verify it against a public page and do not drop it for lacking a public source.** Recorded in the listicle instruction file.
- **The SHRM cost-to-hire figure is $5,475 and is not described as a non-executive average.** Jessica's call, and it applies to both posts that carry it.
- **Currently ranking posts are not restructured.** No answer-first rewrites, no reordering.
- **`<th scope>` on blog tables was considered and dropped.** It needed a Studio wrapper component around the table plugin, and the gain was never quantified. See below.

---

## The one open technical question

**`fm=webp` on Sanity images was not applied, and Jessica is inclined to apply it.**

Tab 11 asks for it on all 71 Sanity image rows. It was skipped on a measurement, and that call was mine to make and probably should not have been.

The measurement, on the tab's worst image:

| | today | with `fm=webp` |
|---|---|---|
| a visitor | 314 KB AVIF | 401 KB WebP |
| a crawler | 7 MB PNG | 401 KB WebP |

`next-sanity-image` already puts `auto=format` on every URL, so browsers negotiate AVIF. `fm=webp` overrides that rather than adding to it, so it makes every visitor's download bigger while fixing what the crawler sees. Screaming Frog sends no image `Accept` header, which is where the 7 MB figure came from — about 22x real transfer.

Only that one image was measured both ways; there is no total across all 71.

**Jessica's position:** Shawn asked for it, he does this professionally, and she suspects his call is right. It is one line in `web/lib/sanityImage.js` — add `.format('webp')` to the builder. Not yet done.

What did ship on images: a width cap in `noUpscaleImageBuilder` clamping requests to the source width, which took the worst asset from 196 KB to 59 KB for a real visitor, and a `sizes` attribute on ten call sites.

---

## Waiting on Jessica

Full list in `builds/seo-audit-2026-08-05/JESSICA-TODO.md`. The live one:

**The contact form needs `POSTMARK_SERVER_TOKEN` in Vercel.** She set up a new Postmark Server for the marketing site. `polymer.co` is **not** verified in Postmark — only `wrk.company` is, which nobody knew was in use. So one of:

- verify `contact@polymer.co` as a single Sender Signature, confirmed by clicking a link sent to that mailbox, no DNS. Fastest.
- verify `polymer.co` as a domain, DKIM TXT plus a `pm_bounces` CNAME to `pm.mtasv.net`. Lets any address on the domain send.
- verify a subdomain like `mail.polymer.co` for reputation isolation, which is the only option that actually isolates, since receivers key reputation to the DKIM signing domain.

The code currently sends `From: Polymer contact form <contact@polymer.co>`, `To: contact@polymer.co`, `Reply-To:` the submitter. **If the verified sender is anything else, the From line in `web/pages/api/contact.js` has to change to match.**

Also outstanding: the Search Console sitemap submission, the Studio deploy, publishing the drafts, two real headshots, two images to regenerate, and the apex `robots.txt` and redirect-hop settings in Vercel.

---

## What is left to build

**Nothing from Week 1 or Weeks 2-4 of Shawn's action plan**, except the `fm=webp` question above. All merged.

**From Days 30-60**, three of four are untouched: the comparison pages (Workable, Greenhouse, Ashby alternatives), `/features/job-distribution`, and `/features/integrations`. The small-business page is built and sits in #55. The best-ATS listicle is refreshed as a draft.

**Days 60-90 is entirely unstarted**: the AEO anchor set, the Plato repositioning, the interview franchise, and the re-crawl.

Two smaller things owed:

- **The alt-text pass over every post the refresh did not touch never ran.** It was planned and dropped. That is why `hiring-gen-z` and `employer-branding-steps` still have no `featureImage.altText` and show up as missing-alt in the validity report.
- **`html-validity.md`** lists 204 pre-existing validity errors, none introduced by this engagement. Jessica wanted four fixed. `/privacy` is done in #57. Still open: the two missing alts, `<th scope>` (dropped), and three heading skips she wants to review herself.

---

## How to work with Jessica

Learned the hard way over this engagement. These are not style preferences.

**Be the orchestrator, not the fix agent.** Queue instructions and dispatch them as workflows. Hand-editing is what produced every blow-up here.

**Do only what was asked.** Not the adjacent thing, not the thing that fixes the "real cause". Two rounds of work existed purely to remove changes no cell asked for.

**But the mechanism of an authorised change is authorised.** Her words: "If you had to add an href, you needed an a tag." The test is not "is this named in a cell" but "would the thing the cell asks for work without this."

**Quote the cell. Never paraphrase an instruction into a plan.** "The tab asks for X" when the tab does not say X is the worst failure mode available here, and it happened repeatedly.

**One line, then stop.** When a workflow finishes, say it finished and write the detail to a file. A long report dumped into the terminal scrolls away whatever she was reading, and scrolling back on a laptop is painful. `fn+shift+↑` is Page Up on a Mac.

**Answer the question asked, at the scope asked.** She asks about one PR; do not answer about all of them. She asks what a thing looks like; show the code, not a discussion of it.

**Never surface a non-problem.** If it is a defect, fix it. Only a decision she alone can make reaches her, and it reaches her as one short question.

**When she states something about her own systems, it is fact.** Do not verify it. She hedges when unsure and states flatly when certain.

**Branch off the merge branch, never off other work in progress.** That rule is now in `~/.claude/CLAUDE.md`, added after the stacking failure here: nine branches were cut off each other, so every PR was based on the previous PR's branch, and merging delivered each phase into the branch below rather than into `main`.

**Never delete a branch. Never merge to main. Never push to main.**

**No em-dashes. No code comments.** Both are standing rules and both were violated at scale before being cleaned up.

---

## Where everything lives

    ~/claude-hub/wrk-marketing/
      MACBOOK-AIR-HANDOFF.md            this file
      builds/seo-audit-2026-08-05/
        JESSICA-TODO.md                 the deliverable: only things she can do
        visual-check.md                 what to look at per PR, in merge order
        html-validity.md                the 204 pre-existing errors, by cause
        Polymer-Technical-SEO-Audit_MakeReality.xlsx    source of truth
        read-workbook.py                the reader
        master-prompt-pages-router.md   the edited master prompt
        QUESTIONS-FOR-SHAWN.md          open with the auditor
        SHAWN-SOURCES.md                his scattered instructions, and the definitions
        HANDOFF.md                      the earlier mid-engagement handoff
        OVERNIGHT-PLAN.md               the autonomous run's plan and progress log
        post-refresh-record.md          every figure changed, per post, with sources
        logs/                           per-agent run logs
      _in-progress/seo-content-refresh/
        approved-decisions.md           11 confirmed decisions from the refresh
        listicle-comparison-table.md    her verbatim listicle instruction

`QUESTIONS-FOR-JESSICA.md` was deleted at her request. Her words: "every single one that's been in there has been utter bullshit." Anything that was a real task moved into `JESSICA-TODO.md`; everything else became a decision to make rather than ask.
