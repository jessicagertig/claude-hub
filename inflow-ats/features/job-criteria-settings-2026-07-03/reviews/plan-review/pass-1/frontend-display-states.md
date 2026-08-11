# Frontend display-state derivation, loading states, and the payload contract — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| F.2.1.3 six-state table implements SPEC 8.2 exactly | Row-by-row diff against SPEC 8.2 | ✓ identical priorities 0-5, identical conditions, identical copy strings, EmptyState variants standard (no roomy/borderless), button-label rule identical. **Failed latest (rows 2/3) outranks criteria-present (row 4): the failure/zero-found empty state renders even when an older succeeded row exists — flag 5 implemented as ruled. NO trace anywhere in plan.md of the reverted "show latest successful when latest is failed" fallback (searched the whole plan for any such display behavior)** |
| Empty-state copy DECISIONS-verbatim | Diffed rows 2/5 strings against DECISIONS "Empty states" | ✓ byte-identical; row 3 copy is the SPEC-drafted failure state (DECISIONS: "not designed — draft the copy") ✓ |
| D-2: EmptyState props only `title`/`message`/`icon`/`borderless`/`roomy` | EmptyState.tsx:7-13 | ✓ exact — no action/button prop; action row outside the component is the only valid placement |
| D-3: `Icon` takes ONLY `name`; ships stroke-width 1.75px | Icon/index.js:12-23 | ✓ `const Icon = ({ name }) =>`; css height/width 1.25em, stroke-width 1.75px — bundle `size` props would be silently dropped; svg-wrapper CSS is the correct mechanism (precedent RunPlatoAddDescriptionModal.tsx:75-81 `svg { width: 1rem; height: 1rem; }` verified) |
| D-4 token names | lightTheme.ts:4-34 + darkTheme.ts + theme.ts:3-56 | ✓ `canvas`, `border`, `loudText`, `primaryText`, `secondaryText`, `placeholderText`, `subtleHover`, `cardCanvas`, `cardBorder` ALL exist in BOTH light and dark poly themes; accessor `t.poly.color.*` confirmed real (`props.theme.poly.color.canvas`, AppDefaultWrapper.tsx:41; ThemeProvider sets `poly: isDarkMode ? darkTheme : lightTheme`, :74). `gray[100]`/`gray[700]` both exist in theme.ts (:7, :14) for the divider row. `t.dark ?` pattern is the codebase idiom (AccountTeam styled) |
| D-5 `isInFlight` = payload in-flight OR `isFetching` | SPEC 8.3 ("payload status in-flight OR the modal-owned POST just fired and the query is refetching") | ✓ covers the required just-POSTed window; broader-than-required cost (background refetches) documented in R-3 with the gate-ruling escape. Backend-status-driven, survives reload (DECISIONS loading-state mandate) ✓ |
| P12 loading treatment | OrganizationAiUsage.tsx:29-31 (`isLoading || !balance ? <LoadingIndicator label="Loading..." />`), :17-19 (`props.history.push`) | ✓ both exact |
| F.2.1.4 FormSection `intro` prop takes element | FormSection/index.js:11 (destructured), :36 (`{intro ? <p>{intro}</p> : null}`), :47 (propTypes `oneOfType([element, string])`) | ✓ all three exact |
| Intro copy explains automatic lifecycle + description link | DECISIONS "Section intro must ALSO explain the automatic lifecycle" | ✓ drafted copy covers publish + description-update re-extract + point-in-time scoring; link route `/jobs/${job.id}/setup/description` verified at RunPlatoAddDescriptionModal.tsx:32 |
| F.2.1.5 `PlatoChip size={36} radius={18}`, gradient + ring built in | PlatoMark.tsx:60-66 (`function PlatoChip({ size = 26, radius, ... })`, style width/height/borderRadius) | ✓ props real; "do NOT re-style" consistent with DECISIONS "reuse the existing production asset" |
| `distanceInWords` adds "ago" | time.ts:89-91 (`formatDistanceToNow(..., { addSuffix })`, default true) | ✓ |
| F.2.1.2 TIERS uses stored `tier_1`-form values | extract_criteria.rb tier writes (`criterion['tier'] = 'tier_1'` / `'tier_3'` verified) + DECISIONS payload-shape-is-ours | ✓ bundle `tier1` keys correctly rejected |
| F.2.2.2 sidebar via `SettingsContainer` `sidebar` prop | SettingsContainer.tsx:10 (`sidebar?: any`), :72 (`{sidebar && <Styled.Sidebar>}`) | ✓ exact |
| F.2.2.3 layout consequence: `hasSidebar` → Content 50vw at lg; sidebar `display: none` below lg | SettingsContainer.tsx:116-126 (Styled.Content `width: ${props.hasSidebar ? "50vw" : "100%"}`), :196-208 (Styled.Sidebar `display: none` + lg block) | ✓ both exact; QA re-verify noted (R-4) |
| P13 sidebar register | AccountTeam.tsx:441-477 (SidebarContent JSX: sticky aside, h3, per-entry h4 + p with bold lead), :515-552 (styled) | ✓ exact |
| D-7 sidebar copy: bold leads DECISIONS-verbatim; trailing sentences from decisions.html wording | DECISIONS "Sidebar tier glossary" + design/bundle-1-decisions/README.md:55-58 + JobSetupPlatoAI.jsx:231-239 | ✓ leads byte-match DECISIONS (which win where the bundle differs — bundle has "Must-haves. These count most…", DECISIONS has "Must-haves that count most…"); intro + trailing sentences byte-match the decisions.html wording carried in the bundle |
| F.2.2.1 `props.history` available | JobSetupContainer.tsx:487 (`<JobSetupAiSettings {...props} {...renderProps} setIsDirty={setIsDirty} />` inside a `<Route render>`) | ✓ route renderProps include `history` |
| D-1 extraction: JobSetupAiSettings.tsx is 83 lines; `jobSetup/components/` exists; `JobCriteriaSection.tsx` absent | wc -l + ls | ✓ all three; ~300-line section estimate makes >400 threshold (component_size_and_extraction.md: ">400 lines: Extract components") a sound basis; SPEC §13 made the file conditional and delegated the call to the plan |
| F.2.2 keeps existing form byte-preserved | JobSetupAiSettings.tsx:15-80 read (dirty tracking, onSubmit, BottomBarContent, Plato reviews FormSection) | ✓ plan touches none of it; error-toast pattern claim (:39-45) exact |
| Hook file F.1.1 SPEC-verbatim; key `["aiJobCriteria", jobId]`; `enabled: jobId != undefined`; hook-level invalidation | Diffed against SPEC 8.1; useAiJobApplicationSummary.ts:35-47 (key + enabled analog), react_query_queries.md :65-66 (array keys), react_query_mutations_and_cache.md :30 (hook-level callbacks primary pattern) | ✓ all verified; `apiGet({path})`/`apiPost({path, variables})` signatures match api.ts:5/:25 |
| No fabricated fallbacks / no `??` / snake_case enum values / double quotes / separate styled variants / Emotion utilities standalone | F preamble + F.2.1.7 + G | ✓ rules carried explicitly (core 10, frontend/_base §1 verified real, core 7 enum exception, pipeline 1/12/13); F.2.1.2 counts computed only in state 4 where `criteria` known present (no `|| []`) |
| Styled idiom `let Styled: any; Styled = {};` after default export | BulkGenerateAiSummariesConfirmModal.tsx:200-201 | ✓ (plan cites :198-252; file is 251 lines — LOW drift) |

## Completeness (vs SPEC §8.1-8.3, §12-13)

- SPEC 8.1 hook file → F.1.1 ✓ verbatim
- SPEC 8.2 all six states + action-row placement note → F.2.1.3 + D-2 ✓
- SPEC 8.3 every bullet: hooks, FormSection+intro+link, card (560px/7px/PlatoChip 36/distanceInWords/count rail/Bonus-only-when-present/tabular figures), TIERS constant, action row + modal wiring, empty states, sidebar glossary, styled-component rules, extraction call → F.2.1.1-F.2.1.7, F.2.2.1-F.2.2.3, D-1..D-5, D-7 ✓ complete
- SPEC 12/13 frontend: no tests (documented) → H ✓; file inventory carried → C ✓ (JobCriteriaSection made definite per D-1, SPEC-sanctioned)

## Findings

- F3 [LOW] F.2.1.7 cites `BulkGenerateAiSummariesConfirmModal.tsx:198-252` for the Styled idiom; the file is 251 lines (block at ~:198-251). Unambiguous.

## Amendments Applied

None required for this angle.
