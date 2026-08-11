# LinkedIn Extension — Architecture

Design agreed on the investigation findings (see `INVESTIGATION.md`). Grounding cites `file:line` in the worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.linkedin-extensions/`. This is the shape, not an implementation plan.

## Three parts

| Part | Lives in | Responsibility |
|---|---|---|
| 1. Backend | existing inflow-ats repo | Mint endpoint, ingest endpoint, one CORS entry |
| 2. Connect/handshake page | existing inflow-ats repo (app frontend) | Authenticated Polymer page the extension opens; mints the token and hands it to the extension |
| 3. Extension | new separate repo | LinkedIn content script (trigger + grab profile PDF), token storage + silent refresh, the call to the ingest endpoint |

Parts 1 and 2 ship in the app. Part 3 is the separate repo.

## How the parts talk

- **Extension ↔ connect page** — same-origin. The connect page's content script calls the mint endpoint (session cookie rides, the API namespace skips CSRF — `base_controller.rb:4`), then hands the token to the extension via `chrome.runtime.sendMessage`.
- **Extension → backend ingest** — cross-origin. `Authorization: Bearer <token>`; the session cookie does not and cannot ride cross-origin (CORS `origins '*'` forces credentials false — `application.rb:88-106`).
- **Cross-repo contract** — the token format, the ingest request/response shape, the backend base URL (extension config), and the CORS allowance for the extension origin. Keep the endpoints stable.

## Authentication

- **Original auth** — unchanged. The human logs into Polymer; Devise session (HttpOnly cookie, same-origin), mapping `api_v1_user` (`user.rb:24-25`).
- **After-auth token** — a short-lived, user-scoped signed token minted from the live session and sent Bearer on the cross-origin ingest call.
  - **Mechanism:** `ActiveSupport::MessageVerifier` via `Rails.application.message_verifier(<name>)` — a Rails built-in, **no new gem, no new table**. Confirmed unused in the app today (`grep` for `message_verifier`/`MessageVerifier`/`MessageEncryptor` across `app lib config` → zero hits).
  - **Payload:** the user id (+ a `purpose:` label scoping the token to this one use), signed. `#generate(payload, expires_in: 30.minutes, purpose: "<label>")`; `#verify(token, purpose: "<label>")`. Rails 6.1 supports `expires_in:` and `purpose:`.
  - **Lifetime:** ~30 minutes, self-expiring. Reusable until expiry (not single-use); the extension silently re-mints when it expires.
- **Mint endpoint** — same-origin, session-authenticated (`authenticate_api_v1_user!`). Returns a fresh token for `current_user`. No CORS, no CSRF handling needed.
- **Ingest endpoint auth** — token, **not** session. A before_action extracts the Bearer token (the `ApiKey` extractor is the house form — `api_public/v1/hire/base_controller.rb:78`), verifies the signature + expiry, resolves the user from the payload, then normal Pundit authorization applies.

### Revocation

Revocation rides on the user, not on a per-token record. The ingest auth resolves the user from the token on every request, so **deactivating (`OrganizationUser#deactivate` → `is_active: false`, `organization_user.rb:66`) or deleting the user stops the token**. No per-token table, no version column — consistent with the app never having built token-revocation infrastructure. Individual early-revocation of one live token is not supported; the ~30-minute window is the accepted exposure bound. (The existing deactivation flow already destroys API keys — `after_update :revoke_api_key_on_deactivation`, `organization_user.rb:29,180` — the analogous enforcement point.)

## Ingest endpoint — what it does

Creates the candidate record from the profile PDF and runs the existing pipeline:

- Builds the Candidate + JobApplication and attaches the PDF as the JobApplication's `resume` (the Active Storage signed_id slot — `job_application.rb:35`), which fires `enqueue_new_job_application` `after_commit on: [:create]` → `SubmitResumeToTextractJob` + `DocxToPdfJob` + auto AI summary (`job_application.rb:46,181-189`). Gated by `TEXTRACT_RESUME_PROCESSING` per org.
- **Copies the mechanism** from the public apply path (`Public::JobsController#apply`, `jobs_controller.rb:36-37,63,67,84-92`): candidate + JobApplication + `resume` = signed_id.
- **Does NOT copy** the public apply path's two liabilities: it is **not public/unauthenticated** (it is token-authed + Pundit-authorized), and it avoids the `@candidate.reload` (`jobs_controller.rb:45`) and inline-logic warts — complex logic goes in an interactor per `controllers/controller_patterns_and_crud.md`.

### Related: manual-add resume gap

The in-app manual-add path (`NewCandidateModal.tsx` → `POST /api/v1/jobs/:job_id/candidates`) uploads no working resume today: it sends JSON only, and `candidate_policy.rb:34`'s permitted `:resume` attaches to the **Candidate** (dead-end, no pipeline). Adding a working resume upload there is the same two-step resume-edit mechanism applied to that path. Build strategy (Jessica): build the extension ingest endpoint and the manual-add resume addition in parallel, diff at the end, decide whether to combine. The diff collapses to **auth mode only** — manual-add authenticates by session (internal), the extension by token (cross-origin); same candidate+JA+resume mechanism underneath.

## CORS

- The authenticated `/api/v1/*` endpoints are not in the current CORS-allowed set (only `/v1/hire/*`, `/api/v1/public/*`, `/rails/active_storage/disk/*` — `application.rb:88-106`).
- The ingest endpoint needs one path-scoped `resource '<prefix>/*', headers: :any, methods: [:post]` entry added to `application.rb` (the house form), allowing the extension origin to send `Authorization`. `headers: :any` already permits the `Authorization` header on covered paths.
- The mint endpoint stays same-origin → no CORS entry.

## Open sub-decisions (small)

1. **Ingest namespace** — a dedicated base controller doing `authenticate_extension_token!` (token-auth + CORS isolated to one prefix) vs. bolting token-auth onto an existing action. Leaning dedicated namespace.
2. **Upload shape** — single multipart POST to the token-authed ingest endpoint (file in body, fully token-gated) vs. two-step (reuse the already-public direct-upload `/api/v1/public/rails/active_storage/direct_uploads` for the blob, then ingest the signed_id, matching public apply). 
3. **Exact token lifetime** — ~30 min proposed.
