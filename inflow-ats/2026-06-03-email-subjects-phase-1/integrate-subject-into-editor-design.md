# Design: Integrate Subject Field into Editor.tsx

**Branch:** `integrate-subject-into-editor` (off `messaging-improvements-qa`)
**Date:** 2026-06-05

## Problem

The Email Subjects Phase 1a implementation added a subject `FormInput` to 4 parent forms that also have a ProseMirror editor with mail merge tag buttons. The merge tag buttons (`MessageMailMergeMenuBar`) are wired to insert `{{variables}}` into the ProseMirror editor via ProseMirror's `dispatch` function. When a user has focus on the subject input and clicks a merge tag button, the tag is inserted into the body editor instead of the subject field. The user expects the tag to be inserted into whichever field has focus.

## Why the merge tag buttons are inside Editor.tsx

`MessageMailMergeMenuBar` needs ProseMirror's `state.selection` to know the cursor position and ProseMirror's `dispatch` function to insert text at that position. Both `state` and `dispatch` are internal to `Editor.tsx`. The buttons were placed inside `Editor.tsx` specifically because that is where `state` and `dispatch` live. This is a dependency, not a design choice.

## Why ProseMirror's dispatch cannot be used for subject insertion

ProseMirror's `dispatch` function accepts ProseMirror `Transaction` objects. A subject `<input>` element is a standard HTML input — it does not have transactions. ProseMirror's dispatch cannot send text to a plain `<input>`. These are completely separate systems. The merge tag buttons need an if-else branch: if the subject field has focus, call a function that inserts into the subject input. Else, call `dispatch` with the ProseMirror transaction as it does today.

## Rejected approaches

### 1. Add `onFocus` to `FormInput` and pass `lastFocusedField` / `insertTagIntoSubject` through Editor.tsx as passthrough props

This was the first proposed approach. `FormInput` does not currently accept an `onFocus` prop. Adding one is a 2-line change duplicating the existing `onBlur` pattern (`handleFocus` calling `props.onFocus(name, value)` if provided, wired to the `<input>` element). The parent form would track `lastFocusedField` state, and pass `lastFocusedField` and `insertTagIntoSubject` as props through `Editor.tsx` to `MessageMailMergeMenuBar`.

**Why it doesn't work:** `FormInput` does not expose a ref to the underlying `<input>` element. The `inputRef` is internal (line 15 of `FormInput/index.js`). Without a ref, the parent form's `insertTagIntoSubject` function cannot read `selectionStart` / `selectionEnd` on the `<input>` to insert the tag at the cursor position. It could only append to the end, which is bad UX.

### 2. Add `forwardRef` to `FormInput`

This would give the parent form a ref to the underlying `<input>`, solving the cursor position problem. `React.forwardRef` is the standard React pattern for exposing a child's DOM element.

**Why rejected:** `FormInput` is used throughout the entire application. Adding `forwardRef` changes the component's interface. While `forwardRef` is additive (existing callers that don't pass a ref are unaffected), the risk of touching a component used everywhere outweighs the benefit for this specific feature.

### 3. Use `document.activeElement` to find the subject input

Inside `insertTagIntoSubject`, check `document.activeElement` to get the input element and use `selectionStart` / `setRangeText` on it.

**Why rejected:** Hacky. Depends on browser focus timing and the assumption that nothing else has moved focus between the user's click and the function call. The merge tag buttons use `onMouseDown` with `event.preventDefault()` which affects focus behavior — relying on `document.activeElement` in that context is fragile.

### 4. Save `event.target` from the `onFocus` event

When `onFocus` fires on the subject input, save `event.target` (the raw DOM node) in React state, then use it later in `insertTagIntoSubject` to read cursor position and insert.

**Why rejected:** Saving a raw DOM node in React state is fighting the framework. React state is meant for serializable data, not DOM references. Also requires changing `FormInput`'s callback signature — `onBlur` currently passes `(name, value)`, not the event. Duplicating the `onBlur` pattern for `onFocus` (as originally proposed) would lose access to `event.target`.

### 5. Lift `MessageMailMergeMenuBar` out of `Editor.tsx` into the parent forms

