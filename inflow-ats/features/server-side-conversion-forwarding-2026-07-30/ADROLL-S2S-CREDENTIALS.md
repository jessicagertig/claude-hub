# AdRoll / NextRoll S2S conversion events — credentials and required identifiers

Scope: what must be present in a server-to-server conversion event request, and which values are secret. No integration design, no payload schema beyond the identifier fields, no Ruby.

Every claim below traces to a URL in **Sources**. The authoritative host is `apidocs.nextroll.com`, **not** `developers.nextroll.com` — that host serves a JS-only shell (empty body) for `/docs/*` paths and is only the app-registration portal. Anything the docs do not state is marked **unconfirmed** or **inferred** in place.

---

## 1. Answer

A NextRoll S2S conversion event needs exactly one secret — a **Server Access Token (SAT)**, sent as `Authorization: Token <SAT>` — plus two public account identifiers, the **advertisable EID** and the **pixel EID**, both of which are read out of the AdRoll base pixel snippet. The advertisable EID is required twice per request under two different spellings: as the `advertisable` URL query parameter and as the `advertisable_eid` body field; `pixel_eid` is a body field only. **No segment EID exists in this API** (verified negative: zero occurrences of "segment" across all three S2S doc pages) and no OAuth token, `apikey`, consumer key, or Personal Access Token is involved — those belong to the separate CRUD API on `services.adroll.com`.

---

## 2. Required values

| Value (exact spelling) | What it is | Secret or public | Where found in the UI | Source |
|---|---|---|---|---|
| `Authorization: Token <SAT>` | HTTP request header. Scheme is literally `Token`, not `Bearer`. Carries the Server Access Token. | **SECRET** | **Nowhere — no self-serve UI exists.** Doc-stated: contact your AdRoll account manager; delivered via a one-time 1Password share link that expires after seven days and can be opened once. | [s2s-reference] |
| `advertisable` | Required URL **query parameter**. Value is the advertisable EID. `POST https://srv.adroll.com/api?advertisable=<ADVERTISABLE_EID>` | Public identifier | Analytics > Insights > Website > **View Pixel** — the value assigned to `adroll_adv_id` in the base pixel code | [s2s-reference], [ipixel], [gtm] |
| `advertisable_eid` | Required **body** field, snake_case, top level of each event object. "The unique identifier for your AdRoll advertisable." Same value as the `advertisable` query param — sent twice per request. | Public identifier | Same as above | [s2s-events] |
| `pixel_eid` | Required **body** field, snake_case, top level of each event object. "The pixel identifier associated with your AdRoll advertisable." | Public identifier | Analytics > Insights > Website > **View Pixel** — the value assigned to `adroll_pix_id` in the base pixel code | [s2s-events], [ipixel], [gtm] |
| `identifiers` | Required body object. Must contain **at least one of** `first_party_cookie` or `adct`. Other keys (`email`, `email_sha256`, `email_md5`, `device_id`, `user_id`) are optional and "recommended". | Per-visitor data (PII), not a credential — never goes in a credentials file | Not a UI value; captured per visitor at landing time | [s2s-events], [s2s-overview] |
| `event_name`, `page_location`, `ip` | The remaining three required body fields. `event_name` is an enum of 13 values (`pageView`, `homeView`, `productSearch`, `addToCart`, `purchase`, `highValuePage`, `gatedContent`, `demoRequest`, `signupPlan`, `signupTrial`, `contactSales`, `liveChat`, `formFill`). | Public / per-request data | n/a | [s2s-events] |
| `dry_run` | **Optional** query parameter, value `true`. "The payload is validated and logged, but doesn't impact your audiences or attribution." | Public | n/a | [s2s-reference] |

**No segment EID and no third EID of any kind.** Verified negative, not an unknown: independent raw-HTML greps for `segment` / `segment_eid` returned zero hits across `s2s-reference`, `s2s-events`, and `s2s-overview`. `segment_eid` exists elsewhere in NextRoll — the Audience API (`DELETE /audience/v1/sharing/segment`) and the User Lists API — but never in a conversion event.

### Notes on the two EIDs

