# Unrequested-change audit — branch `seo-phase-7-final-report`

Diff base: `seo-phase-6-images-links-headers`. Read-only pass; no repository state changed.

## What the branch contains

`git diff --stat seo-phase-6-images-links-headers..seo-phase-7-final-report`

    SEO-FINAL-REPORT.md           | 299 ++++++++++++++++++++++++++++++++++
    web/components/home/brands.js |   2 +-
    2 files changed, 300 insertions(+), 1 deletion(-)

One content commit, `a6efae9` "Compile the final report, and correct three things it got wrong", plus four merges of the phase 6 branch.

## Test 1 — does the master prompt ask for a report file committed to the source repo?

Read `master-prompt-pages-router.md` in full. Three places name a file at the repo root.

**Rule 3:** "Log anything you cannot automate (missing CMS permissions, environment values, editorial judgment calls) in a running `BLOCKED.md` rather than improvising."

**Rule 4:** "Keep a changelog. Append every change (file, URL affected, before → after) to `SEO-CHANGELOG.md` **in the repo**. The final report is built from it."

**Phase 7, step 1:** "Compile `SEO-CHANGELOG.md` into a summary: issues closed (by audit \#), URLs touched, PRs opened/merged, items in `BLOCKED.md`."

The contrast is the whole answer. Rule 4 names a file, spells it `SEO-CHANGELOG.md`, and says "in the repo". Phase 7 step 1 names no file at all — it says "a summary" — and says nothing about the repo. The one instruction that puts an artifact in the repo does so explicitly; the report instruction does not. `SEO-FINAL-REPORT.md` is a filename the phase invented.

Jessica settled the rest: "Please don't deliver me a final report. You can just bury it in the Hub's docs."

So `SEO-FINAL-REPORT.md` comes out of the repo and goes to the hub. Its content is not the problem and is not deleted — the location is.

### The same test on the other two root files

`git ls-tree --name-only main` returns `.DS_Store`, `README.md`, `studio`, `web`. `git ls-tree --name-only seo-phase-7-final-report` adds `BLOCKED.md`, `SEO-CHANGELOG.md`, `SEO-FINAL-REPORT.md`. All three are engagement output; only the third was added on this branch (the other two arrive on phase 3 and phase 1 respectively and are already present on `seo-phase-6-images-links-headers`).

- **`SEO-CHANGELOG.md` — authorised, stays.** Rule 4 names the file and says "in the repo". Nothing to decide.
- **`BLOCKED.md` — authorised, stays.** Rule 3 names the file by name and calls it "a running `BLOCKED.md`", Phase 3 step 2 says "log the page build in `BLOCKED.md`", Phase 7 step 1 says "items in `BLOCKED.md`". Three references, all by filename. Rule 3 does not carry rule 4's "in the repo" clause, so the repo location rests on the parallel with the changelog rather than on a literal instruction. Flagged as uncertain rather than removed: the file itself is unambiguously asked for, and over-removal is the failure mode this round exists to stop.

## Test 2 — `web/components/home/brands.js`

The one-line change:

    -    { src: cala, alt: "CALA", width: 70 },
    +    { src: cala, alt: "CALA", href: "https://ca.la", width: 70 },

`git show main:web/components/home/brands.js` line 26 reads:

    { src: cala, alt: "CALA", href: "https://ca.la", width: 70 },

The phase 7 line is byte-identical to the pre-engagement line. This change is a restoration toward `main`, not an addition. Phase 6 (`git diff main..seo-phase-6-images-links-headers -- web/components/home/brands.js`) had removed the href; phase 7 puts it back.

Tab 14 `External Links` confirms it was never in scope for removal. Cell A4: "True 404s separated from 403/429 bot-walls (G2, Capterra, Quora etc. block crawlers but load for humans - verify in a browser, do not mass-remove). The five confirmed 404s include all three legacy wrk.xyz help links." Rows A7-A11 name those five: three `help.wrk.xyz` articles, `https://www.crazyegg.com/blog/recooty-review/`, `https://topgrading.com/candidate-assessment/topgrading-job-scorecard/`. `ca.la` appears in no row of the tab.

Reverting this line would move `brands.js` further from `main`, which the round's own rule forbids ("Do not remove pre-existing code. If it was on `main` before this engagement it stays"). It stays.

## Adjacent, outside this branch's diff

Phase 6 also removed `href: "https://www.makelog.com"` from the Makelog entry in the same array, and phase 7 did not restore it. `www.makelog.com` appears in no tab 14 row either. That deletion lives in the `main..seo-phase-6-images-links-headers` diff, so it belongs to the phase 6 agent's pass, not this one. Recorded here only so it is not lost between the two branches.

## Verdict

One removal, one keep, one flagged uncertainty. The report file moves to the hub with its content intact; nothing else on this branch is unauthorised.