Remove the merge tag buttons from `Editor.tsx` and render them directly in each parent form where they'd have access to both the subject input and the editor ref.

**Why rejected:** `MessageMailMergeMenuBar` needs ProseMirror's `state` and `dispatch` to insert at the cursor position in the body. These are internal to `Editor.tsx`. The `editorRef.current` object exposes `insertTextAtCurrentSelection`, but that method inserts at position 0, not at the current cursor position (the name is misleading — the commented-out `let { from, to } = editorState.selection;` at line 371 of `Editor.tsx` shows cursor-position insertion was attempted and abandoned). So lifting the buttons out would break body insertion at cursor position.

### 6. Create a separate `MessageEditor` component that duplicates `Editor.tsx`

Copy `Editor.tsx` into a new `MessageEditor.tsx`, add the subject input and merge tag routing, strip `MessageMailMergeMenuBar` from `Editor.tsx`.

**Why rejected:** Duplicating a complex component creates a maintenance burden. Any future changes to `Editor.tsx` (ProseMirror upgrades, new toolbar features, bug fixes) would need to be applied to both files. Only 4 callers use `enableMessageMailMergeMenuBar` — the duplication is not justified.

## Chosen approach: Add optional subject input inside Editor.tsx

The subject input moves inside `Editor.tsx`, gated behind `enableMessageMailMergeMenuBar`. This is the only place where `state`, `dispatch`, and the merge tag buttons all live. Adding the subject input here means:

- Focus tracking between subject and body is internal — no props threading through parent forms
- The subject input's ref is available locally — cursor position is readable for tag insertion
- `MessageMailMergeMenuBar` receives `lastFocusedField` and `insertTagIntoSubject` from its parent (`Editor.tsx`), which owns both
- No changes to `FormInput`
- Callers that don't use `enableMessageMailMergeMenuBar` are completely unaffected

The subject input only makes sense when merge tag buttons are present — they are the same concern. `Editor.tsx` already has email-specific behavior via `enableMessageMailMergeMenuBar` and `allowSenderMailMergeFields`.

## Implementation steps

### Step 1: Add subject support to Editor.tsx

When `enableMessageMailMergeMenuBar` is true:

- Add `subject` useState, initialized from a new `defaultSubject` prop
- Add a subject input ref (plain React ref, not `FormInput`)
- Render a subject input above the ProseMirror area
- Track `lastFocusedField` state internally, defaulting to `'body'`
- Set `lastFocusedField` to `'subject'` when the subject input receives focus
- Set `lastFocusedField` to `'body'` when the ProseMirror contenteditable receives focus (using the existing `handleDOMEvents.focus` handler at line 477, which already fires — but no caller has ever passed `onFocus` to the Editor, so this code path has never been exercised in production)
- Define `insertTagIntoSubject` function that reads `selectionStart` / `selectionEnd` from the subject input ref and inserts the tag text at that position
- Accept `onSubjectChange` prop so the parent form is notified when the subject changes
- Expose `subjectState()` on `editorRef.current` alongside `serializedState()`, following the same naming pattern. The parent form calls `editorRef.current.subjectState()` at submit time to get the subject string, same as it calls `editorRef.current.serializedState()` to get the body HTML string

New props on Editor.tsx (all optional, only used when `enableMessageMailMergeMenuBar` is true):
- `defaultSubject: string` — initial subject value
- `onSubjectChange: (value: string) => void` — called when subject changes

New method on `editorRef.current`:
- `subjectState()` — returns the current subject string

### Step 2: Update MessageMailMergeMenuBar.tsx

Accept two new props from `Editor.tsx`: `lastFocusedField` and `insertTagIntoSubject`.

In `handleInsert`, replace the current body:

```javascript
const handleInsert = (text) => {
  return (state, dispatch) => {
    let { from, to } = state.selection;
    if (dispatch) dispatch(state.tr.insertText(text, from, to));
    return true;
  };
};
```

With an if-else branch:

```javascript
const handleInsert = (text) => {
  return (state, dispatch) => {
    if (lastFocusedField === 'subject') {
      insertTagIntoSubject(text);
    } else {
      let { from, to } = state.selection;
      if (dispatch) dispatch(state.tr.insertText(text, from, to));
    }
    return true;
  };
};
```

