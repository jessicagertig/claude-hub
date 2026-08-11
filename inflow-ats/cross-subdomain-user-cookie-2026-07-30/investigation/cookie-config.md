# Cross-subdomain user-ID cookie — configuration investigation

**Worktree read:** `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie` (branch `cross-subdomain-user-cookie`)
**Installed gem root:** `/Users/jessica/.rvm/gems/ruby-3.1.6/gems`
**Date:** 2026-07-30

---

## Headline: one given in the brief is wrong

The brief states "Development runs on `lvh.me:5007`." The repo says the authenticated hire app runs on **`app.lvh.me:5007`** — a subdomain, not the bare domain:

- `cypress.config.ts:9` — `baseUrl: "http://app.lvh.me:5007"`
- `config/initializers/rack_attack.rb:16-17` — development `APP_HOSTNAME_LIST = ['app.lvh.me', 'app.ngrok.io', 'api.lvh.me']`
- `config/routes.rb:541` wraps all authenticated app routes (including `root to: 'pages#root', as: :app_root` at `config/routes.rb:568`) in `constraints SubdomainAppConstraints`
- `app/services/subdomain_app_constraints.rb:5-8` — requires `request.subdomain.present? && request.subdomain.start_with?('app')`

This distinction decides question 2. `domain: :all` produces `.lvh.me` on host `lvh.me` but **`.app.lvh.me` on host `app.lvh.me`** — verified empirically below. Because the real dev host is `app.lvh.me`, bare `domain: :all` breaks development.

---

## File chain traced

**Gem source (installed bundle):**
```
Gemfile.lock
  → actionpack-6.1.7.7/lib/action_dispatch/middleware/cookies.rb
      (CookieJar#[]=, #handle_options, #write_cookie?, #make_set_cookie_header, AbstractCookieJar, PermanentCookieJar)
      → rack-2.2.9/lib/rack/utils.rb  (add_cookie_to_header)
      → rack-2.2.9/lib/rack/request.rb (Helpers#scheme, #ssl?, #forwarded_scheme)
  → actionpack-6.1.7.7/lib/action_dispatch/http/url.rb
      (URL.tld_length, URL.extract_domain, URL.extract_domain_from, Request#domain/#subdomain)
  → actionpack-6.1.7.7/lib/action_dispatch/http/request.rb (Request includes Rack::Request::Helpers)
  → actionpack-6.1.7.7/lib/action_dispatch/middleware/host_authorization.rb
  → actionpack-6.1.7.7/lib/action_dispatch/railtie.rb  (always_write_cookie)
  → railties-6.1.7.7/lib/rails/application/configuration.rb  (load_defaults 6.1 → cookies_same_site_protection)
  → railties-6.1.7.7/lib/rails/application/finisher.rb  (setup_default_session_store)
```

**Repo:**
```
config/application.rb  (load_defaults 6.0; module InflowATS; Rack::Cors)
  → config/environments/{development,test,production}.rb  (config.hosts, force_ssl, default_url_options)
  → config/initializers/01_variables.rb  (APP_DOMAIN_LIST, MARKETING_BASE_URL, AtsRootUrl)
  → config/initializers/rack_attack.rb  (APP_HOSTNAME_LIST per env)
  → config/initializers/devise.rb  (remember_for)
  → config/initializers/content_security_policy.rb  (entirely commented out)
  → config/initializers/cookies_serializer.rb
  → config/routes.rb:541 → app/services/subdomain_app_constraints.rb
                          → config/initializers/01_variables.rb:95 (APP_DOMAIN_LIST)
  → app/controllers/account/pages_controller.rb:5   (cookies[:account_referrer])
  → app/controllers/connect/pages_controller.rb:7   (cookies[:connect_referrer])
  → app/javascript/shared/hooks/useCookieValue.ts → useReferrerCookie.ts
  → app/javascript/shared/lib/utils.js:41  (document.cookie read)
  → app/services/posthog/identify.rb:12  (distinct_id: @user.id.to_s)
  → cypress.config.ts:9
```

