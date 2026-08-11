# Phase 6, item 2 — dead external links (tab 14)

Owns any file under `web/pages/` or `web/components/` except `blog.js`, `blog/[slug].js`, `next.config.js`. Branch `seo-phase-6-images-links-headers`.

**No file was changed. Zero of tab 14's 20 URLs exist in any file in this repo.** All 20 live in Sanity documents, which another item owns. Everything below is verification handed forward so the Sanity owner does not repeat it.

## How I established that

```
grep -rl "<domain>" --exclude-dir=node_modules --exclude-dir=.git --exclude-dir=.next \
  --exclude=SEO-CHANGELOG.md .
```

run for all 14 distinct domains on the tab (`wrk.xyz`, `crazyegg`, `topgrading`, `pewresearch`, `breezy.hr`, `g2.com`, `capterra`, `quora.com`, `pcmag`, `hrdive`, `onlinelibrary.wiley`, `gusto.com`, `youth.gov`, `grandviewresearch`) — **0 files each**. The only hit in the whole repo was `SEO-CHANGELOG.md:523`, a prior phase recording the same result.

Independently, every external host referenced anywhere in `web/pages`, `web/components`, `web/lib`:

`app.polymer.co`, `www.polymer.co`, `w3.org`, `schema.org`, `googletagmanager.com`, `help.polymer.co`, `polymer.co`, `edoeb.admin.ch`, `widget.intercom.io`, `twitter.com`, `stripe.com`, `ec.europa.eu`, `discord.gg`, `developer.polymer.co`, `aboutads.info`, `youtube.com`, `makelog.com`, `curious.vc`, `bodeswell.io`, `us.i.posthog.com`, `unsplash.com`, `tixel.com`, `termly.io`, `slack.com`, `s.adroll.com`, `piratewires.com`, `nextjs.org`, `joinleland.com`, `helium.com`, `getcampfire.com`, `filebase.com`, `eeetwell.com`, `climate.stripe.com`, `careers.curious.vc`, `ca.la`, `api-iam.intercom.io`, `sitemaps.org`.

No tab 14 domain is in that list. The site-wide crawl that produced tab 14 reached these URLs through *rendered blog pages*, which render Sanity `content`.

## Resolving the tab's truncated and aggregate rows

Five rows were unfetchable as written and two stood for more URLs than they named. I resolved all of them against the live dataset (read-only GROQ over the public API, `projectId a6d1clb1`, dataset `production` — the same values in `web/lib/sanity.js`), not by guessing:

- A8 `5721143-...slack-workspace` → `5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace`
- A9 `5721747-...discord-server` → `5721747-have-new-candidate-notifications-show-up-in-a-discord-server`
- A12 pewresearch → `/social-trends/2022/02/16/covid-19-pandemic-continues-to-reshape-work-in-america/`
- A14 "+3 G2 product pages" → `lever/reviews`, `springrecruit/reviews`, `tracker-ats-crm/reviews` (plus a fourth `lever/reviews` variant carrying a sort query string)
- A18 "hrdive (2 articles)" → `7-in-10-workers-say-theyve-lied-on-their-resumes/696119/` and `recent-grads-unprepared-for-workforce/747746/`
- A20 gusto → `gusto.com/resources/gusto-insights/new-grad-hiring-report-2025`

## The 5 confirmed dead — verified 404, with verified replacements

All fetched with a desktop Chrome UA, following redirects.

