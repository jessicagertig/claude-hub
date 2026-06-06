# Navigation Map -- Layer 5 Playwright, qa-run-5

## Auth Flow (applies to all agents)

1. Navigate to `http://app.lvh.me:5007/auth`
2. Fill `input[name="email"]` with the user's email
3. Click `button:has-text("Continue with email")`
4. Wait for the dev workaround div; click `a[href*='magic_links/validate']`
5. Login completes when redirected to `/jobs` (jobs list page)

**Default admin user:** `rezu.may@wrkhq.com` (Rezu May, admin, Acme Inc.)
**Non-admin member:** `taylor.brooks@wrkhq.com` (Taylor Brooks, member role)

---

## Starting Point: Jobs List

After login, you land on `/jobs`. This is the root for all navigation paths.

**Landmarks on jobs list:**
- Top bar: org switcher (left), search bar (center), notification bell + gear icon (right)
- Gear icon links to `/hire/settings/organization` -- this is how you reach App Settings
- Job cards show job title, category, candidates counts
- Click a job title (e.g., `h2:has-text("AI Summary Test Job")`) to open that job

---

## Path 1: Plato AI Container (Settings tab -- default)

```
Jobs list
  -> Click gear icon: a[href='/hire/settings/organization']
  -> Lands on App Settings sidebar
  -> Click "Plato AI" in sidebar: a[href='/hire/settings/plato-ai']
  -> Auto-redirects to /hire/settings/plato-ai/settings
  -> Lands on: AI Settings tab (two-column: sub-nav left, content right)
```

**What you see on Settings tab:**
- Sub-nav sidebar: Settings (active), Billing, Usage
- Content: "AI settings" heading
  - "Auto-generate summaries" section with checkbox
  - "Hiring team credit control" section with checkbox
  - "Notifications" section with two checkboxes (low credits, zero credits)
  - "Save changes" button

---

## Path 2: Plato AI Billing tab

```
(From Plato AI Settings tab)
  -> Click "Billing" in sub-nav: a[href='/hire/settings/plato-ai/billing']
  -> Lands on Billing tab content
```

**What you see on Billing tab:**
- Credit balance display (Monthly / Purchased / Total)
- Subscribe button (for credit pack subscriptions)
- Top-up button (for one-off credit packs)

---

## Path 3: Plato AI Usage tab

```
(From Plato AI Settings or Billing tab)
  -> Click "Usage" in sub-nav: a[href='/hire/settings/plato-ai/usage']
  -> Lands on Usage tab content
```

**What you see on Usage tab:**
- Credit balance display
- "Usage this period" bar
- Reset date information

---

## Path 4: Non-admin access to Plato AI (admin-only gate)

```
Jobs list (logged in as taylor.brooks@wrkhq.com)
  -> Click gear icon: a[href='/hire/settings/organization']
  -> Lands on App Settings sidebar
  -> Verify: "Plato AI" link is NOT present in sidebar
  -> Non-admin sidebar should show: User preferences, Message templates, Review templates
  -> No AI-related links should be visible
```

---

## Path 5: Job Setup AI Settings

```
Jobs list (logged in as rezu.may@wrkhq.com)
  -> Click job title: h2:has-text("AI Summary Test Job")
  -> Lands on candidates view (/jobs/{id}/stages/{stage_id}/applicants/...)
  -> Click "Job setup" in left column: a[href*='/setup']
  -> Lands on Job setup (/jobs/{id}/setup/details)
  -> In setup sidebar (column 2), click "AI settings": a[href*='/setup/ai']
  -> Lands on Job AI Settings page
```

**What you see on Job AI Settings:**
- Dropdown for auto-generate AI summaries with values: "Use organization default" (default), "Enabled", "Disabled"
- Save changes button

---

## Path 6: Plan & Billing page (check for stale AI billing link)

```
Jobs list
  -> Click gear icon: a[href='/hire/settings/organization']
  -> Click "Plan & billing" in sidebar: a[href='/hire/settings/billing']
  -> Lands on Plan & billing page
  -> Look for any "go to AI billing" link -- should point to /hire/settings/plato-ai/billing (NOT the old /hire/settings/ai-billing)
```

---

## Path 7: Old AI routes (should show empty content or redirect)

The following old routes were removed by this feature. They should NOT render AI content:
- `/hire/settings/ai`
- `/hire/settings/ai-billing`
- `/hire/settings/ai-usage`

To test: navigate to settings sidebar, verify these paths are NOT linked. If navigated to directly, they should show empty content area (no redirect, just no content).

---

## Verified Selectors

| Element | Selector | Notes |
|---------|----------|-------|
| Gear icon (app settings) | `a[href='/hire/settings/organization']` | Top bar, right side |
| Plato AI sidebar link | `a[href='/hire/settings/plato-ai']` | In settings sidebar, admin only |
| Settings sub-tab | `a[href='/hire/settings/plato-ai/settings']` | Inside Plato AI container |
| Billing sub-tab | `a[href='/hire/settings/plato-ai/billing']` | Inside Plato AI container |
| Usage sub-tab | `a[href='/hire/settings/plato-ai/usage']` | Inside Plato AI container |
| Job title | `h2:has-text("AI Summary Test Job")` | On jobs list |
| Job setup link | `a[href*='/setup']` | In job page left column |
| AI settings (job) | `a[href*='/setup/ai']` | In job setup sidebar |
| Plan & billing | `a[href='/hire/settings/billing']` | In settings sidebar |
| Email input (auth) | `input[name='email']` | Auth page |
| Continue with email | `button:has-text("Continue with email")` | Auth page |
| Magic link | `a[href*='magic_links/validate']` | Dev workaround on verify page |
