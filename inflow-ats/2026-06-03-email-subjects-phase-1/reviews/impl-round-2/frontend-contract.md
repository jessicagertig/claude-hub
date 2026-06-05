# frontend-contract -- Round 2

## Findings

Re-verified all frontend surfaces with fresh scrutiny, focusing on edge cases and data flow.

### Additional checks this round:

1. Verified `ChannelMessageNew.tsx` line 29: `jobApplication.job.organizationName` -- the `JobSerializer` exposes `:organization_name` at line 11 (one of the listed attributes). The `Job` model has an `organization_name` method (via the `belongs_to :organization` association and a delegate or method). The API transforms `organization_name` to `organizationName` (camelCase). This value is available through the serialized `job` object nested inside the `jobApplication` response. PASS.

2. Verified `ChannelMessageTemplateModal.tsx` line 103-104: `createChannelMessageTemplate({ ...channelMessageTemplate, body: editorRef.current.serializedState() })`. The spread includes `id`, `name`, `body`, and `subject`. The explicit `body:` override replaces the stale body from state with the current editor state. `subject` flows through the spread. PASS.

3. Verified `ChannelMessageTemplateModal.tsx` line 126-128: `updateChannelMessageTemplate({ ...channelMessageTemplate, body: editorRef.current.serializedState() })`. Same pattern. `subject` flows through the spread. PASS.

4. Verified `handleInsertTemplate` in `ChannelMessageNew.tsx` line 53: uses `mailMerge?.subjectRaw`. The `subjectRaw` key comes from `render_template_message`'s response `subject_raw:` (line 826) transformed by `allKeysToCamel`. Correct data binding. PASS.

- F1 [MED] `ChannelMessageTemplateSelectionModal.tsx` line 207: `font-size: ${t.text.sm};` -- the codebase pattern is to use `${t.text.sm}` standalone (without a `font-size:` prefix) because `t.text.sm` is a `css` template literal that already includes `font-size: 0.875rem;`. Wrapping it in `font-size:` produces `font-size: font-size: 0.875rem;` which is invalid CSS. The subject preview font-size will not apply as intended. Existing codebase usage (e.g., `FormFieldset.tsx:50`, `SlidingToggleSwitch.tsx:135`) uses `${t.text.xs}` and `${t.text.sm}` standalone. The fix is to change `font-size: ${t.text.sm};` to `${t.text.sm};`.

5. Verified all `FormInput` components use `errors={errors}` for error display. All subject inputs connect to the form's error state. PASS.

6. Verified no `undefined` values are deliberately set (per critical rule #9). All defaults use `|| ''` or `|| defaultSubject` patterns. PASS.

No blocking issues found.
