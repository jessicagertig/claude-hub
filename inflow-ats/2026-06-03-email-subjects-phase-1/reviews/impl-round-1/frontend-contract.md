# frontend-contract -- Round 1

## Findings

### Yup validation schemas (validateWithYup.ts)

1. `channelMessageTemplateSchema`: `subject: string().required()` added. PASS.
2. `bulkMessageSchema`: `subject: string().required()` added. PASS.
3. `singleMessageSchema`: new schema with `subject: string().required()` and `body: string().required()`. PASS.
4. `validateSingleMessage` exported (line 163). PASS.

### ChannelMessageNew.tsx (single-send)

5. Default subject constructed from `jobApplication.job.title` and `jobApplication.job.organizationName` (line 29). `organizationName` is available via `JobSerializer` attribute `:organization_name` (line 11) which is a method on the Job model. PASS.
6. `validateSingleMessage` called before send (lines 89-100). PASS.
7. Repopulate on validation error (lines 96-98). PASS.
8. `subject` included in `createChannelMessage` call (line 112). PASS.
9. `handleInsertTemplate` sets subject from `mailMerge.subjectRaw` (lines 53-55). PASS.
10. Subject reset to default on successful send (line 119). PASS.
11. `FormInput` rendered above ProseMirror editor (lines 153-162). PASS.

### BulkMessageModal.tsx

12. Default subject: `"{{JobTitle}} at {{OrganizationName}}"` (line 53). PASS.
13. `subject` included in `validateBulkMessage` call (line 85). PASS.
14. Repopulate on validation error (lines 99-101). PASS.
15. `subject` included in `createBulkMessage` call (line 116). PASS.
16. Template selection sets subject from `template.subject || defaultSubject` (line 177). PASS.
17. `FormInput` rendered above ProseMirror editor (lines 264-272). PASS.

### ChannelMessageTemplateModal.tsx

18. Default subject with NULL fallback on edit: `props.channelMessageTemplate.subject || defaultSubject` (line 51). PASS.
19. `subject` included in `validateChannelMessageTemplate` call (line 86). PASS.
20. `subject` flows through `...channelMessageTemplate` spread in create (line 103) and update (line 128). PASS.
21. `FormInput` rendered between name and body editor (lines 186-193). PASS.
22. Props type updated to include `subject` (line 27). PASS.

- F1 [MED] `ChannelMessageTemplateModal.tsx` line 189: The subject `FormInput` uses `onChange={handleChangeChannelMessageName}` which is a generic handler that sets `[name]: value` on the state object. Since the input `name="subject"`, this works correctly (it sets `channelMessageTemplate.subject = value`). However, the handler name is misleading -- it's updating subject, not a name. Not a bug, just a naming oddity. Not blocking.

### HiringStageAutomationModal.tsx (inline create template)

23. `newTemplateSubject` state with default (line 57). PASS.
24. `subject` included in `validateChannelMessageTemplate` call (line 217). PASS.
25. `subject: newTemplateSubject` included in `createChannelMessageTemplate` call (line 227). PASS.
26. Subject reset in `handleStartCreateTemplate` (line 183), `handleDiscardTemplate` (line 190), and success handler (line 241). PASS.
27. `FormInput` rendered between name and body editor (lines 345-352). PASS.

### ChannelMessageTemplateSelectionModal.tsx (preview)

28. `mailMerge?.subjectRaw` displayed in `PreviewSelection` (lines 43-46). PASS.
29. `Styled.SubjectPreview` with appropriate styling. PASS.

### JobSetupAutomations.tsx (apply-response template)

30. `applyResponseTemplateSubject` in state with NULL fallback (line 25). PASS.
31. `applyResponseTemplateSubject` included in `updateJob` call (line 67). PASS.
32. `FormInput` rendered above ProseMirror editor (lines 140-147). PASS.

### useChannelMessage.ts

33. `createChannelMessage` passes `variables` directly -- subject flows through. PASS.

### useChannelMessageTemplate.ts

34. `createChannelMessageTemplate` and `updateChannelMessageTemplate` pass `variables` directly -- subject flows through. PASS.
35. `useMailMerge` returns whatever the API returns -- subject keys flow through. PASS.

No blocking issues found.
