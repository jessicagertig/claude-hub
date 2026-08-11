# LinkedIn Extension — Codebase Investigation Findings

Investigation of the four "investigate, not invent" targets in `GENERAL-GUIDE.md`. All paths under the worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.linkedin-extensions/` (branch `linkedin-extensions`, off `develop`). Facts are cited to `file:line`. A closing section surfaces implications and open decisions for the spec — it does not design them.

---

## Target 1 — The manual-add candidate endpoint and its file input

### Headline finding: the manual-add path has no working resume upload; the resume slot lives on the JobApplication

Today the resume slot that triggers the Textract + AI pipeline is reached only through the **resume-edit tab** of an existing application, as a **two-step** flow on the **JobApplication** (not the Candidate):

1. **Direct-upload the file → get a signed blob id.** `POST /api/v1/public/rails/active_storage/direct_uploads` → `Api::V1::Public::DirectUploadsController#create` (`config/routes.rb:345-346`). This endpoint is **unauthenticated** (`direct_uploads_controller.rb:3-6`, `skip_before_action :verify_authenticity_token`) and already CORS-open. It returns an Active Storage `signed_id` string. Frontend `FormUploader.tsx:181-183` (`new DirectUpload(...)`).
2. **Attach the signed id to the JobApplication.** `PUT /api/v1/job_applications/:id` with body `job_application[resume] = "<signed_id>"` → `Api::V1::JobApplicationsController#update` (`config/routes.rb:291`; controller `job_applications_controller.rb:88`). Frontend `JobApplicationResume.tsx:58-79`. This is the **only authenticated path that explicitly enqueues Textract** (`job_applications_controller.rb:107-117`: `SubmitResumeToTextractJob` + `DocxToPdfJob` + `auto_generate_ai_summary_if_enabled`).

**The manual-add candidate path does not upload a resume.** `NewCandidateModal.tsx` sends JSON only — no file, no `DirectUpload`. The candidate-create endpoint `POST /api/v1/jobs/:job_id/candidates` → `Api::V1::CandidatesController#create` (`config/routes.rb:237`) permits `:resume` via `candidate_policy.rb:34`, but that attachment lands on the **Candidate** record (`candidate.rb:14` `has_one_attached :resume`) and **never reaches the JobApplication and never triggers Textract**. `SubmitResumeToTextract#submit_resume` returns early `"No resume attached" unless @job_application.has_resume` (`submit_resume_to_textract.rb:10`), and `has_resume` reads `resume.attached?` on the JobApplication only (`job_application.rb:624-625`) — there is no Candidate→JobApplication resume copy on normal creation (confirmed absent; the only copy is `clone_to_job_at_hiring_stage`, `job_application.rb:436`). There is even a stubbed-but-unused `job_application_params` (`candidates_controller.rb:222`, `params.require(:job_application).permit(:resume)`) that `create` never calls.

**Consequence:** giving the manual-add path a working resume upload means duplicating the exact two-step resume-edit mechanism into that path — attach the `signed_id` to the JobApplication (as the public apply path does via `resume_signed_id`) so `enqueue_new_job_application` / `SubmitResumeToTextractJob` runs. It is the same mechanism, not a new one.

### Params contract

- **Candidate create** — `candidates_controller.rb:214-219`: `params.require(:candidate).permit(policy(Candidate).permitted_attributes)`. Permit list (`candidate_policy.rb:34-42`): `:first_name, :last_name, :email, :phone, :location, :photo, :resume, :cover_letter, :linkedin_url, :twitter_url, :github_url, :dribbble_url, :website_url, :created_via`.
- **Resume upload (operative)** — `job_applications_controller.rb:182-184`: `params.require(:job_application).permit(policy(JobApplication).permitted_attributes)`, permit list includes `:resume` (`job_application_policy.rb:33-46`).
- **File is passed as an Active Storage direct-upload signed_id string, NOT raw multipart.** Frontend: `FormUploader.tsx:181-183` runs `new DirectUpload(file, "/api/v1/public/rails/active_storage/direct_uploads")`; `JobApplicationResume.tsx:58-79` sends `job_application: { resume: blob.signed_id }` as a JSON body (`api.ts:47-52`, `Content-Type: application/json`).

