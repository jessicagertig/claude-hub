# Phase 6, item 3 — Wrk legacy (tab `10 Wrk Legacy`)

Scope: tab 10 rows 7-10, plus (per this item's brief) any dead `help.wrk.xyz` or similar link in
any Sanity post body.

**No file in `/Users/jessica/wrk/wrk-corp/wrk-marketing` was created, edited or deleted.**
This item owns Sanity documents only. Four `drafts.<id>` documents carry changes. Nothing was
published — `.publish()` was never called and no id without a `drafts.` prefix was ever passed to
a mutation. Every published document is byte-identical to its pre-run state, `_rev` included; see
"Verification".

## Headline

Row 7 asks for the Webflow post to be rewritten for the Polymer brand. **Its body is already
fully Polymer-branded and needed no change.** The dead `help.wrk.xyz` links the tab attributes to
that post are not in it — they live in three `changelog` documents and one *other* blog post.
Those are what got fixed.

## Row 7 — `/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site`

Published `_id` `54ea4d1f-deee-47c6-849e-da34989f5736`. **Body unchanged. Slug unchanged.**

What the tab claims (B7): "URL slug + body reference 'wrk'; post links help.wrk.xyz custom-domain
article." Two of those three are not true of this document today:

- **"body reference 'wrk'"** — there is none. Across all 44 content blocks, plus `editorialTitle`,
  `metaDescription`, every image `alt`, and `featureImage.altText`, the string `wrk`
  (case-insensitive) does not occur once. The body says "Polymer" throughout — e.g. block
  `0f9b6fecc9a7` "displays your jobs from Polymer", block `c1d57fe837c9` (h2) "Connect your
  Polymer and Webflow accounts". `editorialTitle` is "Easily display Polymer job posts on your
  Webflow site with our CMS integration". Someone rebranded this body already.
- **"post links help.wrk.xyz custom-domain article"** — it does not. The post's only non-Webflow
  outbound link is `https://app.polymer.co/account/integrations/webflow` (block `9f9708aee269`).
  The `help.wrk.xyz` custom-domain article is linked from `changelog` document
  `914dc19a-965f-4e6d-8187-2db998abba02` dated 2021-06-06, which renders on `/changelog` — see
  the table below. The auditor appears to have attributed a `/changelog` link to this post.
- **"URL slug"** — true, and deliberately left alone. `slug.current` remains
  `use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` (8 referring domains, no
  301 in scope). `https://www.polymer.co/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site`
  returns **200 directly**, no redirect hop.

Its draft `drafts.54ea4d1f-deee-47c6-849e-da34989f5736` was **read and left exactly as Phase 4 left
it** — `pageTitle` only. Post-run check: it differs from published in `["pageTitle"]`, its
`content` differs in zero leaf paths, and its 44 block `_key`s are identical to published. Phase
4's pending change is intact.

## Rows 8-10 (and one the tab missed) — four dead `help.wrk.xyz` links replaced

All four `help.wrk.xyz` URLs return **404**, as does `https://help.wrk.xyz/` itself — the host is
alive but the help centre is gone. The current help centre is `help.polymer.co` (Intercom), which
`web/components/footer.js` line 60 and `web/components/home/integrations.js` already link. Three
of the four articles kept their Intercom article ID across the rebrand, so the fix is a host swap.
The custom-domain article did not — it was renumbered 5280480 → 10250419, found in the
"Job board configuration" collection at
`https://help.polymer.co/en/collections/2625932-job-board-configuration`.

**Every replacement URL below was fetched and returned 200 before it was written.**

| # | Document | Renders at | Leaf path changed | Before | After | Reader-visible |
|---|---|---|---|---|---|---|
| 1 | `changelog` `914dc19a-965f-4e6d-8187-2db998abba02` (2021-06-06) | `/changelog` | `content[1].markDefs[0].href` | `https://help.wrk.xyz/en/articles/5280480-configuring-a-custom-domain` (404) | `https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain` (200) | yes — link text "setup guide" |
| 2 | `changelog` `609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` (2022-04-25) | `/changelog` | `content[2].markDefs[0].href` | `https://help.wrk.xyz/en/articles/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace` (404) | `https://help.polymer.co/en/articles/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace` (200) | yes — link text "setup documentation" |
| 3 | `changelog` `3d2afcd8-1acf-429c-81fa-ece69c210185` (2022-01-03) | `/changelog` | `content[2].markDefs[0].href` | `https://help.wrk.xyz/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` (404) | `https://help.polymer.co/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` (200) | yes — link text "setup documentation" |
| 4 | `blogPost` `fcfc319d-8b14-46d0-aef5-fc1fdd751060` (`best-applicant-tracking-software`) | `/blog/best-applicant-tracking-software` | `content[7].markDefs[0].href` | `https://help.wrk.xyz/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` (404) | `https://help.polymer.co/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` (200) | **no — see below** |

### Notes on the table

- **Rows 9 and 10 of the tab say "(blog posts)". They are not.** Both are `changelog` documents,
  and so is row 8's actual carrier. All three render on `/changelog`, not on any `/blog/` URL.
  `web/pages/changelog.js` line 38 overrides only the `key` mark, so `link` falls through to
  `@portabletext/react`'s default renderer and these are real crawlable `<a href>` elements.
- **Row 4 is not named anywhere in tab 10.** It was found by scanning every document in the
  dataset and is included because this item's brief covers dead `help.wrk.xyz` links in any post
  body.
- **Row 4 renders nothing today.** markDef `dce1a2d61580` in block `a937d5dc8309` is orphaned —
  no span in that block carries it (the block's single child has `marks: []`). It is dead data,
  not a clickable dead link, so fixing it closes no crawler-visible defect. It was repointed
  rather than deleted because deleting a markDef is a bigger structural change than this item was
  asked to make. The *live* version of the same article is already correct two blocks later:
  block `e0995478e9e9` markDef `ad7866ef4c00` carries
  `https://help.polymer.co/en/articles/4436181-have-your-job-posts-appear-in-google-jobs` on the
  span "Google Jobs".
- Document 4 already had a Phase 4 draft changing `pageTitle`. The patch was built from the
  **draft's** content, not the published content, and applied with `.set({content})`, so that
  pending change survives — post-run it differs from published in `["content","pageTitle"]`.

## Drafts to approve in the Studio

- `drafts.914dc19a-965f-4e6d-8187-2db998abba02` — changelog 2021-06-06, one href
- `drafts.609fbb42-fc71-4d5b-a64a-cb7d49d4c11f` — changelog 2022-04-25, one href
- `drafts.3d2afcd8-1acf-429c-81fa-ece69c210185` — changelog 2022-01-03, one href
- `drafts.fcfc319d-8b14-46d0-aef5-fc1fdd751060` — blogPost `best-applicant-tracking-software`,
  one href **plus Phase 4's `pageTitle` rewrite**; approving this draft ships both

`drafts.54ea4d1f-deee-47c6-849e-da34989f5736` (the Webflow post) is listed here only to be
explicit that **this item did not write to it**. It still holds Phase 4's `pageTitle` change alone.

## Verification

After the write, all five documents were re-fetched and compared three ways:

1. **Published vs. the pre-run snapshot** (`all-docs.json`, taken before any mutation), field by
   field excluding `_id`/`_rev`/`_createdAt`/`_updatedAt`: zero differing fields on all five.
   `_rev` is also unchanged on all five, which is the stronger statement — the published documents
   were never written to at all.
2. **Draft vs. published, per leaf path.** Both `content` trees were walked to every scalar leaf.
   Result: exactly one differing path per document, and it is the `markDefs[].href` named in the
   table. No block added, removed or reordered; block `_key` lists identical (2, 3, 7, 134 and 44
   blocks respectively). Every `_key`, every span, every `markDefs` entry not in the map, and
   every other field passed through by reference.
3. **Dataset sweep.** `*[_type in ["blogPost","changelog"]]` was re-scanned for `help.wrk.xyz`.
   Exactly four hits remain, in the four published documents above — i.e. the four the drafts fix,
   and no fifth one anywhere. They stay live until the drafts are published, which is intended.

The same guard ran before the write: the script aborts a document if the walk finds any leaf path
outside the recorded set. It fired once, on document 4, and the abort was correct — an earlier
version of the check used a string round-trip that mangled the *already-correct* `help.polymer.co`
Google Jobs link in block 8. The check was replaced with the per-leaf-path walk.

Drafts cannot leak to the live site: `web/lib/sanity.js` builds its client with no token, and an
unauthenticated Sanity client cannot read `drafts.*`. (`web/pages/changelog.js` line 14 queries
`*[_type == "changelog"] | order(date desc)` with no `!(_id in path("drafts.**"))` filter, which is
safe for that reason alone.)

## Legacy `wrk.xyz` links that are alive — reported, not touched

Every other `wrk.xyz` URL in the dataset was fetched. **None is dead**; all resolve 200, almost
all by redirecting to the Polymer equivalent. They are redirect hops, not broken links, which puts
them in tab 16 row 9 territory ("52 external redirecting links", explicitly not actioned by
Phase 3 item 3) rather than tab 10's. Listed here so the set is on record:

| URL | Status | Where |
|---|---|---|
| `https://www.wrk.xyz/` | 200 → `https://www.polymer.co/` | `talent-acquisition` `content[47]`; `agile-recruiting-process` `content[124]`, `content[125]` |
| `https://wrk.xyz/pricing` | 200 → `https://www.polymer.co/pricing` | `changelog` `62a6ba05-0d23-430b-a58a-ed6b93549e25` |
| `https://hire.wrk.xyz/register` | 200 → `https://app.polymer.co/register` | `a-player` `content[127]`, `content[128]`; `onboarding` `content[181]`, `content[182]` |
| `https://jobs.wrk.xyz/aperturelabs/15394?source=linkedin` | 200 → `https://jobs.polymer.co/aperturelabs/15394` | `13e77379-4459-4ed8-9b5b-e6b9385be30b` — in the `href` **and** in the visible text |
| `https://www.wrk.xyz/blog/utc-is-the-timezone-of-the-future` | 200 → `www.polymer.co/blog/...` | `onboarding` `content[58]`, `content[59]` |
| `https://www.wrk.xyz/blog/five-things-a-startup-should-keep-in-mind-when-hiring` | 200 → `www.polymer.co/blog/...` | `onboarding` `content[147]`, `content[148]` |
| `https://www.wrk.xyz/blog/four-steps-to-build-a-recruiting-strategy-for-your-startup` | 200 → `www.polymer.co/blog/...` | `best-job-board-software` `content[22]` |
| `https://www.wrk.xyz/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers` | 200 → `www.polymer.co/blog/...` | `best-applicant-tracking-software` `content[110]` |
| `https://wrk.xyz/blog/one-click-distribution-to-we-work-remotelys-community-of-job-seekers` | 200 → `www.polymer.co/blog/...` | `changelog` `93a9e91a-965f-...` |
| `https://wrk.xyz/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` | 200 → `www.polymer.co/blog/...` | `changelog` `a3817c92-2887-4827-9aad-665284a492fa` |
| `https://developer.wrk.xyz/` | 200 at its own URL, **no redirect** | `changelog` `fc4d0173-1839-4ef1-99d3-2bfcdcd6a6b7` |

`https://www.wrksolutions.com/...` in `skills-mapping-for-hiring-a-complete-guide` `content[48]`
is an unrelated third party (wrksolutions.com) matched only by the substring — not legacy Polymer.

## Legacy "Wrk" brand text still in Sanity — reported, not touched

Tab 10's Fix column asks for a brand rewrite on row 7 only, and row 7's body turned out to be
clean. The remaining "Wrk" prose is in dated `changelog` entries from 2021-2022 that describe what
shipped under the Wrk brand at the time, so rewriting them would falsify a dated record. That is
an editorial call, not an agent's — filed as a question rather than changed. Same for the image
alt text, which belongs to tab 11. Full inventory is in QUESTIONS-FOR-JESSICA.md under this item.

`hello-polymer` mentions Wrk deliberately — it is the rebrand announcement post. Correct as-is.

## How it was done

Throwaway scripts in the session scratchpad, not files in the repo:

- `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/survey-wrk.js` — dataset-wide href and "wrk" string inventory
- `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/wrk-legacy-drafts.js` — the patch, dry-run by default, `--apply` to write
- `/private/tmp/claude-501/-Users-jessica-claude-hub-wrk-marketing/ae83cb44-eb97-4453-99a4-0718b5a2e1c9/scratchpad/verify-wrk-legacy.js` — the three-way verification above

Structure follows the Phase 4 analog `blog-drafts.js` / `verify.js` in the same scratchpad:
`SANITY_API_WRITE_TOKEN` read out of `web/.env.local` at runtime, `apiVersion: "2021-03-25"`,
`useCdn: false`, `createIfNotExists` then `.patch(draftId).set()` — never `createOrReplace`, never
`.publish()`. The token is not written into this log or any other file, and `.env.local` was read
only, never modified. The dry run was inspected before anything was written.

## Files written by this item

- `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/logs/phase-6-wrk-legacy.md` (this file)
- Questions appended to `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md` under "Phase 6, item 3 — Wrk legacy"

Nothing appended to `BLOCKED.md`. Not blocked.
