# To-do — Jessica

## Merges

Each PR was based on the branch below it, so `#48` and `#49` landed one branch short of `main` rather than in it. Merge order that fixes it:

1. `#56` — phase 3 plus every cleanup round, straight to `main`
2. `gh pr edit 53 --base main`, then merge `#53` — carries phases 4 through 8
3. `gh pr edit 54 --base main` and `gh pr edit 55 --base main`, then merge both
4. Close `#50`, `#51`, `#52` — their content is inside `#53`

All six are `MERGEABLE` and every branch builds on Node 16.20.2.

## Vercel

- Serve `robots.txt` on the apex host (Settings → Domains → `polymer.co`)
- Set `POSTMARK_SERVER_TOKEN`, and verify `contact@polymer.co` as a Postmark sender — without both, the contact form reports a send failure
- Collapse the double hop on `http://polymer.co` (two 308s today)
- HSTS preload — lowest priority, and `includeSubDomains` binds `app`, `help`, `jobs` and `developer` too

## Search Console

- Submit `https://www.polymer.co/sitemap.xml` after deploy

## Sanity Studio

- Deploy the Studio (separate Vercel project) so `updatedDate` and `author` appear in the editor
- Publish the drafts

## Supply

- Two headshots
- Regenerate the Gallup card on `/blog/problem-solving-interview-questions` — 2016 figure, "Millenials" misspelled in the graphic, and no current like-for-like number exists
- Reshoot the scoring matrix screenshot — shows `7/11/2022` and the Google Sheets UI; used on `/blog/problem-solving-interview-questions` and `/blog/behavioral-interview-scoring-matrix`

## Review

- Keep reading section styling

## inflow-ats

- `datePosted` on job postings is `2025-12-18 17:29:22 UTC`, not the ISO 8601 Google requires