## Pass 2026-08-07 — unrequested-change audit of `seo-phase-7-final-report`

Read-only. No repository command was run that changes state.

### The branch's entire delta over `seo-phase-6-images-links-headers`

    git diff --stat seo-phase-6-images-links-headers..seo-phase-7-final-report
     SEO-FINAL-REPORT.md           | 299 ++++++++++++++++++++++++++
     web/components/home/brands.js |   2 +-

Four merge commits from the base branch carry nothing of their own; the whole
delta is commit `a6efae9`, "Compile the final report, and correct three things
it got wrong". Two files, that is all there is to judge.

### SEO-FINAL-REPORT.md — comes out of the repo

The test set for me was whether the master prompt asks for a report file
committed to the source repo. It does not. Phase 7 item 1, quoted whole:

> 1. Compile `SEO-CHANGELOG.md` into a summary: issues closed (by audit \#),
>    URLs touched, PRs opened/merged, items in `BLOCKED.md`.

It asks for a summary to be compiled. It names no output file and it says
nothing about the repo. That silence is load-bearing, because the same prompt
does say so when it means so — rule of engagement 4, one screen earlier:

> 4. **Keep a changelog.** Append every change (file, URL affected, before →
>    after) to `SEO-CHANGELOG.md` in the repo. The final report is built from it.

"in the repo" is in rule 4 and absent from Phase 7. The clause "The final report
is built from it" establishes that a final report exists as an output of the
engagement; it does not put that report in the repo.

Jessica settled the location directly: "Please don't deliver me a final report.
You can just bury it in the Hub's docs."

`main` has no root-level `.md` other than `README.md`, so removal restores the
pre-engagement state exactly. Nothing in the repo references the file —
`git grep -iE "SEO-FINAL-REPORT"` outside the file itself returns nothing — so
no import, link or build step breaks. Removal is a move, not a deletion: the 299
lines go to
`/Users/jessica/claude-hub/wrk-marketing/builds/seo-audit-2026-08-05/SEO-FINAL-REPORT.md`
unmodified first.

### brands.js — stays, because it restores `main`

    -    { src: cala, alt: "CALA", width: 70 },
    +    { src: cala, alt: "CALA", href: "https://ca.la", width: 70 },

Checked all three points on the line:

| ref | line 26 |
|---|---|
| `main` | `{ src: cala, alt: "CALA", href: "https://ca.la", width: 70 },` |
| `seo-phase-6-images-links-headers` | `{ src: cala, alt: "CALA", width: 70 },` |
| `seo-phase-7-final-report` | `{ src: cala, alt: "CALA", href: "https://ca.la", width: 70 },` |

The href was on `main` before the engagement. Commit `6029add` on phase 6
stripped it, reasoning that `ca.la` returns SERVFAIL — it does not, the resolver
on this machine does. Phase 7 put it back. That is this round's own work done a
branch early, not an unrequested addition, and the round's rule is explicit:
"Do not remove pre-existing code. If it was on `main` before this engagement it
stays."

Tab 14 is the only tab that touches external links and `ca.la` is not one of its
20 rows. The only two rows that ask for a link to change at all are A10
(`crazyegg`, "Remove or replace citation") and A11 (`topgrading`, "Link to
Topgrading homepage or remove"). Nothing there reaches a customer-logo href.

### The two files I was told to apply the same test to

**`SEO-CHANGELOG.md` — stays.** Rule 4 names the file and the location in one
sentence. Not in this branch's diff; added by `6229f91` on
`seo-phase-1-2-deorphan-crawl`.

**`BLOCKED.md` — flagged, left alone.** Rule 3 asks for it by name ("Log
anything you cannot automate … in a running `BLOCKED.md` rather than
improvising") and Phase 3 item 2 asks for it again ("log the page build in
`BLOCKED.md`"), so the artefact is authorised. Neither mention says "in the
repo", which is exactly the phrase that decided the report file one paragraph
above. I cannot settle from the text whether the two adjacent rules share an
implied location or whether the phrase appears in one and not the other because
they differ. Over-removal is worse than a flagged uncertainty, so it stays and
is reported as uncertain. If it does come out, it comes out on
`seo-phase-3-redirects-canonicals`, where `4fbc64f` added it, not here.

### One thing outside my branch, for whoever holds phase 6

`6029add` stripped a second pre-existing href in the same array and phase 7 did
not restore it: `main` line 24 reads
`{ src: makelog, alt: "Makelog", href: "https://www.makelog.com", width: 100 },`
and both phase 6 and phase 7 read
`{ src: makelog, alt: "Makelog", width: 100 },`. Same shape as the CALA defect,
same rule against removing pre-existing code, still unrestored at the tip of the
stack. It belongs to the phase-6 diff, so I have not put it in my structured
output.