### Records + associations

- `Candidate` (`candidate.rb:10-17`): `has_many :job_applications`, `has_many :jobs, through: :job_applications`, `belongs_to :organization`.
- `JobApplication` is created by the through-association when `job.candidates.build(...)` is saved (`candidates_controller.rb:23`). `belongs_to :candidate`, `belongs_to :job`, `has_one_attached :resume` (`job_application.rb:35`), `has_many :textract_results`, `has_many :ai_job_application_summaries`, `has_one :ai_job_application_summary_status`.
- No separate "Applicant" model; the resume-upload endpoint mutates an existing JobApplication, it does not create records.

### What triggers Textract + AI

- **Resume upload path (explicit)** — `job_applications_controller.rb:107-120`: on `update` with `:resume` present → `DocxToPdfJob.perform_later`, `set_ai_summaries_stale`, and if not docx and `Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, current_organization)` → `SubmitResumeToTextractJob.perform_later`, then `auto_generate_ai_summary_if_enabled`.
- **JobApplication creation path** — `after_commit :enqueue_new_job_application, on: [:create]` (`job_application.rb:46, 181-189`): `NewJobApplicationJob`, `DocxToPdfJob`, `SubmitResumeToTextractJob` (same Flipper gate), `auto_generate_ai_summary_if_enabled`, `find_or_create_ai_job_application_summary_status`. This is how the **public apply** path triggers Textract — it attaches `resume_signed_id` to the JobApplication *before* save, so the resume is present when the callback fires.
- Downstream: `SubmitResumeToTextractJob` → `SubmitResumeToTextract` (builds `TextractResult`, `textract_job_status: in_progress`) → `GetResumeTextFromTextractJob.set(wait: 2.minutes)` → `GetResumeTextFromTextract#parse_resume_text`.
- **Gate:** all Textract enqueues sit behind the `TEXTRACT_RESUME_PROCESSING` Flipper feature, per organization.

### File-type / size validation

- `application/pdf` accepted. JobApplication: rejects non-`DOCUMENT_CONTENT_TYPES` and `errors.add(:resume, 'must be a PDF or a DOCX file')` (`job_application.rb:628, 955`). Candidate: `candidate.rb:335-336` accepts `application/pdf` + DOCX. DOCX/DOC converted to PDF via `DocxToPdfJob` before Textract; only non-docx (PDF) submits to Textract immediately.
- **No explicit size cap on the `:resume` slot** (only `additional_files` has `less_than: 10.megabytes`, `job_application.rb:40-41`).

### Contrast with the public apply endpoint

`POST /api/v1/public/organizations/:organization_id/jobs/:id/apply` → `Api::V1::Public::JobsController#apply` (`config/routes.rb:347-351`). Same base class `Api::V1::BaseController`, but `skip_before_action :authenticate_api_v1_user!` (`jobs_controller.rb:4`); gated by ReCaptcha (`Recaptcha::Verifier`, `jobs_controller.rb:17`) instead of Devise. Attaches resume via `job_application.assign_attributes(resume: params[:candidate][:resume_signed_id])` (`jobs_controller.rb:37,67,87`). Single `:name` split via `name_splitter`; inline permit list, not policy-based (`jobs_controller.rb:151-157`). Serializer `ShallowCandidateSerializer`. No Pundit.

**Traced chain:** `routes.rb:291 → job_applications_controller.rb:88 → job_application_policy.rb:33 → job_application.rb:35 → SubmitResumeToTextractJob → submit_resume_to_textract.rb → TextractResult / GetResumeTextFromTextractJob`; candidate path `routes.rb:237 → candidates_controller.rb:7 → candidate_policy.rb:34 → candidate.rb:14/23 → job_application.rb:46/181`.

---

## Target 2 — How the current session is readable from a same-origin app page

### Headline

Auth is a **Rails/Devise HttpOnly session cookie** (Warden), set at `POST /api/v1/login`. Every SPA API call is a **relative same-origin request** that carries that cookie automatically — there is no header token, no `withCredentials`, and the entire `/api/v1` namespace **skips CSRF**. A content script on the Polymer domain can therefore issue a credentialed same-origin `GET /api/v1/me` (or hit a new same-origin token-mint endpoint) and be authenticated exactly as the SPA is, with no token or CSRF handling.

