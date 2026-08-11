# Phase 3 fixes — Round 1

## `web/pages/sitemap.xml.js`

**Finding:** MED, Tab 04 row A23, "DONE INCOMPLETELY".

**Tab row asked for:** canonical `https://www.polymer.co/applicant-tracking-for-legal-services` (tab `04 Canonicals`, cell C23, read back from the workbook character for character — it matches).

**Status: FIXED.**

### What I verified before editing

Branch `seo-phase-3-redirects-canonicals`, confirmed with `git rev-parse --abbrev-ref HEAD`.

`git diff seo-phase-1-2-deorphan-crawl...seo-phase-3-redirects-canonicals -- web/pages/sitemap.xml.js` is empty — phase 3 never touched this file, so the comment still described the pre-change world.

All seven industry pages on this branch declare the short form in `pathname`, not just the one the finding names:

```
web/pages/industries/applicant-tracking-for-cryptocurrency-companies.js:90  pathname="applicant-tracking-for-cryptocurrency-companies"
web/pages/industries/applicant-tracking-for-fintech-companies.js:90         pathname="applicant-tracking-for-fintech-companies"
web/pages/industries/applicant-tracking-for-greentech-companies.js:90       pathname="applicant-tracking-for-greentech-companies"
web/pages/industries/applicant-tracking-for-healthcare-companies.js:90      pathname="applicant-tracking-for-healthcare-companies"
web/pages/industries/applicant-tracking-for-legal-services.js:90            pathname="applicant-tracking-for-legal-services"
web/pages/industries/applicant-tracking-for-real-estate-companies.js:90     pathname="applicant-tracking-for-real-estate-companies"
web/pages/industries/applicant-tracking-for-startups.js:90                  pathname="applicant-tracking-for-startups"
```

`staticRoutes` lists those same seven short forms. `web/components/seo.js` builds its URL as
`pathname ? ${baseUrl}/${pathname} : baseUrl` and `urlEntry` in this file builds `<loc>` the same
way from the same host string, so for all seven the canonical, the `og:url` and the `<loc>` are
byte-identical. `next.config.js` rewrites each short source to the `/industries/`-prefixed
destination and `web/components/footer.js` lines 117-147 link the short form.

### The change

The stale sentence was not the only false part. The comment's `— except the industries pages`
framing asserted the industries pages are an exception to "written the way `pathname` declares
it". After phase 3 no exception exists, so the clause went too.

```
before: // Every static marketing route, written the way the site's own SEO component
        // declares it in `pathname` — except the industries pages, which appear under
        // their top-level rewrite source (see the rewrites in next.config.js) because
        // that is the URL footer.js links to. One of them,
        // applicant-tracking-for-legal-services, declares the `industries/`-prefixed
        // form in `pathname`, so that page's og:url does not match its <loc> here.
        // New pages need a line here.

after:  // Every static marketing route, written the way the site's own SEO component
        // declares it in `pathname`. The industries pages sit under `pages/industries/`,
        // but both their `pathname` and their entry here use the top-level rewrite
        // source (see the rewrites in next.config.js), which is the URL footer.js links
        // to, so each one's og:url and canonical match its <loc>.
        // New pages need a line here.
```

Comment only. No executable line changed; `staticRoutes` and every emitted URL are byte-identical
to what the branch already shipped.

### Not fixed — outside the one file I own

The finding also says the repair record in `SEO-CHANGELOG.md` does not mention the comment. I do
not own that file and did not edit it. For whoever does:

- The finding cites line 147. That line is phase 1-2 orphaned-pages text. The actual `Item 1 HIGH`
  repair record is **line 809**, and it does not mention the sitemap comment.
- **`SEO-CHANGELOG.md` line 515 is now stale because of my edit.** It reads "the `staticRoutes`
  comment now names `applicant-tracking-for-legal-services` as the page whose `og:url` does not
  match its `<loc>`". That is no longer true of the working tree.

