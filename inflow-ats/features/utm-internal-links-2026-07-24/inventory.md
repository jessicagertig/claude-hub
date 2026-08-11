# UTM tagging for internal links to Polymer marketing properties

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Branch:** `attribution-work-qa`
**Date:** 2026-07-24
**Params:** `utm_source=polymer_app&utm_medium=internal`

Scope: front-end links that leave the app for a Polymer marketing property (`polymer.co`, `www.polymer.co`, `help.polymer.co`). Inventory produced by an 8-agent ultracode sweep — 358 raw link rows across the repo, reduced to the 19 sites below. Raw data in `raw-inventory.json` and `raw-workflow-output.json`.

---

## Decisions

| | Decision |
|---|---|
| S1 | Params are `utm_source=polymer_app&utm_medium=internal`. snake_case, matching the values already set in the Stripe dashboard and the Google OAuth consent screen (web console config, not in this repo) |
| S2 | `utm_medium` is required |
| S3 | Job-board surfaces are out of scope entirely. No in-scope link was already tagged — the only two already-tagged marketing links are the job-board footer (`_footer.html.erb:4`) and its dead React twin (`job_board/src/components/shared/Footer/index.js:14`), both job-site surfaces. Adding mediums to the pre-existing `appEmail` / `individual` / `WeWorkRemotely` mailer values is a separate project |
| S4 | `developer.polymer.co` is out of scope |
| S5 | `/terms` and `/privacy` are tagged |
| S6 | App-bound links (`app.polymer.co`, `jobs.polymer.co`, `individual.polymer.co`, `connect.polymer.co`) are not in scope |

---

## In scope — 19 sites

### `app/javascript/shared/` — renders in ats, account, and connect

| # | File:line | URL |
|---|---|---|
| 1 | `app/javascript/shared/components/PolymerBar.tsx:132` | `https://polymer.co/changelog` |
| 2 | `app/javascript/shared/components/PolymerBar.tsx:136` | `https://help.polymer.co` |

`window.open(url, "_blank")` in `handleChangelogClick` / `handleHelpClick`, bound to the "Changelog" and "Help docs" buttons at lines 199 and 195. `PolymerBar` renders via `app/javascript/shared/layouts/AppAuthedWrapper.tsx:53` (account + connect) and the ats `AppContainer`.

### `app/javascript/ats/` — nav

| # | File:line | URL |
|---|---|---|
| 3 | `app/javascript/ats/src/components/shared/UserNav.tsx:39` | `https://polymer.co/changelog` |
| 4 | `app/javascript/ats/src/components/shared/UserNav.tsx:43` | `https://help.polymer.co` |

`window.open`, bound to the "Changelog" and "Support" buttons at lines 108 and 103.

### `app/javascript/ats/` — settings, via `Button type="externalLink"`

All render through the shared `Button` (`app/javascript/ats/src/components/shared/Button/index.js:229-241`) as `<a href={link} target="_blank" rel="noopener noreferrer">`.

| # | File:line | URL |
|---|---|---|
| 5 | `app/javascript/ats/src/views/accountAdmin/AccountCommentTemplates.tsx:194` | `https://help.polymer.co/en/articles/5506525-using-review-templates` |
| 6 | `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx:95` | `https://polymer.co/pricing` |
| 7 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsDiscord.tsx:134` | `https://help.polymer.co/en/articles/5721747-have-new-candidate-notifications-show-up-in-a-discord-server` |
| 8 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsLinkedIn.tsx:226` | `https://help.polymer.co/en/articles/8828635-post-your-jobs-to-linkedin` |
| 9 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsSlack.tsx:125` | `https://help.polymer.co/en/articles/5721143-have-new-candidate-notifications-show-up-in-a-slack-workspace` |
| 10 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsWebflow.tsx:536` | `https://polymer.co/blog/use-webflow-cms-to-display-your-wrk-job-posts-on-your-webflow-site` |
| 11 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsXHiring.tsx:109` | `https://help.polymer.co/en/articles/9415910-post-your-jobs-to-x-hiring` |
| 12 | `app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsZapier.tsx:24` | `https://help.polymer.co/en/articles/6218084-trigger-automated-workflows-in-zapier` |
| 13 | `app/javascript/ats/src/views/accountAdmin/accountJobBoard/AccountJobBoardCustomDomain.tsx:162` | `https://help.polymer.co/en/articles/10250419-configuring-a-custom-domain` |

### `app/javascript/ats/` — raw anchors

| # | File:line | URL |
|---|---|---|
| 14 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx:50` | `https://polymer.co/terms` |
| 15 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx:51` | `https://polymer.co/privacy` |
| 16 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx:122` | `https://polymer.co/terms` |
| 17 | `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx:123` | `https://polymer.co/privacy` |
| 18 | `app/javascript/ats/src/views/sessions/components/FormLogoHeader.tsx:9` | `https://polymer.co` |
| 19 | `app/javascript/ats/src/views/sessions/components/HeaderBar.tsx:26` | `https://polymer.co` |

