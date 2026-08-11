# Phase 3 fixes — round 2

## `QUESTIONS-FOR-JESSICA.md`

Branch: `seo-phase-3-redirects-canonicals`, confirmed with
`git rev-parse --abbrev-ref HEAD` (already checked out at spawn; no checkout needed).
Not committed, not pushed.
`/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
is the only file I edited.

### Finding

MED, "Tab 04 rows A7 and A38", "DONE INCOMPLETELY" — line 55 still asked Jessica to pick the
trailing-slash form and stated two things the working tree contradicts.

### Workbook check first

`python3 read-workbook.py "04 Canonicals"` — the tab as quoted to me is accurate:

```
A7:  https://www.polymer.co/
B7:  (none)
C7:  https://www.polymer.co/
D7:  Self-referencing canonical via Next.js metadata

A38: https://www.polymer.co/?partner_source=whatjobs (parameter URL, 243 backlinks)
B38: (none)
C38: https://www.polymer.co/
D38: Canonical consolidates the partner-parameter link equity to the homepage
```

Both prescribe `https://www.polymer.co/` with the trailing slash. No misquote to report.

### Code check second

`git diff web/components/seo.js` in the working tree:

```
   let url = pathname ? `${baseUrl}/${pathname}` : baseUrl; // No trailing slash allowed!
+  let canonicalUrl = pathname ? url : `${baseUrl}/`; // Homepage canonical keeps the trailing slash
...
     url: url,
+    canonicalUrl: canonicalUrl,
...
-      <link rel="canonical" href={seo.url} key="canonical" />
+      <link rel="canonical" href={seo.canonicalUrl} key="canonical" />
```

So both of the old text's load-bearing claims are false against this tree:

1. "The canonical now emits the no-slash form" — it emits `https://www.polymer.co/`.
2. "Switching to the slash form … changes the homepage `og:url` too — so it is not a
   canonical-only edit" — `url` is untouched, only the new `canonicalUrl` feeds the
   `<link rel="canonical">`, so `og:url` does not move.

Row A38 needs no separate code: `?partner_source=whatjobs` is a query string, not a `pathname`,
so `/?partner_source=whatjobs` renders the homepage with no `pathname` prop and takes the same
`` `${baseUrl}/` `` branch. `web/pages/index.js` renders no `<SEO>`; `web/pages/_app.js` renders
it with no props, which is what puts the homepage on that branch.

### Fixed

Rewrote question 1 under "Phase 3, item 1 — self-referencing canonicals" into the document's own
existing resolved form (`~~struck lead~~` + **Fixed, no longer a question.**), the form already
used at "Phase 2, item 1" question 1, "Phase 3, item 1" question 2 and "Phase 4, item 3"
question 2. The new text states what the component computes, that `url` and therefore `og:url`
is unchanged, and that row 38 is covered by the same branch.

No line numbers for `web/components/seo.js` were written into the new text. The `canonicalUrl`
line shifts every number below it, and pinning one would re-create the staleness defect this
round exists to fix. Same reasoning round 1 recorded.

### Note on the uncommitted state

Round 1 left this question standing because `canonicalUrl` existed only in the working tree —
`git status` still shows ` M web/components/seo.js` and no branch contains the identifier.
That is unchanged, and it is the orchestrator's commit to make. I resolved the question anyway
because the finding I was sent is that the question misdescribes the tree, and the fix that
makes tab 04 rows A7 and A38 true is already written. If the `web/components/seo.js` change is
dropped rather than committed, this question has to come back.

### Not fixed

Nothing. The one finding is closed.

## web/next.config.js

**Finding:** MED, Tab 06 row A7 — DONE DIFFERENTLY. Tab 06 cell E7 reads
`Restore /contact with demo/sales form; until then 301 -> /about or /pricing`; the master prompt's
Phase 3 redirect map row reads `https://www.polymer.co/contact` -> `restore page (preferred) — else
301 → https://www.polymer.co/about`. `web/next.config.js` emitted `destination: '/about'`, a
relative value, so the `Location` header was relative rather than the redirect map's absolute
`https://www.polymer.co/about`.

**Fix applied**

Before:

```js
      {
        source: '/contact',
        destination: '/about',
        statusCode: 301,
      },
```

After:

```js
      {
        source: '/contact',
        destination: 'https://www.polymer.co/about',
        statusCode: 301,
      },
```