### One observation, not acted on

A sibling agent has an uncommitted change in `web/components/seo.js` adding `canonicalUrl`, which
emits `https://www.polymer.co/` with a trailing slash for the homepage (tab 04 row A7) while
`urlEntry` in my file still emits `<loc>https://www.polymer.co</loc>` without one. For `pathname`
values that are non-empty `canonicalUrl === url`, so the industries pages and my comment are
unaffected. I did not change it: it is outside this finding and would collide with in-flight work.

## `BLOCKED.md`

**Finding:** MED, "n/a (conventions) — BLOCKED.md scope", "DONE INCOMPLETELY".

**Asked for:** the three Phase 1 / Phase 2 items that `SEO-CHANGELOG.md` lines 964-978 says land in the
three categories master prompt rule 3 names — missing permissions, environment values, editorial
judgment calls — and that were routed to `QUESTIONS-FOR-JESSICA.md` (a hub scratchpad outside this
repo) instead of `BLOCKED.md`.

**Status: FIXED.** Three entries added, inserted ahead of the existing Phase 3 `/contact` entry so the
file reads in phase order. `BLOCKED.md` was the only file I edited.

### Workbook values, read back character for character

`python3 read-workbook.py "01 Orphaned"`, `"02 XML"`, `"03 robots"`. Every value the finding quotes is
in the workbook as quoted:

- Tab `03 robots.txt` row 10 — A10 `Host handling`, B10 `serve at both apex and www`,
  C10 `Apex 308s to www; ensure robots.txt resolves pre-redirect too`
- Tab `02 XML Sitemap` row 9 — A9 `Search Console`, B9 `unknown`,
  C9 `Submit sitemap; monitor Index Coverage for the 10 currently-orphaned posts`
- Tab `01 Orphaned Pages` rows 7-16, column F — F8 `Link + refresh + add downloadable template`,
  F9 `Link + refresh; formula & benchmark blocks for AEO`, F12 `Link; fold into hiring-ops cluster`,
  F15 `Strengthen internal links; base for interview-bias guide`,
  F16 `Link from /features/jobboard + blog index; refresh`

### One quotation in `SEO-CHANGELOG.md` does not match the workbook

Line 974 says of tab 01 rows A7:F16: "every row's Recommended action ends in 'refresh'". Eight of the
ten do — F7, F8, F9, F10, F11 ("light refresh"), F13, F14, F16. Two do not: F12 is
`Link; fold into hiring-ops cluster` and F15 is `Strengthen internal links; base for interview-bias
guide`, neither of which contains the word. The same claim appears in `QUESTIONS-FOR-JESSICA.md`
line 13 ("Every row in tab 01 also says 'refresh'"). I wrote the accurate count into `BLOCKED.md`
rather than copying the claim forward. I do not own either of those two files, so neither was
corrected.

### Facts each entry rests on, and where they were checked

- **Phase 1 entry.** The `/features/jobboard` half of row F16 is on this branch, not only in a working
  tree: `web/pages/features/jobboard.js` line 14 queries the `best-job-board-software` `blogPost`,
  lines 35-36 render `<Styled.Related aria-label="Keep reading">` with a `Styled.RelatedTitle`, and
  line 49 is the new `getStaticProps`. The phase-3 diff touches that file on one line only (the
  `og:image` host), so the block arrived with the phase-1-2 base branch.
- **Phase 2 sitemap entry.** `web/public/robots.txt` on disk carries
  `Sitemap: https://www.polymer.co/sitemap.xml`, matching `web/pages/sitemap.xml.js`.
- **Phase 2 robots.txt entry.** `web/next.config.js` read in full on this branch: `redirects()` holds
  `/climate` and the `/contact` 301, `rewrites()` holds the seven industry entries, and nothing else.
  `ls web/vercel.json vercel.json` returns "No such file or directory" for both. The entry says
  `next.config.js` carries "the `/climate` redirect, the `/contact` 301 and the seven industry
  rewrites" — `QUESTIONS-FOR-JESSICA.md` line 17 predates the `/contact` 301 and names only two of the
  three, so that sentence was updated to this branch rather than copied.
