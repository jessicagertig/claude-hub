# Verify: AiJobApplicationSummaryStatus topic — OLD vs NEW reframe

**Verdict: CLEAN**

## Scope
AiJobApplicationSummaryStatus data model + 4-value transition table + dedicated section
(lifecycle ownership, every transition, every reader, windows where the row differs from the
latest summary), the 3 writers, and counter_culture behavior.

## Files / regions checked
- OLD: changelog X1/X2 (`237-258`), 5.3 table (`675-691`), Part 9 dedicated (`763-836`),
  AI Summary Data Model (`571-608`), data-model callbacks (`589-593`), frontend F1 (`276-288`),
  reconciliation note (`290-295`).
- NEW: Overview (`19`), Data models (`71-96`, plus AiJobApplicationSummary callbacks `64-69`),
  5.x table (`476-488`), dedicated section (`503-547`), Frontend consumers summary (`550-557`).

## CHECK 1 — Fact preservation: every load-bearing OLD fact confirmed present in NEW

| OLD fact (cite) | NEW location |
|---|---|
| 4-value enum `{none:0,initial_summary_pending:1,current:2,regenerating:3}` (`a_j_a_s_status.rb:9-14`) | NEW `78`, `476` |
| No `regenerating` boolean column; value 3; columns list; migration `20260611120001`; schema `168-179` | NEW `79-82`, `72` |
| `create_status_record` callback REMOVED from summary | NEW `69`, data-model `66`; dedicated transition implied |
| counter_culture `[:job_application,:job]` → `jobs.ai_job_application_summaries_count`, `status IN (2,3)`; two-part literal (proc + column_names) | NEW `87` (full literal) |
| Backing column present `db/schema.rb:907` v2026_06_22_182504; sibling cols `:908/:909`; no missing-column/raise | NEW `87` |
| counter_culture sole callback-bearing behavior; `.update`/save fire it; two `update_columns` (`:15`, `textract_result.rb:104`) bypass | NEW `87`, `482-484`, `488`, `516-518`, `546` |
| Role-fit band scopes `:20-24` | NEW `89` |
| `unscored`/`fit_bands` read table `job_application.rb:106-113` | NEW `526` |
| `set_initial_summary_pending` writer `textract_result.rb:104-107` / `:98-108` | NEW `510`, `482` |
| Unique idx `:178` backs uniqueness + RecordNotUnique rescue `:43-44`; idx `:177` on summary id | NEW `92-93` |
| No-op pass-through (row exists, summary not succeeded) `:42`; common case at none/init/regen | NEW `486`, `519` |
| Concurrency rescue `RecordNotUnique :43-44` reload-returns | NEW `92`, `509` |
| Save-failure `context.fail! :37-38` → caller skips set_initial (`textract_result.rb:72`) | NEW `509` |
| regenerating-flip status-only `:15` keeps old denormalized data (cause of regenerating render) | NEW `483`, `517`, `541` |
| update_summary_status_record re-points `ai_job_application_summary_id` unconditionally `:75`; sole reconciler regen→current | NEW `66`, `518` |
| Desync: failed/retrying leaves row stuck; no `failed` enum value | NEW `488`, `540` |
| `on: :update` only; would not fire on already-succeeded create; reaches succeeded via `.update` | NEW `66`, data-model `66`, `511` |
| `:70` caller NOT every generation — `:68` early-return precondition | NEW `509` |
| Reverse `has_one` on summary model `:8`; two belongs_to / two has_one; reached via `job_application.…` `:71` | NEW `51`, `95` |
| Maintenance reader `recurring_tasks.rake:79 counter_culture_fix_counts` (siblings `:76-78`) | NEW `525`, `546` |
| 5.3 table — all 5 to-state rows (none, current create-path, init_pending, regenerating, current success-path) with writers/preconditions/reached-by | NEW `480-484` (row-for-row) |
| 5.3 dead ends (stuck init_pending; stuck regenerating + no-credit `:77→:82` before `:84`; no row → serializer null) | NEW `483`, `488`, `542`, `544` |
| Lifecycle ownership (unconditional owner JobApplication; 3 creator/advancers); wrapper `:160-162` | NEW `508-511`, `95` |
| Every transition in words (none / current-create / none→init / existing-succeeded→regen / init|regen→current / no-op) | NEW `514-519` |
| Every reader: serializer attrs `:4-6` + method `:8-10`; ShallowJA `:23-24`; JA serializer `:40-41`; controller includes `:27,:38,:56` | NEW `522`, `554` |
| QueueBulkAiSummaryJobs reads `status: :current` `:36-40` | NEW `523` |
| Frontend list `JobApplicationListContainer.tsx:220/226/235/236`; NavItem scalar props `:17-18`; Harvey ball `:26-29` | NEW `527` |
| PlatoTab full reader `:42,:46,:50,:52,:151,:154,:187,:210,:218`, `:130`, fallbacks `:127`/`:129`, gate `useAiJobApplicationSummary.ts:45` | NEW `528` |
| JobApplicationActivity `:79-91` (87/88/89/90/91), publishedAtTimestamp untyped `jobApplication.ts:1-9` | NEW `529` |
| bulkAiSummaryCount.ts `:37-41`/`:46` excludes current | NEW `530` |
| PlatoOverviewCallout `:13`/`:40-47`, zero callers, two same-named files | NEW `531` |
| Websocket JobChannel `:73-76`/`:77-81`; GlobalChannel `:227/:241/:253/:281` prefix-match list key `useJobApplication.ts:185` | NEW `532-533` |
| No optimistic-UI write; `useJobApplication.ts:229` setQueryData in onSuccess | NEW `534` |
| TS interface 4-value union `jobApplication.ts:4`, path `app/javascript/shared/types/jobApplication.ts` | NEW `535`, `257` (note) |
| Desync windows 1-8 (in-flight incl. S-E awaiting_job_criteria; failed/retrying; regen keeps old data; S-D/T2 stuck + no credit + auto-gen OFF stays current; list vs per-status; no row; current pointing at stale summary, no stale guard; counter_culture bypass) | NEW `539-546` (1-8 row-for-row) |

No DROPPED facts. No ALTERED file:line or flipped conditions found — every line number and
condition (`status IN (2,3)`, `:68` precondition, `:69` guard `saved_change_to_status? &&
status_succeeded?`, `:77→:82→:84` credit path, `:101/:102` set_initial guards) matches OLD.
De-duplication (e.g. OLD repeats the no-credit `:77/:82/:84` chain in 5.3, Part 9, and the
reconciliation note; NEW states it in the table row `483` and window `542`) is not a drop.

## CHECK 2 — Neutrality
No banned vocab or framing in the NEW topic regions (data-model `71-96`, table `476-501`,
dedicated section `503-547`, frontend `550-557`). OLD's defect-framing labels were neutralized:
- OLD "Every desync window" → NEW "Windows where the row differs from the latest summary"
  (`537`), with explicit "stated factually" (`538`).
- OLD "Dead ends" / "Stuck" / "no-op pass-through" / "silent dead end" → NEW "resting",
  "Pass-through (no write)" (`486`,`519`), neutral graph statements.
- `cleanup_orphaned_summary` (allowed method name) does not appear in these regions.

No residual `should`/`never recovers`/`incorrect`/`problem`/`defect`/`wrong`/`matters`/
`concerning`/judgmental ALL-CAPS in the topic text.