The destination string is copied from `master-prompt-pages-router.md` line 33 character for
character: `https://www.polymer.co/about`. An absolute destination is already the form the
neighbouring `/climate` entry uses (`https://climate.stripe.com/Cg9EBK`). `source`, `statusCode`,
`reactStrictMode`, `images`, `env`, the `/climate` entry and all seven `rewrites()` entries are
byte-identical to the previous state.

**Check run**

```
node -e "const c=require('./next.config.js'); c.redirects().then(r=>console.log(JSON.stringify(r,null,2)))"
  { "source": "/climate",  "destination": "https://climate.stripe.com/Cg9EBK", "permanent": false }
  { "source": "/contact",  "destination": "https://www.polymer.co/about",      "statusCode": 301 }

node -e "const c=require('./next.config.js'); c.rewrites().then(r=>console.log(r.length))"
  7

node -e "loadCustomRoutes(require('./next.config.js')) -> redirects filtered on 'contact'"
  [ { "source": "/contact", "destination": "https://www.polymer.co/about", "statusCode": 301 } ]
```

Next's route validation accepts the absolute destination. `next build` was not run: this repo's
build fails locally on node 18 at `pages/about.js` with a squoosh mozjpeg wasm error, recorded in
SEO-CHANGELOG.md as the phase-1 node question.

**Side effect of this change**

`/contact` now redirects to the production host from every host. On `localhost:3000` and on Vercel
preview deployments, `/contact` sends the browser to `https://www.polymer.co/about` instead of to
that deployment's own `/about`. Before this change the relative destination kept the request on
whatever host served it. On `https://www.polymer.co` the emitted `Location` is unchanged.

**Not fixed here — outside this file**

The finding's stated reason is that the deviation was recorded only in SEO-CHANGELOG.md's
verifier-findings section and not in `QUESTIONS-FOR-JESSICA.md`. With the absolute destination
shipped there is no longer a deviation to file, but SEO-CHANGELOG.md line 762 still quotes the old
`{ "source": "/contact", "destination": "/about", "statusCode": 301 }` output, line 730 still says
"now a 301 to `/about`", and line 907 still lists the relative destination under "Not filed
anywhere". `SEO-CHANGELOG.md` and `QUESTIONS-FOR-JESSICA.md` are outside this agent's ownership and
were not touched.

## web/pages/404.js

Branch: `seo-phase-3-redirects-canonicals`, confirmed with
`git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` (already checked
out at spawn; no checkout needed). Not committed, not pushed.
`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/pages/404.js` is the only repo file I edited.

**Finding:** MED, "n/a - conventions angle (web/pages/404.js line 11)" — DEFECT. `pathname="404"`
made the Not Found page emit `<link rel="canonical" href="https://www.polymer.co/404" />`.
`/404` appears in none of tab 04's 41 rows.

### Workbook check first

`python3 read-workbook.py "04 Canonicals"` — 47 rows x 4 cols. Grepping the full tab output for
`404` and for `not found`, case-insensitive, returns nothing. The claim that `/404` is in no tab 04
row is accurate. No misquote to report.

### Why deleting the prop was not the fix

`web/pages/_app.js` line 91 renders `<SEO />` with no props on every page.
`web/components/seo.js` line 14 reads
``let canonicalUrl = pathname ? url : `${baseUrl}/`;`` — with no `pathname`, the canonical is
the homepage. So removing `pathname="404"` from 404.js would not remove the canonical, it would
change it from `https://www.polymer.co/404` to `https://www.polymer.co/`, canonicalizing every
unmatched URL to the homepage. The tag has to be displaced, not dropped.

`web/components/seo.js` line 60 emits the tag unconditionally and is outside this agent's
ownership, so the override had to live in `web/pages/404.js`.

### Mechanism, traced before editing

`node_modules/next/dist/shared/lib/head.js` → `node_modules/next/dist/shared/lib/side-effect.js`
(next 12.1.0, confirmed from `node_modules/next/package.json`).

- `unique()` in head.js dedups on the `key` prop alone. The `key` branch runs before the
  `switch (h.type)` and is not scoped to a tag type, so a `<meta>` with `key="canonical"` collides
  with a `<link>` carrying the same key.
- `reduceComponents` ends `.reverse().concat(defaultHead(...)).filter(unique()).reverse()`, so the
  **last** element rendered with a given key survives.