- **Format:** an EID is an "External ID … alphanumeric characters (e.g. `48F9EA2E5ACAEE24EB766F`)" [object-structure]; the Automated Campaigns reference states an advertisable EID is "22 Characters long" [automated-campaigns]. No published length or charset for the pixel EID specifically. Do not write a format validator on doc authority.
- **Why public:** the docs never use the words "secret" or "public" for either EID, but the classification is doc-**evidenced**, not merely inferred: the CRUD `get_pixel` response returns the pixel JavaScript snippet containing `adroll_adv_id = "6SHGRDIZUBDXLHUG4YHFGC"; adroll_pix_id = "XCOW5YUNQFGR5J5VSDITAX";`, and the same response's pixel object carries `"eid": "XCOW5YUNQFGR5J5VSDITAX"` — the identical value [crud-examples]. That snippet is installed in public page source on every page of the advertiser's site, and the iPixel form embeds both EIDs in a public `<img src>` URL [ipixel]. Values in public page source are not secrets.
- **The `adroll_adv_id` → `advertisable_eid` bridge is inferred**, not doc-stated in a single source. The GTM article says "`adroll_adv_id` = Advertisable ID" [gtm] and the iPixel article says the "Advertisable EID" and "Pixel EID" are "displayed within your base pixel code" at the same View Pixel location [ipixel]. The pixel half of the mapping is doc-evidenced by the `eid` match above; the advertisable half is not. Confirm both against the live dashboard before relying on them.
- **`pixel_eid` required-ness:** three independent raw-HTML reads of `s2s-events` place `pixel_eid` under the literal `Required Fields` heading. One agent working from a WebFetch summary of `s2s-reference` reported a fabricated field table marking every body field "Optional" — that table does not exist in the page source. Treat `pixel_eid` as required, on the strength of the `Required Fields` heading.

### Codebase mapping (codebase-verified, not doc-stated)

Our two captured columns map one-to-one onto the two identifiers that satisfy the API's minimum: `adroll_click_id` (set from the `adct` URL param at `app/javascript/shared/lib/utils.js:147`) → `identifiers.adct`, and `adroll_first_party_cookie` (read from the `__adroll_fpc` cookie at `utils.js:165`) → `identifiers.first_party_cookie`. Either alone satisfies "at least one of `first_party_cookie` or `adct`". The docs never name the `__adroll_fpc` cookie, so the cookie-name half is codebase-verified only.

---

## 3. Authentication

**Mechanism:** a Server Access Token (SAT) in the `Authorization` header using the `Token` scheme. Doc-stated verbatim [s2s-reference]:

> The Server Access Token is sent via the `Authorization` header with the `Token` scheme. For example: `Authorization: Token MYTOKEN`

**Not** OAuth 2.0. **Not** `Bearer`. **Not** Basic auth. **Not** a query-parameter API key. The S2S reference page contains zero occurrences of `apikey`, `Bearer`, `OAuth`, `client_id`, `consumer key`, or `Personal Access Token`.

**Is OAuth additionally required? No.** The endpoint takes exactly one required query parameter, `advertisable`. The OAuth 2.0 flow (`services.adroll.com/auth/authorize`, `/auth/token`, `Authorization: Bearer {ACCESS_TOKEN}`), the Personal Access Token, the consumer key/secret from `developers.nextroll.com`, and the `apikey` query parameter all belong to the **CRUD / general NextRoll API on `services.adroll.com`** — a different host with a different credential model [get-started], [oauth]. The trap: the CRUD API's PAT uses the byte-identical header form `Authorization: Token MYTOKEN`, so the header shape alone cannot tell the two credentials apart. The discriminators are the host (`srv.adroll.com` vs `services.adroll.com`) and the absence of `apikey` on S2S. A PAT is not documented as accepted by the S2S endpoint.

**How the SAT is obtained** [s2s-reference], verbatim:

> You'll need to contact your account manager to access the Server Access Tokens (SATs) required for the S2S API. We will use 1Password to share the necessary credentials with you securely. While 1Password is the tool for this secure sharing process, you won't need to create your own 1Password account. The share link expires after seven days, and the item can only be accessed once.

So: no dashboard page, no self-service generation, and a human handoff with lead time on the critical path. Separately, AdRoll's help center states the S2S path is "currently in beta. Contact Customer Support if you're interested in trying it out" [user-event-audience] — a second, different contact channel from the "account manager" one, unreconciled by the docs.

---

## 4. Proposed credentials-file entries

House form is a per-vendor namespace with the key naming the credential (`sendgrid: marketing_api_key`, `mailgun: api_key`, `stream: api_secret`, `stripe: secret_api_key`).

**Goes in the encrypted credentials file — one key, the SAT:**

```yaml
adroll:
  s2s_api_key: <Server Access Token from the AdRoll account manager>
```

**Does NOT need to be secret — these are public identifiers, visible in our own page source today:**

- the advertisable EID (the `adroll_adv_id` value in our base pixel snippet)
- the pixel EID (the `adroll_pix_id` value in our base pixel snippet)

Both are readable by anyone who views source on any page carrying the AdRoll pixel, and both are embedded in public `<img src>` URLs in AdRoll's own iPixel form. Encrypting them buys nothing and adds a rotation surface. Where they should live instead (env var, `01_variables.rb`, hardcoded constant) is a decision for whoever wires this up, not a credentials-file question.

The endpoint URL `https://srv.adroll.com/api` is likewise public configuration, not a credential.

---

## 5. Gaps

