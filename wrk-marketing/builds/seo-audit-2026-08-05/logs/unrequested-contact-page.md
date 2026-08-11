# Unrequested-change audit: `contact-page`

Read-only pass over `git diff seo-phase-8-faq..contact-page`. Nothing was edited.

## The diff

Six files, all from two commits (`1bd8dab` Add /contact page with a working contact form, `babe1b0` Record /contact as shipped rather than blocked); the other four commits are merges of `origin/seo-phase-8-faq`.

| File | Change |
|---|---|
| `web/pages/contact.js` | new, 317 lines |
| `web/pages/api/contact.js` | new, 88 lines |
| `web/next.config.js` | `/contact` -> `/about` 301 deleted from `redirects()` |
| `web/pages/sitemap.xml.js` | `"contact"` added to `staticRoutes` |
| `web/pages/pricing.js` | enterprise CTA retargeted from `mailto:support@polymer.co` to `/contact` |
| `BLOCKED.md` | `/contact` entry rewritten from unblocked to shipped |

## Cells consulted

Tab 06 row 7, the only detail row for this item:

- E7 `Restore /contact with demo/sales form; until then 301 -> /about or /pricing`
- F7 `Footer 'Contact us' and pricing's enterprise 'Contact Us' CTA imply this page should exist; 404 kills enterprise-intent conversions`

Overview row 16 (issue 6):

- E16 `pricing's enterprise CTA has no landing page`
- J16 `https://www.polymer.co/contact 404s, yet the backlink index shows 22 external links pointing at it, and the footer/pricing reference 'Contact us'. Link equity and enterprise-intent visitors are both being dropped.`
- K16 `Restore /contact with a demo/sales form (preferred), or 301 to a live equivalent until it ships.`

Overview row 12 (issue 2):

- K12 `Generate a sitemap.xml from the Next.js app (app/sitemap.ts) covering all marketing pages + blog posts; submit in Search Console.`

`master-prompt-pages-router.md` Phase 3 item 2: `Restore /contact with a demo/sales form if a design exists; otherwise ship the 301 now and log the page build in BLOCKED.md.`

## Nothing marked for removal

**`web/pages/contact.js`, `web/pages/api/contact.js`** are Jessica's ask, stated in the approvals as `/contact` with a form emailing contact@polymer.co. Everything inside them stays inside them: the diff touches no shared component, no theme file, no existing page other than pricing.js. `web/components/seo.js`, `web/components/button.js`, `web/components/footer.js`, `web/components/header.js`, `web/components/section.js` and `web/components/start.js` are all unmodified on this branch. The `noBrandSuffix`, `editorialTitle` and `article` props on contact.js's `SEO` match the existing house calls; `article` on a non-blog marketing page is pre-existing on `main` (`web/pages/about.js` line 26, `web/pages/features.js` line 410), so it is not an engagement invention. Postmark over `fetch` adds no npm dependency, and the repo had no prior mail path (`web/pages/api/hello.js` was the only API route on `main`), so a transport had to be chosen for the form to email anything.

**`web/next.config.js`** is a mechanism. E7 calls the 301 the interim step, "until then", and a `redirects()` entry at `/contact` runs before filesystem routing, so `pages/contact.js` would never render while the entry exists. The page the cell asks for does not work without this deletion.

**`web/pages/sitemap.xml.js`** is K12: a sitemap covering all marketing pages covers a new marketing page.

**`BLOCKED.md`** is authorised by the master prompt line that makes BLOCKED.md the log for this item.

## One flagged as uncertain: the pricing CTA

`web/pages/pricing.js` lines 204-210. Pre-engagement text, identical on `main`:

    <Button
      label="Contact Us"
      size="large"
      type="outbound"
      color="gradient"
      to="mailto:support@polymer.co"
    />

On the branch, `type="outbound"` is gone and `to` is `/contact`. Dropping `type="outbound"` is not a separate change: `web/components/button.js` renders a `next/link` `Link` unless `type` is `"outbound"`, so an internal target requires it gone.

Against authorisation: the action columns (E7, K16) ask for the page and nothing else, and the page works fully without any pricing.js edit, which is the round's stated mechanism test. F7 and E16 are Notes and Scale-note columns, evidence for why the page should exist rather than an instruction to retarget anything. The phase-3 agent read the same cell the same way and declined the edit deliberately (`logs/phase-3-contact.md` line 113: "there are no internal links to repoint... I own neither file and changed neither"). And BLOCKED.md's last paragraph on this branch, unchanged by this branch, still reads "those two CTAs are candidates for repointing at the restored page" while pricing has in fact been repointed and `web/components/footer.js` has not, so the branch's own record calls this a candidate rather than a done deal.

For authorisation: F7 names this exact CTA as one that belongs to `/contact`, J16 names "enterprise-intent visitors" as half the harm the restore is meant to stop, and the edit is one attribute on the one CTA the cell names. `git grep` across `web/components` and `web/pages` finds `to="/contact"` at `pricing.js:261` and nowhere else, so without it the restored page carries zero internal links and is reachable only through the sitemap and the 22 external backlinks, which is the orphan shape the same audit calls P1 in issue 1.

Genuinely either way, so per the round's rule it stays and is flagged rather than reverted. The one consequence worth Jessica's eye: the CTA used to open a mail client to support@polymer.co and now routes enterprise leads through the form to contact@polymer.co, a different inbox. That is a business call, not a technical one. Reverting is a two-token edit back to main's text above.

## Not findings, noted so they are not lost

- BLOCKED.md's surviving "candidates for repointing" paragraph is now false for pricing.js and still true for `web/components/footer.js`. Whichever way the pricing question goes, that paragraph needs a line changed.
- `web/pages/api/contact.js` requires `POSTMARK_SERVER_TOKEN` in the environment and a verified Postmark sender signature for `contact@polymer.co`. Nothing in the diff sets either; without the token the route logs and returns the `#failed` banner.
- `web/pages/contact.js` passes `noBrandSuffix`, which the settled decision removes from `web/components/seo.js` in favour of `pageTitle.includes("Polymer")`. The rendered title is the same either way, since `pageTitle` is "Contact Polymer - Talk to Sales and Support"; the prop just goes dead when that change merges.