### Details

- **Devise mapping** `api_v1_user` — `devise_for :users` nested under `namespace :api / :v1` (`config/routes.rb:123`; confirmed `base_controller.rb:9` `alias current_user current_api_v1_user`, `routes.rb:80` `devise_scope :api_v1_user`). Modules (`user.rb:24-25`): `:database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable, :trackable, :validatable`. **No** `:token_authenticatable`, **no** `:omniauthable`.
- **Transport is cookie, not header.** `base_controller.rb:6` `before_action :authenticate_api_v1_user!`. Login runs Devise `super` → `sign_in` sets the session cookie (`sessions_controller.rb:8-14`). Frontend `api.ts` sends only `Accept`/`Content-Type` on GET (`:8-13`) and adds only `X-CSRF-Token` on mutations (`:43-52`) — **no `Authorization`, no `withCredentials`**. All paths are relative (`` `/api/v1${path}` ``) so the cookie rides automatically. Legacy JWT/Bearer logic is fully commented-out dead code (`base_controller.rb:13-21`).
- **Current-user endpoints:** `GET /api/v1/session` (`routes.rb:90` → `sessions_controller.rb:19-22`) and `GET /api/v1/me` (`routes.rb:93` → `me_controller.rb:5-9`), both render `Api::V1::SessionSerializer`. SPA bootstraps via React Query `useGetMe` → `apiGet({ path: '/me' })` (`AppAuthRouter.tsx:76`, `useMe.ts:8-10,71`), populating `CurrentSessionProvider` (`CurrentSessionContext.tsx:75`). On 401 it redirects to `/logout`.
- **Session cookie config:** **NO `config/initializers/session_store.rb`** and no `config.session_store` anywhere → Rails default `ActionDispatch::Session::CookieStore`. `config/application.rb:52` sets `config.load_defaults 6.0`, so the 6.1 default `cookies_same_site_protection = :lax` is **not** applied — **no SameSite attribute is set**. Cookie is **HttpOnly** (framework default) → **not readable via `document.cookie`**; usable only by letting the browser attach it to a same-origin request. `secure` only via `config.force_ssl = true` in production (`production.rb:57`). No domain attribute (host-only cookie).
- **CSRF:** `ApplicationController` uses `protect_from_forgery with: :null_session` (`application_controller.rb:7-8`); the API namespace does `skip_before_action :verify_authenticity_token` (`base_controller.rb:4`) and sessions skips again (`sessions_controller.rb:4`). So `GET /api/v1/me` succeeds on the cookie alone with no CSRF token. The SPA still sends `X-CSRF-Token` on mutations (sourced from `<meta name="csrf-token">`, `useCSRFToken.ts:3-9`), but the API controller does not enforce it.
- **Same-origin auth-state exposure to JS:** **none** beyond the CSRF meta tag — no `window.__BOOTSTRAP__`, no gon, no user meta tag. Identity is obtained only at runtime via the authenticated `GET /api/v1/me`. Layout globals (`application.html.erb:73-92`) are non-identity config only.
- **Convention note:** all `/api/v1` JSON responses arrive **snake_case** from Rails and are camelCased client-side by `allKeysToCamel` (`cursor_rules/frontend/_base.md:67-85`). An extension parsing `/api/v1/me` gets raw snake_case.

**Traced chain:** `routes.rb → user.rb → base_controller.rb → application_controller.rb → sessions_controller.rb / me_controller.rb → session_serializer.rb`; frontend `application.html.erb → AppAuthRouter.tsx → useMe.ts → api.ts → CurrentSessionContext.tsx`.

---

## Target 3 — Existing token / signing utilities (before introducing anything)

Everything needed for a short-lived, user-scoped Bearer token already exists in-tree — **no new dependency required.** Stack: **Ruby 3.1.6, Rails 6.1.7.7** (`Gemfile:6,10`; `Gemfile.lock:406`). Rails 6.1 → **`generates_token_for` / `find_by_token_for` are NOT available** (that is Rails 7.1).

### Closest analog: `MagicLink` (short-lived, user-scoped, DB-lookup token)