- The live-fetch result reused verbatim from `QUESTIONS-FOR-JESSICA.md` line 17
  (`https://polymer.co/robots.txt` 308s to `https://www.polymer.co/robots.txt`, checked 2026-08-05).
  No new fetch was run.

### Sibling agents are writing the same tree

`git status` was clean at checkout and now shows `web/components/seo.js` and
`web/pages/sitemap.xml.js` modified as well. Neither is mine and neither was touched.

---

## QUESTIONS-FOR-JESSICA.md

Branch: `seo-phase-3-redirects-canonicals`. Not committed, not pushed.
File owned and edited: `/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/QUESTIONS-FOR-JESSICA.md`
No file in the source repo was touched.

### Checkout note

`git rev-parse --abbrev-ref HEAD` said `seo-phase-6-images-links-headers` on my first command and
`seo-phase-3-redirects-canonicals` two commands later, with no branch change by me. Same flapping the
`web/components/seo.js` section above recorded. I did not switch it and did not need to: every fact
below was verified with `git show seo-phase-3-redirects-canonicals:<path>`, which reads the branch
regardless of what is checked out.

### Workbook verification

Ran `python3 read-workbook.py "04 Canonicals"`. The orchestrator's transcription is accurate for the
row that bears on this file:

- `A23: https://www.polymer.co/applicant-tracking-for-legal-services`
- `C23: https://www.polymer.co/applicant-tracking-for-legal-services`
- `D23: Self-referencing canonical via Next.js metadata`

All seven industry rows (`A18`–`A24`) are in the short top-level form; none is listed under an
`/industries/` path. No misquote to report.

### Finding addressed

**Tab 04 row A23 asked for:** canonical `https://www.polymer.co/applicant-tracking-for-legal-services`.
The finding against this file was that it still asked Jessica to authorise an edit already in the branch.
**Status: DONE.**

Verified before editing:

```
git show seo-phase-3-redirects-canonicals:web/pages/industries/applicant-tracking-for-legal-services.js
  line 90:  pathname="applicant-tracking-for-legal-services"
git show 4fbc64f -- .../applicant-tracking-for-legal-services.js
  -        pathname="industries/applicant-tracking-for-legal-services"
  +        pathname="applicant-tracking-for-legal-services"
git show seo-phase-3-redirects-canonicals:web/components/seo.js
  line 58:  <link rel="canonical" href={seo.url} key="canonical" />
```

So the edit the file asked her to authorise is committed, and the canonical it produces is
byte-identical to cell `C23`.

### Three edits, not one

The finding names line 57. The same commit had made two more statements in this file false, both the
same defect — a question asking her to decide something the branch already did. Fixing only the named
line would have left her reading the identical question 27 lines earlier.

1. **Line 57, "Phase 3, item 1" question 2** (the named finding) — the legal-services `pathname`.
   Struck through and marked **Fixed, no longer a question**, citing commit `4fbc64f` and cell `C23`.
2. **Line 30, "Phase 2, item 1" question 1** — the *same* question about the *same* line of the *same*
   file, asked in the sitemap section. Same treatment.
3. **Line 31, "Phase 2, item 1" question 2** — claimed "`web/components/seo.js` emits no
   `<link rel="canonical">` at all, only `og:url`." That is now false; `4fbc64f` added it. Rewritten to
   state the canonical is in and to keep the half that is genuinely still open — the seven
   `next.config.js` rewrites are unchanged, so both URL forms still return 200, and converting them to
   permanent redirects remains her call.

I used the document's own existing form for a resolved item (`~~struck lead~~` +
**Fixed, no longer a question.**), which it already uses at "Phase 4, item 3" question 2.