- side-effect.js adds each instance to `headManager.mountedInstances` — a Set — in constructor
  order on the server and in `componentDidMount` order on the client. Both are render order, so a
  `<Head>` placed after `<SEO>` in the same fragment is last and wins. This is the same mechanism
  the existing `key="ogurl"` / `key="twcard"` dedup in seo.js relies on.

### Fixed

Added the `next/head` import and one `<Head>` after the existing `<SEO>`:

```jsx
      <Head>
        {/* key="canonical" displaces the <link rel="canonical"> that components/seo.js
            emits for every page. This page is served for every unmatched URL, so it must
            not canonicalize -- neither to /404 (its own pathname) nor to the homepage
            (what the prop-less <SEO /> in _app.js would emit if this override were removed). */}
        <meta name="robots" content="noindex" key="canonical" />
      </Head>
```

`pageTitle="Page not found"`, `pathname="404"`, the `<BasicPage>` body and both `css` blocks are
byte-identical to the previous state. `pathname="404"` is left in place because it still feeds
`seo.url`, which is what `og:url` reads.

### Check run

`next build` (node v20.18.1, `node node_modules/next/dist/bin/next build`) — succeeded, 46 static
pages. Grepped the emitted HTML in `.next/server/pages/`:

```
/404      <meta name="robots" content="noindex"/>          and no <link rel="canonical"> at all
/about    <link rel="canonical" href="https://www.polymer.co/about"/>
/         <link rel="canonical" href="https://www.polymer.co/"/>     (tab 04 row A7, trailing slash)

pages with no canonical:   ./404.html          (1 of 46)
pages with a robots meta:  ./404.html          (1 of 46)
```

So the override removes the canonical on exactly one page and leaves the other 45 untouched.

Note for the orchestrator: the `web/next.config.js` section above records that `next build` fails
locally on node 18 with a squoosh mozjpeg wasm error. On node v20.18.1 the build completes. The
failure is a node version issue, not a repo issue.

### Side effect, not asked for by any tab

The displacing element is `<meta name="robots" content="noindex">`, so `/404` now carries a
noindex directive it did not carry before. No tab row asks for this. It is there because the only
way to suppress the canonical from inside `web/pages/404.js` is to render some element under the
same key, and an href-less `<link rel="canonical">` would be invalid markup that an SE Ranking
recrawl could report as an empty canonical. `/404` is a real 200-status page in the Pages Router
(Next.js statically generates it and serves it at the literal `/404` path), so it is indexable
today. Jessica's call whether to keep the directive.

If `web/components/seo.js` later gains a page-level canonical opt-out prop, this override should be
replaced by that prop; the key collision is invisible to anyone reading seo.js alone.

### Not fixed

Nothing. The one finding is closed.

## `web/components/seo.js`

Branch: `seo-phase-3-redirects-canonicals`, confirmed with
`git -C /Users/jessica/wrk/wrk-corp/wrk-marketing rev-parse --abbrev-ref HEAD` (already checked out
at spawn; no checkout needed). Not committed, not pushed.
`/Users/jessica/wrk/wrk-corp/wrk-marketing/web/components/seo.js` is the only repo file I edited.

### Workbook check first

`python3 read-workbook.py "04 Canonicals"`:

```
A7:  https://www.polymer.co/
C7:  https://www.polymer.co/
D7:  Self-referencing canonical via Next.js metadata

A38: https://www.polymer.co/?partner_source=whatjobs (parameter URL, 243 backlinks)
C38: https://www.polymer.co/
D38: Canonical consolidates the partner-parameter link equity to the homepage
```

Both prescribe `https://www.polymer.co/` with the trailing slash, as quoted to me. No misquote.

### Findings sent to this file

Five, all resolving to two edits' worth of work:

1. MED, tab 04 A7/A38, DONE INCOMPLETELY — trailing-slash canonical exists only in the working tree.
2. MED, tab 04 A7, DEFECT — homepage emits three spellings of its own URL (canonical, `og:url`,
   sitemap `<loc>`).
3. HIGH, tab 06 A8, DONE DIFFERENTLY — same uncommitted-state finding against the parameter URL.
4. MED, tab 04 A7, DONE INCOMPLETELY — same uncommitted-state finding, code-correctness angle.
5. MED, conventions — `seo.url` (and therefore `og:url`) not moved with the canonical.

### Fixed

The round-1 tree carried a second variable alongside `url`:

```js
  let url = pathname ? `${baseUrl}/${pathname}` : baseUrl; // No trailing slash allowed!
  let canonicalUrl = pathname ? url : `${baseUrl}/`; // Homepage canonical keeps the trailing slash
```