- Mint: `magic_link.rb:11` `self.generate` → `create(user:, intent:, expires_at: 10.minutes.from_now, token: generate_token, ...)`; `:18` `Devise.friendly_token(20)`.
- Verify: `magic_links_controller.rb:17` `MagicLink.where(token: params[:token]).where('expires_at > ?', DateTime.now).first`, then `sign_in('api_v1_user', @magic_link.user)`, marks `has_been_used: true` (`:26`). Routes `routes.rb:54-55`.
- Shape: plain random token (not HMAC/signed), user-scoped, `expires_at` column, single-use. This is the pattern most aligned with the plan's "short-lived, user-scoped token."

### Org Bearer scheme already in place: `ApiKey`

- `api_public/v1/hire/base_controller.rb:57-83`: `before_action :authenticate_api_key!` → `extract_bearer_token` (reads `Authorization: Bearer …`, `:78`) → `key_digest = Digest::SHA256.hexdigest(token)` → `ApiKey.find_by(key_digest:)`. Gated behind `Flipper.enabled?(:CUSTOMER_API, ...)`.
- Mint: `api_key.rb:13-20` `SecureRandom.hex(32)`; stores only `Digest::SHA256.hexdigest(key)` (`key_digest`, unique index) + `key.last(4)` (`key_hint`); raw key returned once, never persisted. **Org- and organization_user-scoped, long-lived (no expiry).** (The plan explicitly rejects reusing this org key — but its Bearer extractor + SHA256-at-rest pattern are the house form to copy.)

### Other token patterns present

- **Invites** (`invite.rb:34` `Digest::SHA1.hexdigest([...])`, verify `invites_controller.rb:9,29`) — DB-lookup, no expiry.
- **Zapier key** (`organization.rb:456` `SecureRandom.uuid`, `zapier_integrations_controller.rb:39-42`, `X-API-KEY` header) — plaintext, org-scoped, long-lived.
- **Devise** `reset_password_token` / `confirmation_token` on User + Individual (schema).
- **Active Storage** `find_signed` used only for blob signed-ids (`job_application_files_controller.rb:35`) — not auth.

### NOT present

- `gem 'jwt'` is **commented out** (`Gemfile:121`); `jwt 2.5.0` is transitive-only. No live `JWT.encode/decode` in app (only a comment in dead `handle_old_proof_token`, `base_controller.rb:17`).
- No `devise-jwt` / `devise_token_auth` / `:token_authenticatable`.
- No `has_secure_token`, no app use of `ActiveSupport::MessageVerifier` / `MessageEncryptor` / `Rails.application.message_verifier`.
- No `AccessToken` / `PersonalAccessToken` / `AuthToken` model; no `authentication_token` / `unlock_token` / `invitation_token` columns.

Available-but-unused Rails 6.1 built-ins if a **stateless** signed token were ever preferred over a DB row: `has_secure_token`, `ActiveSupport::MessageVerifier`.

---

## Target 4 — CORS configuration needed to accept an Authorization header

### Headline

`rack-cors 1.0.2` (`Gemfile:87`) is configured **inline in `config/application.rb:88-106`** (there is **no** `config/initializers/cors.rb`), inserted at `config.middleware.insert_before 0, Rack::Cors`. `origins '*'` (hardcoded, **not** env-driven), but scoped to **three path prefixes only**:

```ruby
resource '/v1/hire/*',                       headers: :any, methods: [:get]
resource '/api/v1/public/*',                 headers: :any, methods: [:get, :put, :post]
resource '/rails/active_storage/disk/*',     headers: :any, methods: [:get, :put, :post]
```

- **`Authorization` header: allowed** on those three resources (`headers: :any` → rack-cors 1.0.2 short-circuits `allow_headers? → true`, echoes the requested header back on preflight).
- **Credentials: never sent.** `origins '*'` forces `public_resource = true`, which forces `credentials = false` (`rack/cors.rb:334`); `Access-Control-Allow-Origin` is returned as literal `*`. A **Bearer token in the `Authorization` header does not need CORS credentials mode** (that governs cookies / client certs), so a Bearer request is fine on the covered paths — but a **cookie would not cross** (which is consistent with the plan using a token, not the cookie, cross-origin).
- **No other CORS mechanism:** no controller sets `Access-Control-*` headers; no manual OPTIONS route; the only other `Access-Control-Allow-Origin: *` hits are `webpacker.yml` dev-server headers (irrelevant to app responses). ActionCable origin allowlist is commented out.
- **Precedent for opening an endpoint externally:** the app hardcodes `origins '*'` and scopes by adding a path-prefixed `resource '<path>/*', headers: :any, methods: [...]` entry. No origin allowlisting via env var exists.