No line numbers were written into the new text for `web/components/seo.js`. The uncommitted
`canonicalUrl` change described in the section above shifts the canonical from line 58 to line 60, and
pinning a number would have re-created the same staleness defect I was sent to fix.

### Not fixed, and why

**"Phase 3, item 1" question 1 — the homepage trailing slash — is now stale too, but I left it alone.**
It tells her the canonical emits `https://www.polymer.co` without the slash, and that switching to the
slash form "changes the homepage `og:url` too — so it is not a canonical-only edit." The
`web/components/seo.js` fix logged above disproves both: it emits `` `${baseUrl}/` `` for the homepage
canonical and leaves `seo.url` untouched, so `og:url` does not move.

That fix is **uncommitted** — `git status` shows ` M web/components/seo.js`, and no branch in the repo
contains `canonicalUrl`:

```
for b in $(git branch --format='%(refname:short)'); do
  git show "$b:web/components/seo.js" | grep -q canonicalUrl && echo "$b"
done
  -> (no output)
```

Marking that question resolved would be recording an outcome that does not exist yet in any commit and
would be wrong if the change is dropped. Once the orchestrator commits it, question 1 under
"Phase 3, item 1" should get the same strike-through treatment as the three above.

---

## `SEO-CHANGELOG.md`

Branch: `seo-phase-3-redirects-canonicals`, confirmed with `git rev-parse --abbrev-ref HEAD` after
`git checkout` (HEAD was on `seo-phase-6-images-links-headers` at spawn; the tree was clean, so the
checkout took nothing with it). Not committed, not pushed. `SEO-CHANGELOG.md` is the only file I
edited.

**Finding:** MED, "Tab 04 row A23 / Tab 06 row A7", master prompt rule 4 (keep a changelog),
"DONE INCOMPLETELY".

**Status: FIXED**, plus three further statements of the same class the finding did not name.

### Workbook verification

`python3 read-workbook.py "04 Canonicals"`, `"06 Backlinked 404"`, `"16 Redirect Links"`. The
orchestrator's transcription of all three tabs is accurate — no misquote to report. Spot values read
back character for character:

- `A7: https://www.polymer.co/` / `C7: https://www.polymer.co/` (trailing slash, as quoted)
- `A23: https://www.polymer.co/applicant-tracking-for-legal-services` / `C23` identical; all seven
  industry rows `A18`–`A24` are the short top-level form, none under `/industries/`
- `A38: https://www.polymer.co/?partner_source=whatjobs (parameter URL, 243 backlinks)` /
  `C38: https://www.polymer.co/` / `D38: Canonical consolidates the partner-parameter link equity to the homepage`
- Tab 06 `E7: Restore /contact with demo/sales form; until then 301 -> /about or /pricing`;
  `B9: 59 (445 ref. domains)` — the backlink count and the ref-domain count share cell B9, and C9 is
  `445.0`, which is how the orchestrator's "59 backlinks, 445 ref domains" reads
- Tab 16 rows A7/A8/A9 and note A4 match as quoted

### State the file now describes, verified before editing

```
git log --oneline -3
  94a8f05 Merge branch 'seo-phase-1-2-deorphan-crawl' into seo-phase-3-redirects-canonicals
  05eed5c Close the gaps the phase 1+2 review found
  4fbc64f Add canonical tags, redirect /contact, and drop the apex hop

git show --stat 4fbc64f   -> 8 files: BLOCKED.md (A), SEO-CHANGELOG.md, web/components/seo.js,
                             web/next.config.js, web/pages/features/jobboard.js,
                             web/pages/industries/applicant-tracking-for-legal-services.js,
                             web/pages/plato.js, web/pages/privacy.js
git branch --contains 05eed5c -> includes seo-phase-1-2-deorphan-crawl, so it is that branch's
                                 commit, merged in by 94a8f05
grep -n pathname web/pages/industries/applicant-tracking-for-legal-services.js
  90:        pathname="applicant-tracking-for-legal-services"
BLOCKED.md exists at the repo root, 21 lines as committed
```