with `canonicalUrl: canonicalUrl` added to the `seo` object and
`<link rel="canonical" href={seo.canonicalUrl} key="canonical" />` on the tag. That is what
produced findings 2 and 5: the canonical moved to the trailing-slash form and `og:url`, which reads
`seo.url`, stayed on the no-slash form.

`url` has exactly one other consumer — `<meta property="og:url" content={seo.url} key="ogurl" />` on
line 76. Grepped `pages/`, `components/` and `lib/`: nothing else imports or reads it. So the whole
divergence collapses by giving `url` the trailing slash and deleting the second variable.

Before (committed head 94a8f05):

```js
  let url = pathname ? `${baseUrl}/${pathname}` : baseUrl; // No trailing slash allowed!
```

```jsx
      <link rel="canonical" href={seo.url} key="canonical" />
```

After:

```js
  let url = `${baseUrl}/${pathname || ""}`; // Homepage keeps its trailing slash; interior pages never get one
```

```jsx
      <link rel="canonical" href={seo.url} key="canonical" />
```

`git diff HEAD -- web/components/seo.js` is now one changed line. The `canonicalUrl` variable, the
`canonicalUrl: canonicalUrl` entry and the `href={seo.canonicalUrl}` attribute are all gone; the
tag is back to the committed text. `key="canonical"` is unchanged, which matters because
`web/pages/404.js` (section above) displaces this tag by that key.

The emitted value `https://www.polymer.co/` is copied from cells C7 and C38 character for
character.

The old comment `// No trailing slash allowed!` was replaced because it now contradicts the line it
annotates. Nothing else in the file changed: `baseUrl`, `card`, every other `seo` field, all icons,
Twitter and Open Graph tags are byte-identical.

### Check run

`node node_modules/next/dist/bin/next dev` on node v22.21.1 (ports 3991 and 3992, both stopped
afterwards; `lsof -ti tcp:3991` reports the port free):

```
/                                              <link rel="canonical" href="https://www.polymer.co/"/>
                                               <meta property="og:url" content="https://www.polymer.co/"/>
/?partner_source=whatjobs                      <link rel="canonical" href="https://www.polymer.co/"/>
                                               <meta property="og:url" content="https://www.polymer.co/"/>
/plato                                         <link rel="canonical" href="https://www.polymer.co/plato"/>
                                               <meta property="og:url" content="https://www.polymer.co/plato"/>
/privacy                                       <link rel="canonical" href="https://www.polymer.co/privacy"/>
/blog                                          <link rel="canonical" href="https://www.polymer.co/blog"/>
/features/jobboard                             <link rel="canonical" href="https://www.polymer.co/features/jobboard"/>
/applicant-tracking-for-legal-services         <link rel="canonical" href="https://www.polymer.co/applicant-tracking-for-legal-services"/>
/industries/applicant-tracking-for-legal-services
                                               <link rel="canonical" href="https://www.polymer.co/applicant-tracking-for-legal-services"/>
/sitemap.xml first entry                       <loc>https://www.polymer.co/</loc>
homepage count of rel="canonical"              1
/404 count of rel="canonical"                  0   (robots noindex still emitted)
/this-page-does-not-exist                      0
```

Homepage canonical, homepage `og:url` and sitemap `<loc>` now all read `https://www.polymer.co/`.
Interior pages are unchanged in both tags. `web/pages/sitemap.xml.js` already emits the
trailing-slash `<loc>` in this working tree (its `urlEntry` is `${BASE_URL}/${pathname}`), so the
three now agree without touching that file.

### Not fixed

The side effect finding 2 asks to be recorded in `SEO-CHANGELOG.md` or `BLOCKED.md`. Both files are
outside this agent's ownership and were not touched. The `og:url` divergence they would have
recorded no longer exists — `og:url` moved with the canonical — but SEO-CHANGELOG.md's phase-3
section still describes the round-1 `canonicalUrl` variable, which is no longer in the file.

### Note on the uncommitted state

Findings 1, 3 and 4 are all "the fix is in the working tree, not in commit 94a8f05 / 4fbc64f, so
PR #48 ships the no-slash form." My instructions are not to commit. The emitted value is now
correct in the working tree and `git status` still shows ` M web/components/seo.js`. If this file's
change is not committed, tab 04 rows A7 and A38 and tab 06 row A8 all revert to
`https://www.polymer.co` with no trailing slash.