When `lastFocusedField` is `'subject'`, call `insertTagIntoSubject(text)` — this inserts the tag into the subject input at the cursor position. Else, read `from` and `to` from `state.selection` and call `dispatch(state.tr.insertText(text, from, to))` — the existing ProseMirror insertion path.

When `lastFocusedField` and `insertTagIntoSubject` are not provided (callers that don't use subject), the else branch fires every time — identical to current behavior.

### Step 3: Update ChannelMessageTemplateModal.tsx

- Remove the subject `FormInput` and its state management (`defaultSubject` useState, `handleChangeChannelMessageName` for subject)
- Pass `defaultSubject` to the `ProseMirrorEditor`
- At submit time, read `editorRef.current.subjectState()` and include it in the validation call and the create/update mutation
- Remove the subject repopulation logic from the validation error handler (the subject input inside `Editor.tsx` handles its own state)

### Step 4: Update BulkMessageModal.tsx

Same changes as Step 3:
- Remove subject `FormInput`, subject state, `handleChangeSubject`
- Pass `defaultSubject` to `ProseMirrorEditor`
- Read `editorRef.current.subjectState()` at submit time

### Step 5: Update HiringStageAutomationModal.tsx

Same changes as Step 3, in the `isCreatingTemplate` branch only:
- Remove subject `FormInput`, `newTemplateSubject` state, `handleChangeNewTemplateSubject`
- Pass `defaultSubject` to `ProseMirrorEditor`
- Read `editorRef.current.subjectState()` at submit time in `handleSaveTemplate`

### Step 6: Update JobSetupAutomations.tsx

Same changes as Step 3:
- Remove subject `FormInput`, `applyResponseTemplateSubject` from job state
- Pass `defaultSubject` to `ProseMirrorEditor`
- Read `editorRef.current.subjectState()` at submit time in `handleSubmit`

### Step 7: Verify webpack compiles

Run `RAILS_ENV=test bin/webpack` from the worktree and confirm zero errors.

## Styling

The subject input inside `Editor.tsx` should match the existing styling patterns in the app:

- Same font size as the body text (`t.text.sm` on mobile, `t.text.base` otherwise — follow the existing input sizing in the Editor's container)
- Muted text color: `gray[500]` in light mode, `gray[400]` in dark mode — same as the inline-editable subject display in the composer
- "Subject:" label if appropriate, or just a placeholder
- The input should be visually secondary to the body editor — it should not dominate

The exact styling will be determined during implementation based on how it looks in context with the rest of the Editor's container.

## What this does NOT change

- `FormInput` — no changes
- `Editor.tsx` behavior when `enableMessageMailMergeMenuBar` is false — no changes, no new UI, no new state
- The `onMouseDown` / `event.preventDefault()` pattern on merge tag buttons — unchanged, still necessary for ProseMirror focus preservation
- The existing `serializedState()`, `clearEditor()`, `replaceEditorContent()` methods on `editorRef.current` — unchanged
- `ChannelMessageNew.tsx` (the single-send composer) — this component uses a separate inline-editable subject pattern and does not use `enableMessageMailMergeMenuBar`, so it is not affected

## Risk

`Editor.tsx` is a shared component. The new behavior is gated behind `enableMessageMailMergeMenuBar`, which is only set to true by the 4 forms listed above. All other callers pass `enableMessageMailMergeMenuBar={false}` or don't pass it at all (it defaults to `undefined`, which is falsy). The risk is low but nonzero — any bug in the new code could theoretically affect the Editor's rendering or state management even when the flag is false. Thorough testing of both the 4 affected forms and at least one non-affected Editor instance is required.

One specific risk: `Editor.tsx`'s `onFocus` handler (line 482-484 of `handleDOMEvents.focus`) has never been called by any parent component in the application. It is used internally in this change to track when the ProseMirror contenteditable receives focus (setting `lastFocusedField` to `'body'`). The code path exists and looks correct, but it has never been exercised in production. It should be tested explicitly.