**The S2S events API IS publicly documented.** All three pages (`overview.html`, `events.html`, `reference.html`) return HTTP 200 as static server-rendered Sphinx HTML with no login wall and no JS shell. Field names above were extracted from raw HTML, not from summarizers. What is gated is the *access*, not the documentation.

Unanswered by the docs:

1. **SAT scope, expiry, rotation, revocation — entirely undocumented.** Not stated whether one SAT covers a whole NextRoll organization or is issued per advertisable, whether it expires, or how it is rotated or revoked. This determines how the credential is keyed and stored. Contrast: OAuth access tokens (24h) and refresh tokens (1 year) *are* documented for the other API. Ask the account manager at issuance time.
2. **Whether the `advertisable` query parameter must match the body's `advertisable_eid`.** The same EID is required in both places; the docs never say what happens if they disagree, nor whether one request may batch events for multiple advertisables.
3. **Content-Type is not doc-stated.** Verified negative: zero occurrences of `content-type`, `application/json`, or `curl` across all three S2S pages. There is no curl example anywhere in the S2S section — only bare JSON skeletons and a bare `POST https://srv.adroll.com/api?advertisable=<ADVERTISABLE_EID>` line. `application/json` is the obvious inference; the docs do not say it.
4. **No response contract.** No response body, no status codes, no auth-failure shape. There is no documented way to distinguish a bad token from a bad advertisable EID from a malformed identifier. `dry_run=true` is the documented mechanism for probing safely.
5. **No rate limits, quotas, or payload-size caps for `srv.adroll.com`.** The only stated constraints are gzip support and "no more than one hundred events" per request. The api-key-migration guide's rate-limiting statement applies to `services.adroll.com`, a different host.
6. **The docs never classify `advertisable_eid` or `pixel_eid` as secret or public.** The public classification in §2 is evidence-based (both appear in the client-side pixel snippet), not doc-asserted.
7. **Two unreconciled access channels.** `apidocs.nextroll.com` says "contact your account manager"; `help.adroll.com` says the S2S path is in beta and to "Contact Customer Support." The docs do not say which is correct, nor which account role or package tier can request a SAT.
8. **The API is explicitly unstable.** Verbatim, on every S2S page: "The S2S event API is under active development. Although the API is generally stable, it may change. Event processing is not yet fully complete." Field names here are current as of this fetch, not contractually stable.
9. **The `__adroll_fpc` cookie name is never documented.** The docs describe only how to *obtain* the first-party cookie value (`adroll.get_cookie(callback)`, or self-generate with a one-year validity) and never name the cookie. Our column name is codebase-verified only.

Pages that could not be read directly:

- **All of `help.adroll.com` returns HTTP 403 to automated clients** (Cloudflare JS challenge — body: "Enable JavaScript and cookies to continue"), on both `curl` with a full Chrome UA and WebFetch. The five help-center articles cited in §2 were read through the same site's own Zendesk content API (`https://help.adroll.com/api/v2/help_center/en-us/articles/<id>.json`, HTTP 200), which returns the articles' stored HTML bodies. **Same-origin official content, different transport** — treat the UI click paths as officially sourced but confirm against the live dashboard, since we never rendered the pages.
- `https://developers.nextroll.com/docs/authentication`, `/docs/server-to-server-api/events.html`, `/docs/reporting-api/reference.html` — HTTP 200 but a 2,138-byte JS-only Angular shell with no extractable content. **Do not cite `developers.nextroll.com/docs/*` paths.**
- `https://apidocs.nextroll.com/reporting-api/reference.html` — HTTP 404.
- `https://app.adroll.com/settings/personal-access-tokens` — redirects to the sign-in page. Login-walled; only its URL and section name are doc-confirmed, and it is the CRUD API's credential, not ours.
- `https://developers.nextroll.com/my-apps/new-app` — HTTP 200 but a login-gated registration form; not read. CRUD API only.
- `https://github.com/AdRoll/server-to-server` — readable but useless: `README.md` contains only the string "server-to-server", and the repo holds only first-party-cookie generation samples. No credential or header information.

---

## 6. Sources

**Official — fetched OK (raw HTML, server-rendered):**

