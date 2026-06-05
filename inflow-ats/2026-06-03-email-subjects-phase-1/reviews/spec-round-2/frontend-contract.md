# Frontend Contract -- Round 2

## Findings

Round 2 deepened verification on API payload shapes and hook behavior.

### Mutation payload shape
`useCreateChannelMessage` calls `apiPost({ path, variables })`. The `variables` object is the mutation's input, which the frontend component constructs. Looking at the controller, `channel_message_params` will permit `:subject`, so the frontend must include `subject` in the `variables` passed to the mutation. The hook itself is generic and doesn't filter keys -- whatever the component passes flows through. No hook change needed, only component changes. Consistent with spec.

### useMailMerge response consumption
`useMailMerge` returns the raw JSON response from the mail-merge controller. Currently that's `{ message_raw, message_html, template_html, has_invalid_tags, invalid_tags }`. After phase 1, new keys will be added (subject variants). The frontend template selection modal needs to destructure the new keys. Since the hook returns the full response object, no hook change is needed -- only the component that reads the data. Consistent with spec.

### Template create/update hooks
`useCreateChannelMessageTemplate` and `useUpdateChannelMessageTemplate` call `apiPost`/`apiPut` with `variables`. The controller's `channel_message_template_params` will permit `:subject`, so the frontend must include `subject` in `variables`. Hook is generic. No issue.

### Automation modal inline-create-template
The spec says add subject input in the inline-create-template flow. The `HiringStageAutomationModal` currently creates templates inline -- when a user creates a new template from within the automation modal, it goes through `useCreateChannelMessageTemplate`. Subject will flow through the same path. No issue.

### Automation modal existing-template preview
The spec says show the saved template's subject as-is. This means when an automation references an existing template, the preview should show the template's `subject` field value. The template data comes from `useChannelMessageTemplates()` which fetches from the templates index endpoint. The serializer will expose `:subject`. The component can read it. No issue.

### No single-send yup schema (re-confirmed from Round 1)
Round 1 noted this as MED. Re-confirmed: `validateWithYup.ts` has no schema for single-send channel messages. The single-send composer validates inline. This is a known implementation detail, not a spec gap.

No new issues found.

## Amendments Applied

None.