### The gap that matters for this feature

The authenticated candidate endpoints from Target 1 are **NOT** in the CORS-allowed set:

- `POST /api/v1/jobs/:job_id/candidates` — under `/api/v1/*`, **not** `/api/v1/public/*` → **no CORS resource matches** → a cross-origin (`chrome-extension://…`) POST is browser-blocked today.
- `PUT /api/v1/job_applications/:id` — same, **not covered** → blocked cross-origin today.
- `POST /api/v1/public/rails/active_storage/direct_uploads` — **is** under `/api/v1/public/*` and POST is allowed → the direct-upload step **is** already CORS-open.

**Traced chain:** `Gemfile:87 → Gemfile.lock:396 → application.rb:88-106 → routes.rb:345 (/api/v1/public), routes.rb:474 (/v1/hire) → rack/cors.rb:283,334,391,415`.

---

## Implications and open decisions for the spec (surfaced, not designed)

These are decisions the PLAN leaves open once the facts above are known. Flagging them so the spec phase makes them explicitly rather than an implementer picking silently.

1. **The resume slot is two steps and lives on the JobApplication; the manual-add path lacks it.** Direction (Jessica, 2026-07-20): add resume upload to the manual-add path by duplicating the same two-step resume-edit mechanism — direct-upload PDF → attach `signed_id` to the JobApplication so `enqueue_new_job_application` / `SubmitResumeToTextractJob` runs. This reuses the existing mechanism; it is not a new pipeline. **Open sub-decision:** whether the extension does this as the authenticated two-call sequence (create candidate JSON, then attach resume to the resulting JobApplication) or the manual-add endpoint itself is extended to accept the `signed_id` in the create call (attaching to the JobApplication the way public apply does via `resume_signed_id`).

2. **CORS is the real blocker, not auth.** The candidate/upload endpoints live under `/api/v1/*`, which has no CORS resource. Options: add a new path-scoped `resource` entry to `application.rb` for the specific endpoint(s) the extension calls; **or** expose a purpose-built, token-authenticated ingest endpoint under the already-CORS-open `/api/v1/public/*` prefix. **Decision needed: widen CORS for existing endpoints vs. new public-prefixed token endpoint.** (Either way, the `Textract` gate is `TEXTRACT_RESUME_PROCESSING` per org.)

3. **Token mint is same-origin and needs no CORS/CSRF.** The content script that reads the session and mints a token runs on the Polymer domain → same-origin, cookie rides automatically, API namespace skips CSRF. So the mint endpoint is unconstrained by the CORS gap. Only the extension's cross-origin candidate calls hit the CORS gap. **No new CSRF handling needed for the mint.**

4. **Token mechanism should reuse `MagicLink`'s shape, verified via `ApiKey`'s Bearer extractor.** `Devise.friendly_token(n)` + `expires_at` DB row (MagicLink) for mint; `Digest::SHA256` digest-at-rest + `Authorization: Bearer` extraction (ApiKey) for verify. No `jwt`/`MessageVerifier` needed. **Decision needed: new user-scoped token model vs. extending an existing one** — but the primitives are all in-tree (no new gem).

5. **The direct-upload endpoint is unauthenticated.** `Api::V1::Public::DirectUploadsController` skips auth entirely — the blob/signed_id can be created by anyone; the auth gate is the attach step. The extension can reuse it as-is for step (a)'s upload; the Bearer token only guards the candidate/JobApplication mutation.

6. **HttpOnly means the extension cannot read the cookie value.** It can only trigger same-origin credentialed requests from a content script on the Polymer page. This is why the connect flow must run its token mint from a Polymer-domain tab, not from the LinkedIn page.