- `[s2s-reference]` https://apidocs.nextroll.com/server-to-server-api/reference.html — THE authoritative page. Endpoint, query params, auth scheme, SAT acquisition, request-body skeleton.
- `[s2s-events]` https://apidocs.nextroll.com/server-to-server-api/events.html — the literal `Required Fields` / `Optional Fields` headings and per-event-type schemas.
- `[s2s-overview]` https://apidocs.nextroll.com/server-to-server-api/overview.html — identifier concepts (`adct`, first-party cookie, device ID, email, user ID). No endpoint, no auth, no EIDs.
- https://apidocs.nextroll.com/server-to-server-api/index.html — section landing page, no credential detail.
- `[object-structure]` https://apidocs.nextroll.com/guides/object-structure.html — EID = "External ID … alphanumeric".
- `[automated-campaigns]` https://apidocs.nextroll.com/automated-campaigns-api/reference.html — the only official statement of an EID length (22 characters, advertisable).
- `[crud-examples]` https://apidocs.nextroll.com/crud-api/examples.html — `get_pixel` response showing `adroll_adv_id` / `adroll_pix_id` inside the pixel snippet, and the pixel object's matching `eid`.
- `[get-started]` https://apidocs.nextroll.com/guides/get-started.html — CRUD API auth (PAT + `apikey`, `services.adroll.com`). Cited only to mark the distinction.
- `[oauth]` https://apidocs.nextroll.com/guides/oauth.html — OAuth 2.0 endpoints, Bearer scheme, token lifetimes. CRUD API only.
- https://apidocs.nextroll.com/crud-api/reference.html — `eid` as the generic entity identifier; `apikey` documented as "Required if using Personal Access Tokens (PAT)".
- https://apidocs.nextroll.com/audience-api/reference.html — where `segment_eid` actually lives. Zero occurrences of `identifiers`.
- https://apidocs.nextroll.com/guides/ecommerce-integration.html — API retrieval path for the EIDs (`get_advertisables` → `eid` → `get_pixel`).
- https://apidocs.nextroll.com/guides/pixel-javascript-api.html — negative control. Zero occurrences of `advertisable_eid`, `pixel_eid`, `adroll_adv_id`, `adroll_pix_id`, `dry_run`, or `Authorization`.
- https://apidocs.nextroll.com/guides/api-key-migration.html — `apikey` and the `services.adroll.com` migration. **Appears stale**: says OAuth 2.0 is planned while `get-started` and `oauth` document it as live.
- https://apidocs.nextroll.com/searchindex.js — site-wide Sphinx term index, used to prove verified negatives (`dry_run` → only `server-to-server-api/reference`; `adroll_adv_id` → only `crud-api/examples`; no `status` term on any S2S page).
- `[gtm-partners]` https://partners.adroll.com/partners/google-tag-manager — "`adroll_adv_id` = Advertisable ID and `adroll_pix_id` = Pixel ID"; UI path "AdRoll > Website > View Pixel".
- https://github.com/AdRoll/server-to-server — official AdRoll org. Effectively empty.

**Official — HTML blocked (HTTP 403), read via `help.adroll.com/api/v2/help_center/en-us/articles/<id>.json`:**

- `[ipixel]` https://help.adroll.com/hc/en-us/articles/360034422852-iPixel-Match-Audience — the only official article naming "Advertisable EID" and "Pixel EID" *with* a click path. Updated 2026-04-27.
- https://help.adroll.com/hc/en-us/articles/360047152971-Where-can-I-find-my-Pixel-code — second statement of the same path. Updated 2025-10-08.
- https://help.adroll.com/hc/en-us/articles/211846018-What-is-the-AdRoll-Pixel — third statement, adds the left-menu location and Copy button. Updated 2026-04-08.
- `[gtm]` https://help.adroll.com/hc/en-us/articles/212675687-Connect-AdRoll-to-your-Site-Install-the-Pixel-with-GTM — `adroll_adv_id` / `adroll_pix_id` labels. Updated 2025-10-28.
- `[user-event-audience]` https://help.adroll.com/hc/en-us/articles/360045120371-User-Event-Audience — the only S2S mention in the entire help center; states beta + "Contact Customer Support". Updated 2026-06-09.
- https://help.adroll.com/hc/en-us/articles/40192198764557-How-to-Connect-AdRoll-and-AppsFlyer — confirms "Advertisable EID" / "Pixel EID" as customer-facing terms handed to third-party server-side partners. Updated 2025-10-13.
- https://help.adroll.com/hc/en-us/articles/4413646006797-Personal-Access-Tokens — CRUD API credential, not ours. Updated 2026-06-10.
- https://help.adroll.com/hc/en-us/articles/360040116252-Connect-AdRoll-to-your-Site-Add-the-Pixel-to-your-Website-Header — Updated 2025-10-28.

**Official — FAILED, nothing reported from these:**

- https://developers.nextroll.com/docs/authentication — empty JS-only shell
- https://developers.nextroll.com/docs/server-to-server-api/events.html — 2,138-byte Angular shell
- https://developers.nextroll.com/docs/reporting-api/reference.html — empty JS-only shell
- https://apidocs.nextroll.com/reporting-api/reference.html — HTTP 404
- https://app.adroll.com/settings/personal-access-tokens — login wall
- https://developers.nextroll.com/my-apps/new-app — HTTP 200, login-gated form, not read

**Third-party sources: none used.** No Segment, Stape, Zapier, or vendor-tutorial page contributed any field name, header, or click path above.
