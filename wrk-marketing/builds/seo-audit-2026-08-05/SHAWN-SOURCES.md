# Supplementary clarifications

**`Polymer-Technical-SEO-Audit_MakeReality.xlsx` is the source of truth. It is not superseded by anything in this file.**

This file exists for one narrow purpose: to record clarifications Shawn has supplied that the workbook does not contain. Nothing here is an alternative instruction set, and nothing here licenses going looking for material elsewhere.

How to use it:

- **The workbook decides.** Where this file and the workbook cover the same thing, the workbook wins.
- **This file is consulted only when the workbook is silent or ambiguous on a specific point** — never as a starting point, never browsed for ideas.
- **Everything here is quoted verbatim** from something Jessica passed on. If it is not in quotation marks with a stated origin, it does not belong in this file.
- **Nothing gets added here without Jessica providing it.** No agent goes hunting for further sources.

One clarification the workbook does contain and which was missed: the definitions in the Overview tab's Recommended fix column define terms the detail tabs then use bare. That is inside the workbook, not outside it, and it should have been read first.

---

## Documents we have

| Document | Where | Status |
|---|---|---|
| `Polymer-Technical-SEO-Audit_MakeReality.xlsx` | `builds/seo-audit-2026-08-05/` | Read. 19 tabs. |
| The master prompt | `PolymerNextJSSanityMasterPrompt.md` in the same directory | Read. Executed as phases 1-7. |
| The prioritised action list below | pasted by Jessica, 2026-08-06 | Recorded here. |

## Documents referenced but NOT in our hands

Named inside his own instructions. Work that depends on them cannot be scoped from what we have.

- **"the keyword plan"** — Overview K19: *"Execute the AEO tier of the keyword plan (definitional + cost + comparison content, answer-first formatting)"*. Also Overview #17's fix: *"Give /plato an H1 ('Plato AI candidate review' phrasing from the keyword plan)"*.
- **"combined workbook: Page & Content Plan tab"** — named as the source for the post refresh scope in item 9 below.
- **"241-keyword combined Keyword & Content Gap workbook"** — named in the item that was dropped as out of scope.

---

## The prioritised action list

Provided by Jessica 2026-08-06, renumbered 1-10 with his week groupings removed at her instruction. The tenth item, rank tracking in SE Ranking, was dropped as not ours.

1. De-orphan the nine legacy blog posts (audit tab 01): add blog-index pagination and related-post links so every post is reachable. Claude-automatable.
2. Restore /contact (22 backlinks currently hitting a 404; enterprise CTA dead-ends — audit tab 06). Claude-automatable.
3. Ship robots.txt with AI crawlers allowed, and sitemap.xml covering all pages including the de-orphaned posts (tabs 02-03); submit to Search Console. Claude-automatable.
4. Add self-referencing canonicals site-wide, including the parameter URL carrying 243 backlinks (tab 04). Claude-automatable.
5. Apply the 13 title rewrites — homepage, pricing and Plato first; give /plato its missing H1 (tabs 07, 17). Claude-automatable.
6. Implement JSON-LD across templates: Organization, SoftwareApplication with real pricing offers, Article, BreadcrumbList (tab 05). Claude-automatable.
7. Publish llms.txt; fix the nine over-length meta descriptions; replace the five dead external links including all help.wrk.xyz remnants (tabs 08, 12, 14, 10). Claude-automatable.
8. Convert Sanity images to webp/avif via URL params and add dimensions — one template-level change fixes ~70 oversized images including a 7 MB PNG (tab 11). Claude-automatable.
9. Refresh the top three orphaned posts in order: employee turnover, behavioral scoring matrix (add downloadable template), problem-solving questions (combined workbook: Page & Content Plan tab). Claude drafts, Polymer approves.

### What this list changes

**Item 2 contradicts the master prompt on `/contact`.** This list says restore it, flatly, and calls it Claude-automatable. The master prompt says *"Restore `/contact` with a demo/sales form if a design exists; otherwise ship the 301 now and log the page build in `BLOCKED.md`"*. We shipped the 301 on the master prompt's qualifier. This list carries no qualifier.

**Item 9 names a source for the refresh scope that we do not have** — the Page & Content Plan tab of a combined workbook. Our refresh planning has been built from tab 13 and tab 01. That tab may specify something different or more.

**Item 9 orders the three posts differently from tab 13.** This list: employee turnover, behavioral scoring matrix, problem-solving questions. Tab 13's refresh order column: problem-solving questions (1), employee turnover (2), behavioral scoring matrix (3).

---

## Definitions, quoted

Terms Shawn uses in detail tabs without defining them there. The definition is usually in the Overview tab's Recommended fix column.

**"Refresh"** — Overview K23, the fix for issue #13:
> "Refresh each post (2026 data, updated modified dates, author bylines, downloadable templates), in the order given in the detail tab."

Four things. This is what the bare word means everywhere it appears on tabs 01 and 13.

**Tab 01's bare "refresh"** — Overview K11 sends it to the same place:
> "...Then refresh the assets (see Content Freshness)."

**"Update the post"** (issue #10, Wrk legacy) — Overview K20:
> "Update the post (title, body, links to current help docs), keep the URL with a refreshed slug only if 301'd."

**"AEO tier"** — Overview K19:
> "Execute the AEO tier of the keyword plan (definitional + cost + comparison content, answer-first formatting), plus items 2/3/5/8 which give AI engines crawlable, structured grounding."

**"Answer-first"** — NOT DEFINED ANYWHERE. Nine occurrences across the workbook, three different phrasings, no definition in any of them:
- Overview K19: "answer-first formatting"
- Tab 13 E10: "Refresh examples; answer-first blocks"
- Tab 01 F9: "formula & benchmark blocks for AEO"
- Tab 05 D12: "FAQ markup feeds AI answer extraction"
- Tab 08 C7: "Mirrors the definitional AEO content"
- Tab 09 E12: "The fix is the AEO tier + comparison pages"
- Tab 13 E14: "Fold into onboarding-process AEO play (320 vol)"

Either it is defined in the keyword plan, or it is a question for Shawn. Filed as question 2 in `QUESTIONS-FOR-SHAWN.md`.

---

## Reading rules established

**Overview describes, detail tab specifies.** Where both mention the same item, the Overview gives the shape and the detail tab gives the exact value. They are not two sources to reconcile. Example: Overview #17 says *"'Plato AI candidate review' phrasing from the keyword plan"* while tab 17 row 7 gives the string *"Plato: AI candidate screening built into your ATS"*. The tab's string is what ships.

**Nothing in these documents is optional.** Tab 08 row 12 labels `llms-full.txt` "Optional second file" and that was read as permission to skip it. Overview K8 says *"Publish /llms.txt (and llms-full.txt)"*. It gets built. Any other item skipped on an optional reading is to be found and done.