**Empirical probes** (scripts in scratchpad, run via `bundle exec ruby` against the repo's own bundle — real `ActionDispatch::Cookies::CookieJar` over `Rack::MockRequest`, no app boot, no DB):
`cookie_probe.rb`, `cookie_probe2.rb`, `cookie_probe3.rb`

---

## 1. Rails and Rack versions; the `ActionDispatch::Cookies` contract

### Versions (`Gemfile.lock`)

| Gem | Version | Gemfile.lock line |
|---|---|---|
| `rails` | 6.1.7.7 | 406 |
| `actionpack` | 6.1.7.7 | 37 |
| `actionview` | 6.1.7.7 | 50 |
| `activesupport` | 6.1.7.7 | 81 |
| `rack` | 2.2.9 | 393 |
| `devise` | 4.8.1 | 155 |

Installed at `/Users/jessica/.rvm/gems/ruby-3.1.6/gems/actionpack-6.1.7.7` and `.../rack-2.2.9` (`bundle show`).

**Framework defaults are `6.0`, not `6.1`** — `config/application.rb:52`: `config.load_defaults 6.0`. This is load-bearing for SameSite (question 4).

### Full list of supported options on `cookies[] = {...}`

Two consumers read the hash. `CookieJar#handle_options` (`cookies.rb:427-475`) reads `:expires`, `:path`, `:same_site`, `:domain`, `:tld_length`. `Rack::Utils.add_cookie_to_header` (`rack-2.2.9/lib/rack/utils.rb:237-262`) reads `:domain`, `:path`, `:max_age`, `:expires`, `:secure`, `:httponly` (falling back to `:http_only`), `:same_site`, `:value`.

| Option | Read at | Emitted as | Notes |
|---|---|---|---|
| `:value` | `cookies.rb:352` | the cookie value | `Rack::Utils.escape`d (`cookies.rb:406-408`, `utils.rb:263`) |
| `:path` | `cookies.rb:432` | `path=` | **defaults to `"/"`** — `options[:path] ||= "/"` |
| `:domain` | `cookies.rb:437-474` | `domain=` | `:all`, `"all"`, an Array, or a String. See Q2 |
| `:tld_length` | `cookies.rb:449-453` | *(not emitted)* | only consulted when `:domain` is `:all`; harmlessly ignored by Rack |
| `:expires` | `cookies.rb:428-430`, `utils.rb:242` | `expires=` (httpdate) | a `Time`, or any object responding to `from_now` (an `ActiveSupport::Duration`) |
| `:max_age` | `utils.rb:241` | `max-age=` | accepted by Rack; Rails does not touch it |
| `:secure` | `utils.rb:243`, `cookies.rb:424` | `; secure` | see Q5 — also gates whether the header is written at all |
| `:httponly` / `:http_only` | `utils.rb:244` | `; HttpOnly` | |
| `:same_site` | `cookies.rb:434-435`, `utils.rb:245-257` | `; SameSite=...` | `false`/`nil` → omitted; `:none`/`:lax`/`:strict`/`true` → emitted; anything else raises `ArgumentError` |

### `:domain` handling — `handle_options`, `cookies.rb:437-474`

```ruby
if options[:domain] == :all || options[:domain] == "all"
  cookie_domain = ""
  dot_splitted_host = request.host.split('.', -1)

  if request.host.match?(/^[\d.]+$/) || dot_splitted_host.include?("") || dot_splitted_host.length == 1
    options[:domain] = nil
    return
  end

  if options[:tld_length].present?
    if dot_splitted_host.length >= options[:tld_length]
      cookie_domain = dot_splitted_host.last(options[:tld_length]).join('.')
    end
  else
    if !(/\.[^.]{2,3}\.[^.]{2}\z/.match?(request.host))
      cookie_domain = dot_splitted_host.last(2).join(".")
    else
      cookie_domain = dot_splitted_host.last(3).join('.')
    end
  end

  options[:domain] = if cookie_domain.present?
    ".#{cookie_domain}"
  end
elsif options[:domain].is_a? Array
  options[:domain] = options[:domain].find do |domain|
    domain = domain.delete_prefix(".")
    request.host == domain || request.host.end_with?(".#{domain}")
  end
end
```

A **String** `:domain` falls through both branches untouched and is emitted verbatim.

### `:expires`

`cookies.rb:428-430`: `options[:expires] = options[:expires].from_now if options[:expires].respond_to?(:from_now)`. So an `ActiveSupport::Duration` (`1.year`) is converted to an absolute `Time` at write. Rack then writes `"; expires=#{value[:expires].httpdate}"` (`utils.rb:242`). Verified: `expires: 1.year` → `expires=Fri, 30 Jul 2027 18:37:02 GMT`.

### Defaults when you pass nothing

| Option | Default | Evidence |
|---|---|---|
| `secure` | **absent** (i.e. false) | `utils.rb:243` `secure = "; secure" if value[:secure]` — nil → no attribute |
| `httponly` | **absent** (i.e. false) | `utils.rb:244` `if (value.key?(:httponly) ? value[:httponly] : value[:http_only])` — both nil → no attribute |
| `same_site` | **absent** in this app | `cookies.rb:434-435` `options[:same_site] ||= request.cookies_same_site_protection.call(request)`; `cookies.rb:72-74` `get_header(COOKIES_SAME_SITE_PROTECTION) || Proc.new { }`. With `load_defaults 6.0` the config is never set, so the empty proc returns `nil` → no attribute. See Q4 |
| `path` | `"/"` | `cookies.rb:432` |

Verified — a bare `cookies[:x] = { value: "12345", domain: "polymer.co" }` on `app.polymer.co` emits exactly:

```
plain_demo=12345; domain=polymer.co; path=/
```

No `secure`, no `HttpOnly`, no `SameSite`. **`httponly: false` is already the default in this app** — passing it is documentation, not a behavior change.

---

## 2. `domain: :all` vs an explicit domain string — the central question

### What `domain: :all` computes, per host

Traced through `cookies.rb:437-467` and confirmed by running the real `CookieJar`:

| `request.host` | `domain: :all` (no tld_length) | `domain: :all, tld_length: 2` | Code path |
|---|---|---|---|
| `app.polymer.co` | **`.polymer.co`** ✅ | `.polymer.co` ✅ | regex miss → `last(2)` (`cookies.rb:457-458`) |
| `www.polymer.co` | `.polymer.co` ✅ | `.polymer.co` ✅ | same |
| `polymer.co` | `.polymer.co` ✅ | `.polymer.co` ✅ | same |
| `lvh.me` | **`.lvh.me`** ✅ | `.lvh.me` ✅ | same |
| **`app.lvh.me`** | **`.app.lvh.me`** ❌ | **`.lvh.me`** ✅ | regex **hit** → `last(3)` (`cookies.rb:460-461`) |
| `localhost` | *(no domain attribute)* | *(none)* | `dot_splitted_host.length == 1` → `options[:domain] = nil; return` (`cookies.rb:443-446`) |
| `127.0.0.1` | *(none)* | *(none)* | `request.host.match?(/^[\d.]+$/)` → nil (`cookies.rb:443-446`) |

**Why `app.lvh.me` breaks.** The heuristic at `cookies.rb:457` is `/\.[^.]{2,3}\.[^.]{2}\z/` — "does the host end in `.XX(X).YY`", meant to catch multi-label public suffixes like `co.uk` and `com.au`. `app.lvh.me` ends in `.lvh.me`: `lvh` is 3 non-dot characters and `me` is exactly 2, so the regex matches and actionpack concludes `lvh.me` is a two-label TLD. It then takes `last(3)` → `app.lvh.me` → emits `Domain=.app.lvh.me`. That cookie is scoped to `app.lvh.me` and its subdomains only.

`app.polymer.co` escapes this only by luck: the label before `.co` is `polymer` (7 chars), outside the regex's 2-3 character window.

**Answer to the central question:** bare `domain: :all` gets `.polymer.co` in production but **not** `.lvh.me` in development, because the real dev host is `app.lvh.me`, not `lvh.me`. It computes `.app.lvh.me`, and the marketing-site read would silently fail locally with no error anywhere.

### `tld_length`

- **Default is 1**: `url.rb:13` — `mattr_accessor :tld_length, default: 1`.
- **Trap:** `:tld_length` means two different things in the two places it appears.
  - In the cookie option (`cookies.rb:452`): `dot_splitted_host.last(options[:tld_length])` — **N labels total**.
  - In `ActionDispatch::Http::URL.extract_domain_from` (`url.rb:95-97`): `host.split(".").last(1 + tld_length)` — **N+1 labels**.

  So `tld_length: 2` as a cookie option yields `polymer.co` (2 labels), while `request.domain(2)` yields `app.polymer.co` (3 labels). Verified both.
- To make `domain: :all` correct everywhere here you need `tld_length: 2` — the actionpack docs even name this exact case: *"For example, to share cookies between user1.lvh.me and user2.lvh.me, set `:tld_length` to 2"* (`cookies.rb:169`).

### Explicit domain string

A String is emitted verbatim (`handle_options` has no String branch — `cookies.rb:437,468`). Verified: `domain: ".polymer.co"` → `domain=.polymer.co`; `domain: "polymer.co"` → `domain=polymer.co`.

### Recommendation for this question

Neither `domain: :all` nor a hardcoded string. Use **`domain: request.domain`** — it is the house idiom, it already produces the exact value wanted, and it is the same call the routing constraint that admitted the request just made.

`ActionDispatch::Request#domain` (`url.rb:329-331`) → `URL.extract_domain(host, 1)` → `host.split(".").last(2).join(".")` (`url.rb:95-97`):

| host | `request.domain` |
|---|---|
| `app.polymer.co` | `polymer.co` ✅ |
| `app-staging.polymer.co` | `polymer.co` |
| `www.polymer.co` | `polymer.co` |
| `app.lvh.me` | `lvh.me` ✅ |
| `lvh.me` | `lvh.me` ✅ |
| `app.wrk.xyz` | `wrk.xyz` |
| `app.localhost` | `app.localhost` ⚠️ (see Q6) |

No regex heuristic, no `tld_length` reasoning, correct on every host in `Variables::APP_DOMAIN_LIST` except `localhost`/`ngrok.io` (Q6, Q9).

---

## 3. The leading dot

**Rails/Rack emit whatever you give them, verbatim.** `rack-2.2.9/lib/rack/utils.rb:239`:

```ruby
domain = "; domain=#{value[:domain]}" if value[:domain]
```

No normalization, no dot insertion or removal. The only place a dot is *added* is the `domain: :all` branch, `cookies.rb:466`: `".#{cookie_domain}"`. So:
- `domain: :all` → `Domain=.polymer.co` (with dot)
- `domain: request.domain` → `Domain=polymer.co` (no dot)
- `domain: ".polymer.co"` → `Domain=.polymer.co`

**The handoff's worry — "setting it without the leading dot so it never reaches www" — is incorrect.** RFC 6265 §5.2.3 strips the leading dot before storing:

> "Let cookie-domain be the attribute-value without the leading %x2E (".") character."

The two forms are therefore stored identically. What actually decides subdomain reach is §5.3 step 6: if a Domain attribute is present *at all*, `host-only-flag` is set to **false**, and the cookie thereafter matches by §5.1.3 domain-matching:

> "The domain string is a suffix of the string, the last character of the string that is not included in the domain string is a %x2E (".") character, and the string is a host name."

`www.polymer.co` has `polymer.co` as a suffix, and the preceding character is `.` — so it domain-matches. **`Domain=polymer.co` does reach `www.polymer.co`.**

MDN states this outright:

> "Contrary to earlier specifications, leading dots in domain names (`.example.com`) are ignored."
> "if a domain _is_ specified, then subdomains are always included."

The real failure mode is the opposite one: **omitting `Domain` entirely** sets `host-only-flag` to true (RFC 6265 §5.3 step 6) and the cookie is confined to `app.polymer.co`. That is what today's two bare cookies do — `cookies[:account_referrer] = request.referrer` (`app/controllers/account/pages_controller.rb:5`) emits no `domain=` at all.

Sources: <https://datatracker.ietf.org/doc/html/rfc6265#section-5.2.3>, <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie>

---

## 4. `SameSite`

### Does SameSite gate the `document.cookie` read on `www.polymer.co`?

**No.** SameSite governs only whether a cookie is attached to outgoing *requests*. MDN:

> "Controls whether or not a cookie is sent with cross-site requests: that is, requests originating from a different site, including the scheme, from the site that set the cookie."

JavaScript access is gated by `HttpOnly`, not SameSite — which is why `httponly: false` is the requirement here.

### Cross-site vs cross-origin but same-site

`app.polymer.co` and `www.polymer.co` are:
- **different origins** — origin is scheme + full host + port, and the hosts differ;
- **the same site** — "site" is the registrable domain (eTLD+1), which is `polymer.co` for both.

MDN: *"`https://app.example.com` and `https://www.example.com` share the same registrable domain (`example.com`) … therefore, they are the same site."*

So a top-level navigation from the app to the marketing site is **same-site**, and even the strictest value (`SameSite=Strict`) would still send the cookie. SameSite is doubly irrelevant here: it does not gate the JS read, and the two hosts are same-site anyway.

Source: <https://developer.mozilla.org/en-US/docs/Glossary/Site>

### What this app defaults to

`config.action_dispatch.cookies_same_site_protection = :lax` is set **only under `load_defaults 6.1`** — `railties-6.1.7.7/lib/rails/application/configuration.rb:180`. This app is on `load_defaults 6.0` (`config/application.rb:52`).

Grepped for an explicit override: `grep -rn "cookies_same_site_protection" config/ app/ lib/` → **zero hits in the repo** (the only matches are inside the gem). `config/initializers/new_framework_defaults_6_0.rb` has every option commented out.

Confirmed empirically — a cookie written with no `same_site` option emits **no `SameSite` attribute**:
```
plain_demo=12345; domain=polymer.co; path=/
```

Modern browsers treat an absent SameSite as `Lax`, which is more than sufficient for a same-site read.

### Recommendation

**Pass nothing.** Adding `same_site: :lax` would be a no-op relative to browser default behavior; adding `same_site: :none` would be actively worse — MDN: *"The `Secure` attribute must also be set when using this value"* — which would make the cookie undeliverable in HTTP development (Q5).

---

## 5. `secure`

### Is development HTTP or HTTPS? — HTTP

- `config/environments/development.rb` has **no `force_ssl`**. `grep -rn "force_ssl\|ssl_options" config/` returns exactly one hit: `config/environments/production.rb:57` — `config.force_ssl = true`. No `config.ssl_options` anywhere.
- Dev server: `.foreman` → `procfile: Procfile.dev`; `Procfile.dev` → `web: bundle exec rails s` — plain Puma, no TLS.
- `cypress.config.ts:9` — `baseUrl: "http://app.lvh.me:5007"` (explicitly `http://`).

### What `secure: true` does over HTTP

Two independent failure layers:

1. **Rails suppresses the header entirely.** `cookies.rb:423-425`:
   ```ruby
   def write_cookie?(cookie)
     request.ssl? || !cookie[:secure] || always_write_cookie
   end
   ```
   Verified: `secure: true` over `http://app.polymer.co` produced `headers["Set-Cookie"] == nil` — no header at all.
   `always_write_cookie` is set to `Rails.env.development?` at `actionpack-6.1.7.7/lib/action_dispatch/railtie.rb:55-56`, so in development Rails *would* write it —
2. **but the browser then rejects it,** because a `Secure` cookie may not be set over plain `http://` on a non-`localhost` host such as `app.lvh.me`.

So `secure: true` in development means the cookie silently never exists.

### How the code should decide — `request.ssl?`

Not `Rails.env.production?`. `ActionDispatch::Request` includes `Rack::Request::Helpers` (`actionpack-6.1.7.7/lib/action_dispatch/http/request.rb:19`), and `ssl?` is proxy-aware:

- `rack-2.2.9/lib/rack/request.rb:350-352` — `def ssl?; scheme == 'https' || scheme == 'wss'; end`
- `rack-2.2.9/lib/rack/request.rb:210-220` — `scheme` honors `HTTPS=on`, `HTTP_X_FORWARDED_SSL=on`, then `forwarded_scheme`
- `rack-2.2.9/lib/rack/request.rb:636-639` — `forwarded_scheme` reads `HTTP_X_FORWARDED_SCHEME` and `HTTP_X_FORWARDED_PROTO`

Heroku's router terminates TLS and sets `X-Forwarded-Proto: https`, so `request.ssl?` is `true` in production and staging, `false` on `http://app.lvh.me:5007`. Verified end to end:

```
http://app.lvh.me:5007/   => "polymer_user_id=12345; domain=lvh.me; path=/; expires=...; "
https://app.polymer.co/   => "polymer_user_id=12345; domain=polymer.co; path=/; expires=...; secure"
```

`secure: request.ssl?` needs no per-environment branching and is correct on every deploy target including review apps and ngrok.

### Per-environment branching idioms that exist in `app/`

| Idiom | Count in `app/` | Shape |
|---|---|---|
| `Rails.env.production?` | **2** | `app/models/job.rb:1425`, `app/controllers/api/v1/registrations_controller.rb:166` — both `unless Rails.env.production?` guards around dev-only conveniences |
| `Rails.env.development?` | **53** | mostly `Rails.logger.info ... if Rails.env.development?` and ternaries for smaller page sizes / shorter expiries (e.g. `app/models/organization_data_export.rb:37` `expires_in = Rails.env.development? ? 10.minutes : 7.days`) |
| `Rails.env.test?` | **29** | test-env guards, e.g. `app/controllers/cypress/cleanup_controller.rb:7` `return head(:bad_request) unless Rails.env.test?` |

**`Rails.env.production?` is nearly unused (2 sites), and never for infrastructure configuration** — it appears only as a dev-affordance guard. Branching cookie security on it would be alien to the codebase.

### Config-driven idioms that exist

- **No `config/settings*.yml`** — `ls config/settings*` → nothing. There is no `config` gem / Settings object.
- **`Rails.application.config.x.*`**: exactly one key, `config/application.rb:82` — `config.x.RailsCredentialsEnv = Rails.env.test? ? :development : Rails.env.to_sym`. It exists solely to select a credentials branch.
- **The dominant idiom is `config/initializers/01_variables.rb`** — a `Variables` module of frozen constants, each `ENV['X'] || Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, ...)`, plus a few hardcoded ones (`MARKETING_BASE_URL = 'https://polymer.co'`, line 6) and per-environment lists (`APP_DOMAIN_LIST`, line 95).
- **`config/initializers/rack_attack.rb:15-24`** — `APP_HOSTNAME_LIST = case Variables::ServerEnv ... when 'development' / 'staging' / 'production'`. This is the closest thing to a per-environment host table, keyed on `Variables::ServerEnv` (`01_variables.rb:33`, `ENV['IS_STAGING'] ? 'staging' : Rails.env`).

**None of these needs to be touched.** `request.ssl?` and `request.domain` derive everything from the request.

---

## 6. How the app knows its own host

### Every mechanism found

| # | Mechanism | file:line | Development value | Production value |
|---|---|---|---|---|
| 1 | `request.domain` | `actionpack.../http/url.rb:329-331` | `lvh.me` (from `app.lvh.me`) | `polymer.co` (from `app.polymer.co`) |
| 2 | `request.host` | Rack | `app.lvh.me` | `app.polymer.co` |
| 3 | `request.subdomain` | `url.rb:345-347` | `app` | `app` |
| 4 | `Variables::APP_DOMAIN_LIST` | `config/initializers/01_variables.rb:95` | `['wrkhq.com','wrk.xyz','polymer.co','lvh.me','ngrok.io','localhost']` (same both envs) | same |
| 5 | `config.action_mailer.default_url_options` | `config/environments/development.rb:82` / `production.rb:79` | `{ host: 'localhost', port: 5007 }` | `{ host: 'hire.polymer.co' }` |
| 6 | `Variables::AtsRootUrl` / `APP_ROOT_URL` | `01_variables.rb:19-20` | `HEROKU_REVIEW_APP_URL \|\| ENV['NGROK_URL'] \|\| ENV['STAGING_ATS_ROOT_URL'] \|\| credentials[:ats_root_url]` | same expression, prod credentials |
| 7 | `Variables::MARKETING_BASE_URL` | `01_variables.rb:6` | `'https://polymer.co'` (hardcoded, both envs) | same |
| 8 | `config.hosts` | `development.rb:110-116`, `test.rb:67-74` | `lvh.me`, `app.lvh.me`, `api.lvh.me`, `individual.lvh.me`, `jobs.lvh.me`, `/[a-z0-9-]+\.ngrok\.io/` | not set (prod does not use HostAuthorization) |
| 9 | `APP_HOSTNAME_LIST` | `config/initializers/rack_attack.rb:15-24` | `['app.lvh.me','app.ngrok.io','api.lvh.me']` | `['app.polymer.co','app.wrk.xyz','hire.wrk.xyz','app.wrkhq.com','hire.wrkhq.com','api.polymer.co','api.wrk.xyz','api.wrkhq.com']` |
| 10 | `Variables::HEROKU_REVIEW_APP_URL` | `01_variables.rb:5` | `nil` locally | `"#{ENV['HEROKU_APP_NAME']}.herokuapp.com"` on review apps |

Notes:
- `config.action_controller.default_url_options` — **not set anywhere**. `grep -rn "default_url_options" config/ app/ lib/` returns only the two `action_mailer` lines plus a commented `# config.default_url_options` at `development.rb:83`. No `default_url_options` method on any controller or helper.
- `.env.example` does not exist — only `.env`. The only host-ish keys present are `DOMAIN` and `PORT`, and **neither is referenced anywhere in `app/`, `config/`, `lib/`, or `bin/`** (`grep -rn "ENV\['DOMAIN'\]\|ENV\['PORT'\]"` → zero hits). They are inert.

### Ranking for producing `.lvh.me` in dev and `.polymer.co` in production

1. **`request.domain`** — correct on both, zero new config, and it is *already the house idiom for exactly this question*: `SubdomainAppConstraints.matches?` (`app/services/subdomain_app_constraints.rb:7`) gates every authenticated route on `Variables::APP_DOMAIN_LIST.include?(request.domain)`. By the time the controller runs, `request.domain` has already been validated as a known app domain. Same pattern at `subdomain_hire_constraints.rb:9`, `subdomain_api_constraints.rb:7`, `subdomain_individual_constraints.rb:7`, `subdomain_jobs_constraints.rb:7`, `job_board/base_controller.rb:12,37`, `recaptcha/verifier.rb:59`.
2. **`domain: :all, tld_length: 2`** — also correct on both, but relies on a fragile regex heuristic and a `tld_length` whose meaning differs from `request.domain(2)`. Strictly more surprising for the same result.
3. `APP_HOSTNAME_LIST` (rack_attack) — correct per env but is a list of full hosts, needing a `.split('.').last(2)` on top; also lives in an initializer unrelated to this feature.
4. `action_mailer.default_url_options` — **wrong values**. Dev says `localhost`, production says `hire.polymer.co`. Deriving from these gives `localhost` in dev, which yields no cookie at all.
5. `MARKETING_BASE_URL` — hardcoded `https://polymer.co` in both envs; would give `.polymer.co` in development, where no such host exists.
6. `AtsRootUrl` — credentials-backed, unset locally without env vars; not dependable in dev.

### `request.domain` / `extract_domain` reference table

`URL.extract_domain(host, tld_length)` → `extract_domain_from` → `host.split(".").last(1 + tld_length).join(".")` (`url.rb:22-24, 95-97`), guarded by `named_host?` = `!IP_HOST_REGEXP.match?(host)` (`url.rb:136-138`). Default `tld_length` is `1` (`url.rb:13`).

| host | tld_length 1 (default) | tld_length 2 |
|---|---|---|
| `app.polymer.co` | `"polymer.co"` | `"app.polymer.co"` |
| `www.polymer.co` | `"polymer.co"` | *(would be `"www.polymer.co"`)* |
| `lvh.me` | `"lvh.me"` | `"lvh.me"` |
| `app.lvh.me` | `"lvh.me"` | `"app.lvh.me"` |
| `localhost` | `"localhost"` | `"localhost"` |
| `app.localhost` | `"app.localhost"` | `"app.localhost"` |
| `127.0.0.1` | `nil` | `nil` |

All rows executed against the installed gem.

Also confirmed: `request.host` **excludes the port** — for `http://lvh.me:5007/`, `host == "lvh.me"`, `host_with_port == "lvh.me:5007"`. Port never contaminates the domain.

⚠️ **`localhost` caveat.** If anyone reaches the app at `http://app.localhost:5007`, `request.domain` returns `"app.localhost"` (not `"localhost"`) because `extract_domain_from` blindly takes the last two labels. The cookie would be scoped to `app.localhost` and invisible elsewhere. Harmless (there is no marketing site on localhost), and `app.localhost` is not in `config.hosts` for development anyway (`development.rb:110-116` lists only `*.lvh.me` and ngrok), so it is unreachable. Noted for completeness.

---

## 7. Expiry

### Mechanism

`expires:` is the right knob; `max_age:` is a Rack-only passthrough (`utils.rb:241`) that Rails never touches and that nothing in this codebase uses. `expires:` accepts an absolute `Time` or an `ActiveSupport::Duration` — `cookies.rb:428-430` calls `.from_now` on anything that responds to it. Rack writes `expires=<httpdate>` (`utils.rb:242`).

### If `expires:` is omitted

Confirmed from source and by execution: the attribute is simply absent —

```
polymer_user_id=12345; domain=.polymer.co; path=/
```

`utils.rb:242` is `expires = "; expires=#{value[:expires].httpdate}" if value[:expires]`. A cookie with neither `Expires` nor `Max-Age` is a **session cookie — gone when the browser session ends.** That defeats the purpose, so `expires:` must be passed.

### What value

- Devise remember-me is **`config.remember_for = 2.years`** — `config/initializers/devise.rb:171`. Verified as stated.
- `cookies.permanent` sets `20.years.from_now` (`cookies.rb:530-534`). Verified: `expires=Mon, 30 Jul 2046`.

`2.years` matches the longest-lived credential the app already issues and means the cookie outlives any session the user could still be signed in from. `1.year` is also defensible. `cookies.permanent`'s 20 years is longer than any browser will honor in practice (Chrome caps cookie lifetime at 400 days) and is not used anywhere in this codebase — no `cookies.permanent`, `cookies.signed`, or `cookies.encrypted` call exists in `app/` or `lib/`.

**Recommendation: `expires: 2.years.from_now`,** matching `remember_for`. Note that because the cookie is rewritten on every authenticated page load, the expiry is continuously refreshed — the practical lifetime is "2 years after the user's last visit," which is the desired behavior for a retargeting exclusion.

---

## 8. Cookie name — everything in play

### What Rails emits for the two existing cookies

`cookies[:account_referrer]` (`app/controllers/account/pages_controller.rb:5`) and `cookies[:connect_referrer]` (`app/controllers/connect/pages_controller.rb:7`). The jar stringifies the key (`cookies.rb:361` `@cookies[name.to_s] = value`) and Rack escapes it (`cookies.rb:406-408` → `Rack::Utils.escape`). Neither name contains escapable characters, so the wire names are literally:

```
account_referrer=<url-encoded referrer>; path=/
connect_referrer=<url-encoded referrer>; path=/
```

No `domain`, no `expires`, no flags — both are host-only session cookies today.

### Full inventory of cookie names in play

| Name | Source | file:line |
|---|---|---|
| `account_referrer` | app, plain jar | `app/controllers/account/pages_controller.rb:5` |
| `connect_referrer` | app, plain jar | `app/controllers/connect/pages_controller.rb:7` |
| `_inflow_ats_session` | Rails session store (default; derived) | `railties-6.1.7.7/lib/rails/application/finisher.rb:100-104` + `config/application.rb:48` |
| `remember_api_v1_user_token` | Devise `:rememberable` | `config/initializers/devise.rb:171`; Devise 4.8.1 names it `remember_#{scope}_token` |

**There is no `config/initializers/session_store.rb`** — the file does not exist, and `grep -rn "session_store\|cookie_store" config/ app/ lib/` returns zero repo hits. So the key comes from the Rails default at `finisher.rb:100-104`:

```ruby
initializer :setup_default_session_store, before: :build_middleware_stack do |app|
  unless app.config.session_store?
    app_name = app.class.name ? app.railtie_name.chomp("_application") : ""
    app.config.session_store :cookie_store, key: "_#{app_name}_session"
  end
end
```

With `module InflowATS` (`config/application.rb:48`), `railtie_name` underscores to `inflow_ats_application`, chomped to `inflow_ats` → **`_inflow_ats_session`**. (Derived from the gem source; not executed, since booting the app would require the database.)

**CSRF** does not use a cookie in this app — `protect_from_forgery with: :null_session` (`app/controllers/application_controller.rb:8`); the token rides in the session, not a separate cookie.

**Frontend-set cookies: none.** `grep -rn "document.cookie" app/javascript/` returns exactly two hits, **both reads**:
- `app/javascript/shared/hooks/useCookieValue.ts:7` — `document.cookie.split("; ")`, used only by `useReferrerCookie.ts` to read `account_referrer`/`connect_referrer`
- `app/javascript/shared/lib/utils.js:41` — `document.cookie.split("; ").forEach(...)`

No `js-cookie` dependency, no `Cookies.set`, no assignment to `document.cookie` anywhere.

### `__Host-` / `__Secure-` prefixes

`grep -rn "__Host-\|__Secure-" app/ config/ lib/ spec/ cypress/` → **zero hits.** None are in play. Correctly so: MDN confirms `__Host-` **"must not have a `Domain` attribute specified"**, which is fundamentally incompatible with a cross-subdomain cookie. `__Secure-` permits `Domain` but requires `Secure`, which would break HTTP development. **Neither prefix should be used.**

### Naming recommendation

The house convention is snake_case, no prefix, named for what it holds. Both existing names are `<context>_<thing>`. `polymer_user_id` collides with nothing above and reads correctly from the marketing site's perspective (where "polymer" disambiguates from any other cookie on `polymer.co`). `app_user_id` or `polymer_uid` are equally fine. This is a free choice — flagged as an open question below since it becomes a contract with the marketing site.

---

## 9. What else runs under `*.polymer.co`

**Hosts with evidence in this repo.** This list is derived only from strings in the codebase and **may be incomplete** — DNS records not referenced in code are invisible here.

| Hostname | Evidence (file:line) | What it is |
|---|---|---|
| `polymer.co` | `config/initializers/01_variables.rb:6` (`MARKETING_BASE_URL`); `config/routes.rb:704` (`root to: redirect('https://polymer.co')`) | marketing site apex |
| `www.polymer.co` | `app/views/job_board/partials/_footer.html.erb:4`; `app/javascript/job_board/src/components/shared/Footer/index.js:14` | marketing site www — **the read target** |
| `app.polymer.co` | `config/initializers/rack_attack.rb:20` (production `APP_HOSTNAME_LIST`); `README.md:48,91` | the hire app — **the write origin** |
| `api.polymer.co` | `config/initializers/rack_attack.rb:20`; `config/routes.rb:472` | public API |
| `jobs.polymer.co` | `README.md:49`; `app/javascript/ats/src/views/accountAdmin/accountJobBoard/AccountJobBoardNavigation.tsx:181`; `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx:134-135` | customer job boards (public, unauthenticated) |
| `hire.polymer.co` | `config/environments/production.rb:79` (mailer host); `app/models/concerns/videoable.rb:21`; `app/controllers/api_public/v1/hire/jobs_controller.rb:99,121` | legacy/alias hire host |
| `help.polymer.co` | `app/javascript/shared/components/PolymerBar.tsx:137`; `app/javascript/ats/src/components/shared/UserNav.tsx:44` | Intercom-hosted help centre (third party) |
| `developer.polymer.co` | `app/javascript/ats/src/views/accountAdmin/AccountApiKeys.tsx:161` | API docs (third party) |
| `mail.polymer.co` | `app/mailers/custom_devise_mailer.rb:25`; `01_variables.rb:8-11` | Mailgun sending domain (MX/SMTP, not a web host) |
| `individual.polymer.co` | `config/routes.rb:669` (comment) | individual app |
| `app-staging.polymer.co` | `config/initializers/rack_attack.rb:19` | staging app |
| `app-develop.polymer.co` | `config/initializers/rack_attack.rb:19`; `app/controllers/api/v1/public/jobs_controller.rb:109` | develop app |
| `api-staging.polymer.co` | `config/initializers/rack_attack.rb:19` | staging API |
| `api-develop.polymer.co` | `config/initializers/rack_attack.rb:19`; `app/controllers/api_public/v1/hire/jobs_controller.rb:97` | develop API |
| `hire-staging.polymer.co` | `README.md:55`; `app/controllers/api/v1/public/webhooks_controller.rb:9` | staging hire host |

**Implications of the blast radius:**
- The cookie will be attached to every request to all of the above, including **`help.polymer.co` and `developer.polymer.co`, which are third-party-hosted**. The value is a user ID that already leaves the app as PostHog's `distinct_id` (`app/services/posthog/identify.rb:12`), so exposure is low, but it is a real widening.
- **`jobs.polymer.co` is public and unauthenticated** — job-board visitors who are also Polymer customers will send their user ID on every job-board request.
- **Staging and develop write to the same `.polymer.co` cookie.** `request.domain` on `app-staging.polymer.co` is `polymer.co`, identical to production. A user who visits staging gets a `polymer_user_id` cookie holding their *staging-database* user ID, which will silently overwrite the production one and mean something different on the marketing site. Flagged as an open question.
- Two other registrable domains are live per `rack_attack.rb:20` — `wrk.xyz` and `wrkhq.com`. `request.domain` handles them automatically (`app.wrk.xyz` → `wrk.xyz`), producing a correctly-scoped cookie on each; there is no marketing site there, so the cookie is simply unused.

---

## 10. CSP / CORS

### CSP — none in force

`config/initializers/content_security_policy.rb` exists but **every line is commented out** — the `Rails.application.config.content_security_policy do |policy| ... end` block, the nonce generator, and the report-only setting. No `Content-Security-Policy` header is emitted from Rails config, and `grep -rn "content_security_policy" config/ app/` finds no other configuration. **Nothing in CSP constrains this feature** — and CSP has no cookie directives regardless.

### CORS — irrelevant to this feature

`config/application.rb:89-98` (`rack-cors` 1.0.2, `Gemfile:87`):

```ruby
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '/v1/hire/*', headers: :any, methods: [:get]
    resource '/api/v1/public/*', headers: :any, methods: [:get, :put, :post]
    resource '/rails/active_storage/disk/*', headers: :any, methods: [:get, :put, :post]
  end
end
```

Three public, unauthenticated resource paths with `origins '*'` and no `credentials: true`. CORS governs cross-origin **XHR/fetch**; it has nothing to do with `Set-Cookie` scoping or `document.cookie` reads on a page the browser loaded from `www.polymer.co`. **The marketing site does not appear in any allowlist, and does not need to** — the plan is a local `document.cookie` read, not a network call to the app.

(`config/webpacker.yml:54,87` set `"Access-Control-Allow-Origin": "*"` for the dev-server assets only.)

---

## 11. Signed vs plain cookie jar

**Only the plain jar produces a JS-readable value.** Confirmed by running all three jars against the same value `"12345"` on `app.polymer.co`:

```
PLAIN:     plain_demo=12345; domain=polymer.co; path=/
SIGNED:    signed_demo=IjEyMzQ1Ig%3D%3D--8ab66da40313bc2c778727a4d0da50b07b062ec9; domain=polymer.co; path=/
ENCRYPTED: enc_demo=bSb%2F%2F8QtEw%3D%3D--l%2BjS2frjXh31YRas--gaKtzUWR%2B3DJj01jyPeRDA%3D%3D; domain=polymer.co; path=/
```

- **Signed** — `<base64(JSON value)>--<HMAC-SHA1 hex>`. `document.cookie` on `www.polymer.co` would see `IjEyMzQ1Ig%3D%3D--8ab66da...`. The marketing site would have to URL-decode, split on `--`, base64-decode, and JSON-parse just to recover `12345`, and could not verify the signature without `secret_key_base`. The digest is `SHA1` here (`cookies.rb:283-285`, no `cookies_digest` configured) and the serializer is `:json` (`config/initializers/cookies_serializer.rb`).
- **Encrypted** — AES-256-GCM ciphertext (`cookies.rb:275-277`). Opaque; recovering the value off-domain is impossible by design.
- **Plain** — `CookieJar#[]=` stores the value verbatim (`cookies.rb:349-367`) and `Rack::Utils.add_cookie_to_header` writes it after `Rack::Utils.escape` (`cookies.rb:406-408`). A numeric user ID has no escapable characters, so `document.cookie` yields the digits directly.

Use **`cookies[...]`** — the plain jar. This also matches the only cookie idiom the codebase has (`account_referrer`, `connect_referrer`), and no `cookies.signed`/`.encrypted`/`.permanent` call exists anywhere in `app/` or `lib/`.

**Tamper note:** a plain cookie is user-editable, so the value is an *unverified hint*. That is correct for the stated purpose — excluding a visitor from retargeting is a decision no one gains from forging, and a signed value would be unreadable anyway. Worth stating explicitly in the spec so nobody later treats it as an identity assertion.

---

## The concrete recommendation

```ruby
cookies[:polymer_user_id] = {
  value: current_user.id.to_s,
  domain: request.domain,
  expires: 2.years.from_now,
  httponly: false,
  secure: request.ssl?
}
```

Verified output of exactly this hash, run against the installed gem:

| Request | `Set-Cookie` |
|---|---|
| `http://app.lvh.me:5007/` (dev) | `polymer_user_id=12345; domain=lvh.me; path=/; expires=Fri, 30 Jul 2027 …` |
| `https://app.polymer.co/` (prod) | `polymer_user_id=12345; domain=polymer.co; path=/; expires=Fri, 30 Jul 2027 …; secure` |

### Each option justified

| Option | Why |
|---|---|
| **plain `cookies[...]`** jar | only jar whose value is legible to `document.cookie` — signed emits `IjEyMzQ1Ig%3D%3D--8ab66da…` (Q11). Matches the codebase's only cookie idiom (`account/pages_controller.rb:5`, `connect/pages_controller.rb:7`) |
| `value: current_user.id.to_s` | matches PostHog's `distinct_id` (`app/services/posthog/identify.rb:12` — `distinct_id: @user.id.to_s`) |
| `domain: request.domain` | `url.rb:329-331` → `extract_domain(host, 1)` → `last(2)` labels (`url.rb:95-97`). Yields `polymer.co` from `app.polymer.co` and `lvh.me` from `app.lvh.me`. Already the house idiom — `subdomain_app_constraints.rb:7` validated `APP_DOMAIN_LIST.include?(request.domain)` before the request reached the controller |
| `expires: 2.years.from_now` | without it the cookie is a session cookie and dies on browser close (`utils.rb:242`, verified). `2.years` mirrors `config.remember_for = 2.years` (`config/initializers/devise.rb:171`) |
| `httponly: false` | required for the `document.cookie` read (MDN: `HttpOnly` is what blocks JS access). **Already the default** — `utils.rb:244` omits the attribute when the key is absent — so this is explicit documentation guarding against a future "security fix" |
| `secure: request.ssl?` | `secure: true` over HTTP means no cookie at all: Rails suppresses the header (`cookies.rb:423-425`) and the browser would reject it anyway. `Rack::Request::Helpers#ssl?` (`request.rb:350-352`) reads `X-Forwarded-Proto` via `forwarded_scheme` (`request.rb:636-639`), so it is `true` behind Heroku's TLS-terminating router (`production.rb:57` `force_ssl = true`) and `false` on `http://app.lvh.me:5007` |
| *(no `same_site`)* | the app is on `load_defaults 6.0` (`config/application.rb:52`), so `cookies_same_site_protection` is unset (it arrives only with 6.1 — `railties …/configuration.rb:180`) and no attribute is emitted. Irrelevant regardless: SameSite gates request-sending, not `document.cookie` reads, and `app.polymer.co`/`www.polymer.co` are same-site (shared registrable domain `polymer.co`) |
| *(no `path`)* | defaults to `"/"` (`cookies.rb:432`) |
| *(no `tld_length`)* | only consulted under `domain: :all` (`cookies.rb:449`) |

### Dev vs production difference, and how the code decides

**There is no environment branch.** Both varying options derive from the request:
- `request.domain` → `lvh.me` locally, `polymer.co` in production/staging
- `request.ssl?` → `false` locally, `true` behind Heroku

This is deliberate. `Rails.env.production?` appears only **twice** in all of `app/` (`app/models/job.rb:1425`, `app/controllers/api/v1/registrations_controller.rb:166`), both as dev-affordance guards, never for infrastructure config — branching on it here would be alien to the codebase and would also break staging, review apps, and ngrok.

### Alternatives rejected

| Rejected | Why |
|---|---|
| **`domain: :all`** | **Breaks development.** On `app.lvh.me` the regex at `cookies.rb:457` (`/\.[^.]{2,3}\.[^.]{2}\z/`) matches `.lvh.me`, so actionpack treats `lvh.me` as a two-label TLD, takes `last(3)`, and emits `Domain=.app.lvh.me`. Verified. Fails silently — the local cookie simply never reaches a sibling subdomain |
| `domain: :all, tld_length: 2` | Functionally correct on every host here (verified), but leans on a fragile TLD regex and a `tld_length` that means "N labels" (`cookies.rb:452`) while `request.domain(2)` means "N+1 labels" (`url.rb:96`). Same result as `request.domain` with more surprise |
| Hardcoded `domain: '.polymer.co'` | wrong in development; would need the env branch that `request.domain` avoids |
| `domain: '.polymer.co'` (leading dot) over the bare form | no behavioral difference — RFC 6265 §5.2.3 strips the leading dot; MDN: *"leading dots in domain names are ignored."* The handoff's worry that a dotless `Domain` "never reaches www" is **incorrect**; what confines a cookie is omitting `Domain` entirely (RFC 6265 §5.3 step 6 sets `host-only-flag`) |
| `same_site: :none` | would require `Secure` (MDN), making the cookie undeliverable in HTTP development, to solve a problem that does not exist |
| `same_site: :strict` | harmless but pointless — the two hosts are same-site |
| `cookies.signed[...]` / `cookies.encrypted[...]` | value unreadable from the marketing site (Q11) |
| `cookies.permanent[...]` | forces `20.years` (`cookies.rb:530-534`), longer than browsers honor (Chrome caps at 400 days), and no `cookies.permanent` call exists in this codebase |
| `__Host-` / `__Secure-` name prefixes | `__Host-` forbids `Domain` outright (MDN), which is the entire point of this cookie; `__Secure-` requires `Secure`, breaking dev. Neither prefix is used anywhere in the repo |
| `max_age:` instead of `expires:` | Rack-only passthrough (`utils.rb:241`); Rails does not process it and the codebase never uses it |
| Deriving from `action_mailer.default_url_options` | dev value is `localhost` (`development.rb:82`), which yields no usable cookie domain |
| Deriving from `Variables::MARKETING_BASE_URL` | hardcoded `https://polymer.co` in both envs (`01_variables.rb:6`) — would emit `polymer.co` in development |
| Adding new env/config for the domain | unnecessary; `request.domain` is already the validated house mechanism (`subdomain_app_constraints.rb:7`) |

---

## Open questions

1. **Cookie name.** `polymer_user_id` is proposed and collides with nothing (`account_referrer`, `connect_referrer`, `_inflow_ats_session`, `remember_api_v1_user_token`). But the name is a contract with the marketing site's JS, so it should be Jessica's call and agreed with whoever writes the `www.polymer.co` reader.

2. **Staging and develop write to the same `.polymer.co` cookie as production.** `request.domain` on `app-staging.polymer.co` and `app-develop.polymer.co` is `polymer.co` (`config/initializers/rack_attack.rb:19`). A staging visit overwrites the production cookie with a staging-database user ID, which means something different on the marketing site. Options: accept it (staging traffic is internal and small); suppress the write unless `Variables::ServerEnv == 'production'`; or namespace the value. Not decidable from the code.

3. **`jobs.polymer.co` and third-party hosts receive the cookie.** Any `Domain=polymer.co` cookie is sent to every `*.polymer.co` host, including the public unauthenticated job boards and the Intercom-hosted `help.polymer.co` / `developer.polymer.co`. The value is an ID that already reaches PostHog, so the exposure is minor — but it is a widening and should be an explicit accept.

4. **Where exactly to write it.** The brief says "every authenticated app load." All authenticated app routes live under `constraints SubdomainAppConstraints` (`config/routes.rb:541`) and render `pages#root` (`config/routes.rb:568`). The natural placement is a `before_action` on the controller serving that route, guarded on the user being signed in. Whether that belongs on `Hire::BaseController` (currently 3 lines — `app/controllers/hire/base_controller.rb`), on `ApplicationController`, or only on the `pages#root` action determines whether the cookie is also written on `Account::` and `Connect::` loads, and on the unauthenticated `/hire/auth` pages. Not specified in the brief.

5. **Whether an ngrok dev session matters.** `Variables::APP_DOMAIN_LIST` includes `ngrok.io` (`01_variables.rb:95`) and `rack_attack.rb:17` lists `app.ngrok.io`. `request.domain` on `foo.ngrok.io` returns `ngrok.io`, which is on the Public Suffix List — browsers **reject** a `Domain=ngrok.io` cookie outright. The cookie would silently not be set during ngrok sessions. Harmless if nobody tests this feature over ngrok; worth knowing before someone debugs it there.
