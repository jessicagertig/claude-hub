# Spec review round 4 — findings not applied

One finding was not applied. Its central codebase claim is false.

## 1. HIGH — "`app/models/job.rb` does NOT require `googleauth`"

**The finding claimed:** SPEC.md's `require 'googleauth'` justification is wrong on both halves. Its evidence
was "app/models/job.rb:5-6 (`require 'csv'`, `require 'money'` — no `googleauth`)" and that `Google::Auth`
resolves in `job.rb` only because `gem 'google-api-client', '0.53.0'` (Gemfile:114) is loaded by
`Bundler.require` and pulls `googleauth` in transitively. It proposed rewriting the cell to say
`app/services/engagement_report/google_sheets_sender.rb` is "the one place in the application that requires
the gem explicitly."

**Refuting evidence:**

- `app/models/job.rb:1420` — `require 'googleauth'`, immediately below `app/models/job.rb:1419`
  `require 'google/apis/indexing_v3'`. Both are inline requires inside the class body, four lines above
  `def ping_google_index` (`app/models/job.rb:1424`), not at the top of the file. The finding read only the
  file header and concluded from lines 5-6 that no other require exists.
- `grep -rn "googleauth\|Google::Auth" app/ lib/ config/ --include=*.rb` returns exactly four lines:
  `app/models/job.rb:1420`, `app/models/job.rb:1435`,
  `app/services/engagement_report/google_sheets_sender.rb:4` and
  `app/services/engagement_report/google_sheets_sender.rb:116`. Two files reference `Google::Auth`; both
  require the gem explicitly. SPEC.md's sentence is exactly right.

**The second half of the finding is also unsupported.** `Gemfile.lock:644` lists `google-api-client (= 0.53.0)`
under `DEPENDENCIES`; `googleauth (1.8.1)` appears only at `Gemfile.lock:220` as a resolved gem and at
`Gemfile.lock:206` as a `google-api-client` runtime dependency. `Bundler.require(*Rails.groups)`
(`config/application.rb:41`) requires the gems named in the Gemfile — `google-api-client`, never `googleauth`.
SPEC.md's clause "`googleauth` arrives as a transitive dependency and is not required by `Bundler.require`"
is accurate as written.

Applying the proposed fix would have replaced a true sentence with a false one, deleting a correct precedent
(`app/models/job.rb`) and asserting a `Bundler.require` behavior the lockfile contradicts.
