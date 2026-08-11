# Audit of merged main — area: jobboard-link-and-rest

Read-only. Diff base `01bf615` ("Merge pull request #46 from wrk-corp/plato-landing-page") against `origin/main`.

Files judged: `web/components/jobBoard/features.js`, `web/components/feature.js`, `web/pages/features/jobboard.js`, `SEO-CHANGELOG.md`.

## Commits that touched this area

```
7420868 Remove the Keep reading block from the job board page
475d355 Link the job board post from the features copy
10468d0 Move the job board post link to the customization block
789d54c Underline the inline link in a feature description
```

## The authorising cells

Tab `01 Orphaned Pages`, row 16:

- A16: `https://www.polymer.co/blog/best-job-board-software`
- E16: "Listicle exists but fully orphaned - not even deep-linked"
- F16 (Recommended action): "Link from /features/jobboard + blog index; refresh"

Overview row 11 (issue 1), K11 (Recommended fix): "Add full blog pagination/archive to /blog, add related-post links from crawlable posts, and include every post in the new XML sitemap. Then refresh the assets (see Content Freshness)."

Master prompt Phase 1: "Fix the blog index… Add a related-posts module to the blog post template… Confirm each of the 10 URLs returns 200 and is now reachable ≤3 clicks from the homepage."

F16 authorises one thing on `/features/jobboard`: a link to `/blog/best-job-board-software`. It says nothing about placement, wording, or styling. Jessica's separate explicit ask covers the underline.

## `web/components/jobBoard/features.js`

Added `import Link from "next/link"` and a third `description` entry on the second feature block ("Powerful, expressive customization"):

```jsx
<>
  See how it compares to{" "}
  <Link href="/blog/best-job-board-software">
    other job board software
  </Link>
  .
</>,
```

Authorised. F16 asks for the link; a link needs anchor text and a host sentence, and this is one sentence in existing copy rather than a new module.

One divergence from the house form, cosmetic: every other `next/link` call site in this repo passes an explicit `<a>` child — `web/components/footer.js:27`, `web/components/looking.js:16`, and `web/components/blogIndex.js:21` (via `passHref`). This one passes a bare string. Next 12.1.0 auto-wraps a string child in an `<a>`, so it renders, but it is the only call site in the codebase written that way.

## `web/components/feature.js`

Two changes.

### 1. The `key` expression

```jsx
{content?.description?.map((p, index) => (
  <Styled.Description key={typeof p === "string" ? p : index}>
```

Authorised as mechanism. A React element cannot be a `key`, so the previous `key={p}` breaks the moment `description` holds a node. The ternary preserves the pre-existing string key rather than changing it, which is the smaller change.

### 2. The `a` block on `Styled.Description`

```
a {
  ${t.text.medium};
  color: ${t.color.black} !important;
  text-decoration: underline !important;
}
```

`text-decoration: underline` is Jessica's explicit ask and stays.

The house analog for exactly this — an inline link inside body copy whose container sets a non-black text colour — is `web/components/looking.js:60`:

```
a {
  ${[t.text.medium, t.text.black, t.mt(2)]}
  display: block;
  text-decoration: underline;
  ...
}
```

`Styled.Component` in `looking.js` sets `t.text.gray` on the container, so the global reset in `web/styles/global.js:41-48` (`a, a:link, a:visited, a:hover, a:active { text-decoration: none; color: inherit; }`) is fighting that rule in exactly the same way it fights the new one, and it loses without `!important`. Same for `basicPage.js:108`, which styles prose links as `${[t.text.medium]}` with no `!important`. So both `!important` flags are unnecessary against working evidence in this codebase.

`color: ${t.color.black}` is also not the house form. `t.text.black` is the theme's colour helper (`web/styles/theme.js:243`) and is what `looking.js` uses; `t.color.black` is the raw hex behind it.

`${t.text.medium}` is a weight bump nobody asked for. It matches the house form for prose links (`basicPage.js`, `looking.js`), so it is defensible, but the only styling in the ask is the underline.