| Dead URL | Got | Lives in | Replacement | Got |
|---|---|---|---|---|
| `help.wrk.xyz/en/articles/5280480-configuring-a-custom-domain` | 404 | Sanity `changelog` `914dc19a-965f-4e6d-8187-2db998abba02` | `https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain` | **200** |
| `help.wrk.xyz/en/articles/5721143-...slack-workspace` | 404 | Sanity `changelog` `609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` | `https://help.polymer.co/en/articles/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace` | **200** |
| `help.wrk.xyz/en/articles/5721747-...discord-server` | 404 | Sanity `changelog` `3d2afcd8-1acf-429c-81fa-ece69c210185` | `https://help.polymer.co/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` | **200** |
| `www.crazyegg.com/blog/recooty-review/` | 404 | Sanity `blogPost` `best-applicant-tracking-software` | *none — tab permits removal; see question 2* | — |
| `topgrading.com/candidate-assessment/topgrading-job-scorecard/` | 404 | Sanity `blogPost` `talent-acquisition` | `https://topgrading.com/` (tab's own instruction) | **200** |

Three of the four help articles are a **plain host swap**, `help.wrk.xyz` → `help.polymer.co`, article ID and slug unchanged. That is not a guess about the redirect: `web/components/footer.js` already links `https://help.polymer.co/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` — the identical article ID the dead link uses. The custom-domain article is the exception; it was renumbered 5280480 → 10250419, which I found through the help centre's own search, not by pattern.

## The 15 bot-walled — checked, none touched

Re-fetched with a desktop Chrome UA and normal `Accept` headers. **Six of the eleven rows return 200 to a browser**, which is the tab's thesis demonstrated rather than assumed:

| URL | Crawler | With browser UA |
|---|---|---|
| `pewresearch.org/social-trends/2022/02/16/...reshape-work-in-america/` | 429 | **200** |
| `breezy.hr/` | 403 | **200** |
| `www.pcmag.com` | 403 | **200** |
| `hrdive.com/news/7-in-10-workers-say-theyve-lied-on-their-resumes/696119/` | 403 | **200** |
| `hrdive.com/news/recent-grads-unprepared-for-workforce/747746/` | 403 | **200** |
| `g2.com/` and the 3 G2 product pages | 403 | 403 |
| `capterra.com` | 403 | 403 |
| `quora.com/` | 403 | 403 |
| `onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.2420240606` | 403 | 403 |
| `gusto.com/resources/gusto-insights/new-grad-hiring-report-2025` | 403 | 403 |
| `youth.gov/feature-article/soft-skills-pay-bills` | 403 | 403 |
| `grandviewresearch.com/industry-analysis/human-resource-management-hrm-market` | 403 | 403 |

The still-403 set is Cloudflare/Akamai bot management, which fingerprints the TLS handshake, not the UA string — curl cannot pass it by any header. A 403 from those hosts is evidence of nothing about the link. **None of the 15 should be removed**, and none was.

A17 `http://www.pcmag.com` is the tab's only bot-wall needing an edit (scheme upgrade). `https://www.pcmag.com` returns **200**. That edit is in Sanity `blogPost` `best-applicant-tracking-software`, so it is not mine to make.

## Beyond the tab

- **A sixth dead `help.wrk.xyz` link the tab never listed.** `help.wrk.xyz/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` → **404**, in Sanity `blogPost` `best-applicant-tracking-software`. Same host swap fixes it: `https://help.polymer.co/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` → **200**. Found only because I scanned the raw dataset for the truncated article IDs. Recording it so the Sanity owner fixes four help links, not three.
- **Six legacy `wrk.xyz` links that are alive, not dead.** `www.wrk.xyz/` and four `/blog/` paths plus `hire.wrk.xyz/register`, across `talent-acquisition`, `best-job-board-software`, `a-player`, `agile-recruiting-process`, `onboarding`, `best-applicant-tracking-software`. All **200**, all redirecting correctly (`www.wrk.xyz/` → `www.polymer.co/`, `hire.wrk.xyz/register` → `app.polymer.co/register`). Not dead links and so not my item; they are redirect hops, which `item-16-redirect-links` owns. Left entirely alone.

## What I did not do

I did not scan the 37 external hosts in my own files for other dead links. Tab 14 is the output of a crawl of the rendered site, so a 4xx on any of them would already be a tab 14 row. Widening past the tab would be scope I was not given.
