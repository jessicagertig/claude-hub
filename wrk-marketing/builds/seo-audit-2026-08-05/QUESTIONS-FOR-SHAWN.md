# Questions for Shawn

Deviations from the audit's default expectation that Jessica has approved. Nothing lands here without her approval first. These are shipped, not blocked — Shawn's sign-off comes after the fact.

---

## 1. `/plato` H1 is visually hidden, not visible

**Phase 4 · tab 17 Headings, row 7**

**Audit says:** Add H1: "Plato: AI candidate screening built into your ATS"

**What we did:** Added it with the exact wording, using the visually-hidden pattern (`position: absolute; width: 1px; height: 1px; clip: rect(0 0 0 0)`), so it is in the DOM and read by crawlers and screen readers but not painted on screen.

**Why:** The Plato hero is a black background carrying an animated visual title. A visible H1 would compete with it. Colour-matching the text to the background was considered and rejected — that is cloaking. The visually-hidden pattern is the accessibility idiom, served identically to every agent, and is not cloaking.

**For Shawn:** We know Google weighs a visually-hidden H1 less than a visible one. Confirm that is an acceptable trade here, or tell us the H1 needs to be visible and we will find a placement that works with the hero design.

---

## 2. "Answer-first blocks" is never defined, and the phrasing varies across three tabs

**Tab 13 row 4**, `/blog/interview-feedback-examples`, Refresh scope column, in full:

> "Refresh examples; answer-first blocks"

That is the only occurrence of the phrase in the workbook. Two adjacent asks use different words for what looks like the same intent:

**Tab 01 row 9**, `/blog/employee-turnover`, Recommended action column:

> "Link + refresh; formula & benchmark blocks for AEO"

**Tab 05 row A12**, Notes column:

> "FAQ markup feeds AI answer extraction"

**For Shawn:** what is an answer-first block, concretely? A definition and one worked example would let us apply it consistently rather than each of us inferring a different structure. Specifically: is it a markup change, a heading-structure change, a reordering of existing prose so the answer leads, or a distinct callout element on the page?

---

## 3. The ten examples on the #1 traffic asset are not stale, and we did not touch them

**Tab 13 row 1**, `/blog/problem-solving-interview-questions`, Refresh scope column:

> "Update examples, add 2026 context + author byline + dateModified schema; keep URL"

**Tab 01 row 7**, Why it matters column:

> "Site's #1 traffic asset; #1 on five 590-vol terms"

**What we found:** we read all ten example questions and their model answers. None references a dated technology, practice, or event — they are timeless behavioural questions (initiative, difficult client, recent failure, coworker conflict, difficult decision, when to escalate to a manager, project risk, supplier misses a deadline, competing priorities, and a curveball). The audit names no defect in them; the only stated reasons for touching the post are its 2022 publish date and its position at the top of a traffic-weighted refresh order.

**What we did instead:** left the ten intact, on the reasoning that rewriting the body of a page ranking #1 on five 590-volume terms risks the ranking for no identified gain. Updated the one genuinely dated item — a Gallup figure, "59% of Millennials believe a job that accelerates their professional development is important" — and added 2026 context as new material alongside the ten rather than inside them.

**For Shawn:** if "update examples" meant something specific you saw in those ten, tell us which and why. Otherwise confirm that leaving the #1 asset's body alone is the right call.

**Separately, what does "add 2026 context" mean on this post?** We are replacing every dated figure with its most recent published value and current URL regardless — that part is not waiting on you. But the post's subject is problem-solving interview questions specifically, not interviewing practice generally. The candidates we came up with — AI in screening, remote and async interviewing — are about interviewing generally and would dilute a page ranking #1 on five terms for its actual topic. If you had particular context in mind, name it.

---

## 4. Proposed, not in the audit: promote two labels to H4 on the same post

Each of the ten questions is an H3. Under each sit two labelled sections — "What to look for in a good answer" and "Red flag answers" — which render as plain paragraphs rather than headings, so an answer engine sees ten questions each followed by undifferentiated prose.

**This is our idea, not the audit's.** No tab asks for it. Promoting the labels to H4 changes no wording, skips no heading level, and the `blogPost` schema already permits H4.

**For Shawn:** worth doing, or unnecessary?