Blast radius is nil today: `feature.js` has four consumers (`home/features.js`, `jobBoard/features.js`, `candidateManagement/features.js`, `industries/industryFeatures.js`) and only `jobBoard/features.js` puts an anchor in a `description`.

## `web/pages/features/jobboard.js`

### "Keep reading" — confirmed gone

Commit `7420868` removed the whole block. `origin/main` version is 25 lines: `SEO`, `Intro`, `Basics`, `Features`, `Other`, `Start`. No `getStaticProps`, no `sanity` import, no `Section` import, no `Styled`, no `styled`/`css` imports, no `Link` import. `git grep -i "keep reading" origin/main -- web/` returns only `web/pages/blog/[slug].js:325-326` (the related-posts module, a different item) and one descriptive sentence in `web/public/llms-full.txt:247`. Nothing survives on this page.

### Two other changes rode in on the same commit

`7420868` also changed:

```
-        pageTitle="Job Board Software"
+        pageTitle="Job Board Software - Branded, Instant, Free to Start"
-        image="https://polymer.co/images/jobboardcard.png"
+        image="https://www.polymer.co/images/jobboardcard.png"
```

**pageTitle.** Tab `07 Title Rewrites` row 10: URL `https://www.polymer.co/features/jobboard`, current title "Job Board Software | Polymer", problem "Good keyword, room for differentiator", suggested rewrite "Job Board Software - Branded, Instant, Free to Start | Polymer". `web/components/seo.js:19` appends `" | Polymer"` when the title does not already contain "Polymer", so the rendered title is the cell verbatim. The cell authorises the string. Tab 07 is Phase 4, which is not the phase merged into `main` — so this is authorised copy shipped out of phase, inside a Phase 1 cleanup commit, and it is not recorded in `SEO-CHANGELOG.md`.

**image host.** Tab `16 Redirect Links` lists exactly two URLs, A7 `https://polymer.co` and A8 `https://polymer.co/`, both with fix D "Update internal hrefs to the www URL", under the note "Only two internal 3xx targets exist (apex forms of the homepage, 308 -> www)". The master prompt Phase 3 redirect map row 2 is worded the same: "internal hrefs to `https://polymer.co` / `https://polymer.co/` → `https://www.polymer.co/` | href update". `https://polymer.co/images/jobboardcard.png` is not either listed URL and is not an href — it is the `og:image` / `twitter:image` content value. Nothing in tab 16 or the redirect map covers it.

It is also inconsistent: `git grep 'image="https://' origin/main -- web/pages web/components` returns two hits, and `web/pages/plato.js:19` still carries `https://polymer.co/images/platocard.png`. One of two instances was changed.

## `SEO-CHANGELOG.md`

### Does anything ask for it in the repo? Yes.

Master prompt, Rules of engagement, rule 4, verbatim:

> **Keep a changelog.** Append every change (file, URL affected, before → after) to `SEO-CHANGELOG.md` in the repo. The final report is built from it.

Phase 7 step 1: "Compile `SEO-CHANGELOG.md` into a summary."

The file is named, the location is named ("in the repo"), and a later phase consumes it. So the file's existence in the source repo is authorised and it does not come out on the "nothing asks for it" test.

### What is not authorised is what is in it.

Rule 4 defines the content shape: "every change (file, URL affected, before → after)". The file on `origin/main` is 881 lines. Section headings:

```
  1 # SEO changelog
 49 ## Phase 1 — de-orphaning internal links
 51 ### Item 1 — blog index pagination
 61 #### What 6229f91 shipped — superseded by the 2026-08-06 shape below
151 #### The 2026-08-06 shape — URL-based pagination, five posts a page
217 ### Item 2 — related-posts module on the blog post template
468 ### Phase 1 step 3 — 200 confirmation and click path per URL
518 ## Phase 2 — crawlability files
520 ### Item 1 — XML sitemap
635 ### Item 2 — robots.txt
670 ### Item 3 — llms.txt
683 # Polymer
687 ## Products
695 ## Pricing
706 ## Docs & API
713 ## Guides
744 ## Repairs applied after the workflow
775 ## Open items
777 ### Verifier findings
816 ### needsLiveCheck still unconfirmed
837 ### BLOCKED.md
853 ### Where this file lives
864 ### QUESTIONS-FOR-JESSICA.md
```

