# UI Preference Section -- Round 4

## Findings

### Component pattern match (re-verified)

Existing pattern (lines 119-155):
```
FormSection title="Notifications"
  FormFieldset legend="Emails" description="..."
    FormCheckbox name="emailJobApplicationsNew" ...
    FormCheckbox name="emailCommentsNew" ...
    FormCheckbox name="emailMessagesNew" ...
```

New section (lines 156-168):
```
FormSection title="Weekly digest"
  FormFieldset legend="Email" description="..."
    FormCheckbox name="emailWeeklyDigest" ...
```

Same component hierarchy, same prop shapes, same save handler. CORRECT.

### State initialization

`useState<UserSettings>({ ...meResponse.settings } || {})` at line 25. If `meResponse.settings` includes `emailWeeklyDigest` (which it will after the data migration), the state includes the key. The `useEffect` at lines 40-43 also syncs state when `meResponse` changes. The checkbox at line 164 reads `checked={emailWeeklyDigest}` from the destructured settings. CORRECT.

### Destructuring safety

Line 27: `const { emailCommentsNew, emailMessagesNew, emailJobApplicationsNew, emailWeeklyDigest } = settings;`

If `emailWeeklyDigest` is not in `settings` (e.g., org_user created before migration and migration hasn't run), it destructures as `undefined`. `FormCheckbox checked={undefined}` -- React treats `undefined` as `false` for a controlled checkbox. The checkbox renders unchecked. When the user saves, the `settings` state includes `emailWeeklyDigest: undefined`, and `handleSubmitForm` sends it. The backend `settings_params` permits it, and `update(settings: temp_params)` writes it. The value would be `nil` in JSONB which is `false`-ish for the `@>` containment check. This is the correct degradation path -- the same as existing keys before their data migrations ran. Not a finding.

### Form submission

The `FormContainer` at line 114 has `id="preferences-form"`. The submit `Button` at line 96-103 has `form="preferences-form"`. All checkboxes (including the new one) are inside this form. The new section is inside `FormContainer`, so submitting the form includes the new checkbox state. CORRECT.

No issues found.