14-17 are `<a target="_blank" rel="noopener noreferrer">` inside `Styled.Terms`. 18-19 are `<a className="app-header__logo">` with no `target` — same-tab. 18 is on every auth form page, 19 on the sessions header bar.

---

## Eliminated from scope

| Site | Reason |
|---|---|
| `accountAdmin/AccountApiKeys.tsx:161` — `developer.polymer.co/#introduction` | S4 |
| `app/views/job_board/partials/_footer.html.erb:4` — `www.polymer.co?utm_source=polymerJobsPage` | S3, job-board surface |
| `individual_app/careers_page_subscriptions_controller.rb:15` — `redirect_to` marketing on unsubscribe failure | Server redirect, not a front-end link |
| `config/routes.rb:704` — `root to: redirect('https://polymer.co')` | Server 301, not a front-end link |
| `config/routes.rb:37` — legacy wrk.xyz → polymer.co 301, ENV-gated | Server 301, not a front-end link |
| `generate_xml/linkedin_feed.rb:55`, `x_hiring_feed.rb:54` — `xml.publisherURL` | Feed metadata, not a link |
| `ats/src/components/shared/UserNav.tsx:47` — `polymer.co/#pricing` | Dead: `handlePricingClick` has no callsite |
| `ats/src/components/modals/SubscriptionRequiredModalNew.tsx:151` — `polymer.co/pricing` | Dead: not imported anywhere |
| `ats/src/components/modals/SubscriptionRequiredModalNewLegacy.tsx:149` — `polymer.co/pricing` | Dead: not imported anywhere |
| `job_board/src/components/shared/Footer/index.js:14` — `www.polymer.co?utm_source=polymerJobsPage` | Job-board surface, and dead: never imported; the live footer is the ERB partial |
| `ats/src/views/sessions/Login.tsx:37` — `polymer.co/blog/hello-polymer` | Inside a JSX comment block, lines 35-40 |
| ~300 rows pointing at `app.polymer.co`, `jobs.polymer.co`, `individual.polymer.co`, `connect.polymer.co` | S6. Includes every Stripe `success_url` / `cancel_url` / `return_url`, all built server-side from `Variables::AtsRootUrl` |

---

## Implementation

**One constant, no helper function.** Added to `app/javascript/shared/lib/utils.js` in its own section, following the file's existing section-header style. The file is already imported by TypeScript callers via the `@shared` alias (`config/webpack/custom.js:11`, `tsconfig.json:22-23`).

```js
/* Internal links to Polymer marketing properties
--===================================================-- */
export const INTERNAL_UTM_PARAMS = "?utm_source=polymer_app&utm_medium=internal";
```

The leading `?` lives in the constant. All 19 in-scope URLs are bare — verified: no query string, no fragment on any of them — so there is no `?`-vs-`&` case and no fragment case to handle. A helper function that handled those was written first and then deleted; it existed only for inputs this feature does not have.

**Call sites** — each of the 19 becomes a template literal: `` `https://polymer.co/pricing${INTERNAL_UTM_PARAMS}` ``. One changed line per site, no reflowing, no component signatures changed. The two bare `https://help.polymer.co` strings also gain a trailing slash, so the result is `https://help.polymer.co/?utm_…`.

**No test.** A bare exported string constant has no logic to break.

---

## Adversarial review — 12 agents, 6 lenses each followed by a skeptic

22 raw findings, 5 survived refutation. Per-lens verdicts: completeness PASS, emitted-urls PASS, jsx-and-types PASS, conventions FAIL, scope-discipline PASS, test-quality PASS.

Four of the five survivors were the same defect found independently by four lenses.

**Fixed — prettier printWidth 100 regression.** Four call sites were written as single lines of 102-104 characters, while four siblings in the same change used the wrapped form. Three files went prettier-clean → prettier-dirty because of it: `AccountBilling.tsx:96`, `AccountIntegrationsXHiring.tsx:110`, `AccountJobBoardCustomDomain.tsx:163`. Wrapped all four to prettier 2.2.1's exact output (`AccountIntegrationsLinkedIn.tsx:227` too, though that file had 7 pre-existing over-length lines and was already dirty). All three regressed files are clean again.

**Fixed — ghost test.** Every assertion interpolated the same `INTERNAL_UTM_PARAMS` the implementation uses, so the params payload cancelled out on both sides: setting the constant to `""` left all four tests green. Moot now — the helper and its test file were deleted in favour of the plain constant.

**Superseded — prettier reflows.** Both prettier findings were about multi-line wrapping of long `link={withInternalUtm(...)}` lines. Jessica's call: smallest possible diff wins over formatter cleanliness. Every reflow was collapsed back to a single line, then the helper was removed entirely, which shortened the lines anyway. Nothing enforces prettier in this repo — husky pre-commit runs Cypress plus a lint-staged rule scoped to `api_public` Ruby, and the `linters` job in `.github/workflows/ci.yml` is commented out.

**Final state:** 19 call sites, 15 files, 15 imports, 16 files in the diff, **+38 / −20** (down from +75/−20 at peak). `eslint` on all 16 changed files: 0 errors, 51 pre-existing unused-var warnings, none from this change.