Beyond "file, URL affected, before → after" it carries: which commit contains which change and which working-tree edits are not in the PR (lines 5-47); superseded shapes kept alongside current ones; verifier verdicts and finding-by-finding repair tables; an orchestration post-mortem about parallel agents clobbering each other's log files (line 772); the entire body of `web/public/llms.txt` pasted verbatim at lines 683-743, whose `#`/`##` headings also break the document's own heading hierarchy; the full text of `QUESTIONS-FOR-JESSICA.md` re-transcribed at lines 864-881; and a section arguing with itself about where the file belongs. Line 3 and lines 816-881 cite absolute local paths under `/Users/jessica/claude-hub/` from inside a committed source file.

Lines 853-862 record that the file's own authors saw the conflict and left it: master prompt rule 4 says in the repo, `~/claude-hub/CLAUDE.md` universal rule 1 says outputs go in the pipeline scratchpad. The resolution that satisfies both is the one the file itself lists third — cut to the rule 4 shape in the repo, run record to the hub — and it is also what "Jessica does not want long documents delivered to her" requires.

### It is wrong about this area.

On the one rule that authorises the file at all, the changelog fails for my files. `git grep` for this area's identifiers returns:

- Line 27: "`web/pages/features/jobboard.js` — the tab 01 row 16 'Keep reading' link."
- Line 764: "**File:** `web/pages/features/jobboard.js` — in neither `6229f91` nor the branch."
- Lines 766-770 describe the shipped state as a `<Section thin>` wrapping `<Styled.Related aria-label="Keep reading">`, a `Styled.RelatedTitle` div, a link, a paragraph, "plus the two styled components those need", fed by "a new `getStaticProps` [that] reads `editorialTitle`, `metaDescription` and `slug` for that one post from Sanity".

Commit `7420868` deleted every one of those. The changelog on `main` describes a shape that `main` does not contain.

`web/components/jobBoard/features.js` and `web/components/feature.js` — the two files that actually carry the shipped link — appear nowhere in the changelog. Neither does the `pageTitle` rewrite nor the `image` host change from the same commit. Line 791 still reads "The `/features/jobboard` half is not done by anything on this branch".

## Anything else in the diff

Full diff file list: `SEO-CHANGELOG.md`, `web/components/blogIndex.js`, `web/components/feature.js`, `web/components/jobBoard/features.js`, `web/lib/blog.js`, `web/next.config.js`, `web/pages/blog.js`, `web/pages/blog/[slug].js`, `web/pages/blog/page/[page].js`, `web/pages/features/jobboard.js`, `web/pages/sitemap.xml.js`, `web/public/llms-full.txt`, `web/public/llms.txt`, `web/public/robots.txt`.

Everything outside my four files falls to the blog-pagination, related-posts, and sitemap/robots/llms areas. Two notes in case they fall between areas:

- `web/next.config.js` — two `permanent: true` redirects, `/blog/page` → `/blog` and `/blog/page/1` → `/blog`. Belongs to the pagination area; the pagination shape is Jessica's 2026-08-06 decision.
- `web/public/llms-full.txt` (287 lines, commit `753a3c4`) — authorised by Overview K18, "Publish /llms.txt (and llms-full.txt)", and by tab 08 row 12, "llms-full.txt | Extended page-level summaries | Optional second file". Note that `QUESTIONS-FOR-JESSICA.md` question 1 asks "do you want `llms-full.txt` (tab 08 row 12, optional), and which pages should it cover?" and it shipped without that answer. Whether 287 lines is "extended page-level summaries" is the llms area's call, not mine.