### The four edits

1. **Line 675 (named).** "Nothing in this phase was committed or pushed. The phase-3 working tree
   carries five modified files:" plus a five-line block. Replaced with the commit record: `4fbc64f`,
   pushed as PR #48, eight files listed in the block; then the two non-phase-3 commits the branch
   also carries (`05eed5c` and the merge `94a8f05`).
2. **Line 843 (named).** Row 23 said "**not actioned as specified.** The page emits
   `https://www.polymer.co/industries/applicant-tracking-for-legal-services` instead". It now records
   the row as actioned, names the line that carries the short form, and says why the entry stays
   under the "not actioned, or actioned with a differing value" heading — the item that owns the row
   did not action it; a later repair did.
3. **Line 876 (named).** "`BLOCKED.md` still does not exist" replaced with the file's creation in
   `4fbc64f` and its `/contact` entry.
4. **Lines 966, 976, 978 (same falsehood, not named).** The phase-1/2 "### BLOCKED.md" section
   asserted three more times that the file does not exist ("does not exist", "With no `BLOCKED.md` on
   disk", "`BLOCKED.md` has not been created"). Fixing only the phase-3 copy would have left the
   contradiction intact 90 lines lower. All three now describe the committed file and the working
   tree, and the rule-3 table's third column header changed from "Where it currently lives" to
   "Where it lived when this was written" so its cells stop asserting a present state that a
   concurrent agent is changing.

Two verifier findings (item 1 HIGH on the legal-services `pathname`, item 2 MED-1 on `BLOCKED.md`)
were left verbatim, as this file's convention requires, with the marker the file already uses at the
llms.txt HIGH: **Fixed — see Phase 3 repairs applied after the workflow, above.** Without it both
findings still read as open work in a section titled "Phase 3 open items".

### One more, handed over by a sibling agent

The `web/pages/sitemap.xml.js` agent's section above records that its comment rewrite made line 515
of this file stale ("the `staticRoutes` comment now names `applicant-tracking-for-legal-services` as
the page whose `og:url` does not match its `<loc>`"). That clause is true of the branch and false of
the working tree; both are now stated there.

### Sibling agents are writing the same tree

`git status --porcelain` was clean at checkout and now shows ` M BLOCKED.md`, ` M web/components/seo.js`
and ` M web/pages/sitemap.xml.js` in addition to my file. None of the three is mine and none was
touched. Their in-flight edits are the reason every statement I wrote is anchored to a commit
(`4fbc64f`) and, where the working tree differs, says so explicitly as of the time of writing:

- `web/components/seo.js` — a `canonicalUrl` that emits `https://www.polymer.co/` for the homepage.
  I made no claim about tab 04 rows 7 and 38 either way; the existing bullets there are true of the
  commit, and recording an uncommitted outcome as done is the defect I was sent to fix.
- `BLOCKED.md` — three entries added for the Phase 1 / Phase 2 items. Both `BLOCKED.md` sections now
  state the committed content and the working-tree addition separately.

### Not fixed

- **Lines 5-32, the phase-1/2 header.** "The run itself committed and pushed nothing", "**The working
  tree carries uncommitted edits that PR #47 does not contain**" and "Those corrections are
  working-tree only and are not on the branch until this file is committed" are all stale: those
  edits are commit `05eed5c` on `seo-phase-1-2-deorphan-crawl`, which is in PR #47 and merged into
  this branch by `94a8f05`. It is the phase-1/2 record, describing a different branch and a different
  PR, and the phase-1-2 round owns it. Correcting it here would race that round's own copy of this
  file and land as a merge conflict.
- Nothing in the repo was created or deleted; no code file was touched.
