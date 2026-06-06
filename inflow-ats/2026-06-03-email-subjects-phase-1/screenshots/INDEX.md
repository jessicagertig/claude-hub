# Email Subjects Phase 1a — Screenshot Index

The organized screenshots are in the numbered folders below. Older screenshots from earlier QA runs are in `agent-*` and `round-*` folders — you can ignore those.

## 01-single-send-composer/ (the new inline-editable subject)

This is the main design change — the compact subject display replacing the old full-height FormInput.

| File | What it shows |
|------|--------------|
| `01-default-subject-display.png` | **Key screenshot.** Composer with inline "Subject: Software Engineer at Acme Inc." in gray + pencil icon. Compact, doesn't dominate the body editor. |
| `02-subject-editing-mode.png` | Click the row → inline input appears in same space |
| `03-custom-subject-typed.png` | Custom subject "Follow-up: Interview Scheduling" typed in |
| `04-message-sent-success.png` | Message sent, appears in thread |
| `05-empty-subject-validation.png` | Subject cleared, showing editing state before validation |
| `06-subject-repopulated-after-error.png` | Subject auto-repopulated to default after escape/blur |

## 03-template-selection-modal/

| File | What it shows |
|------|--------------|
| `01-template-list.png` | "Choose template" modal with dropdown |
| `02-template-selected-with-subject-preview.png` | **Key screenshot.** Template selected, preview shows "Subject: Software Engineer at Acme Inc." above the body preview |
| `03-template-inserted-into-composer.png` | After selecting, composer shows template body and subject |

## 04-bulk-message-modal/

| File | What it shows |
|------|--------------|
| `01-bulk-modal-with-subject.png` | **Key screenshot.** Bulk modal with Subject field showing `{{JobTitle}} at {{OrganizationName}}` (template variables since no single candidate) |
| `02-bulk-modal-template-selected.png` | Template selected, subject updated from template |

## 05-template-create-edit/

| File | What it shows |
|------|--------------|
| `01-template-list-page.png` | Settings → Message Templates list |
| `02-create-modal-with-subject-field.png` | **Key screenshot.** Create modal showing Subject field between name and body, default `{{JobTitle}} at {{OrganizationName}}` |
| `03-template-saved-in-list.png` | New template appears in list after save |
| `04-edit-modal-showing-saved-subject.png` | Edit modal confirming custom subject persisted |

## 06-automation-modal/

| File | What it shows |
|------|--------------|
| `02-automation-modal-inline-create.png` | **Key screenshot.** Template create form showing Subject field |
| `01-template-list-with-subjects.png` | Templates list (note: subjects not shown in list view) |

## 07-job-setup-automations/

| File | What it shows |
|------|--------------|
| `01-automations-disabled.png` | Apply response template toggle in disabled state |
| `02-automations-enabled-with-subject.png` | **Key screenshot.** Toggle enabled, Subject field visible with `{{JobTitle}} at {{OrganizationName}}` |
| `03-custom-subject-entered.png` | Custom subject typed |
| `04-subject-persisted-after-reload.png` | Custom subject persisted after save and reload |

## Notable findings from screenshots

1. The new inline subject in `01-single-send-composer/` is compact and recedes behind the body editor — much less visual weight than the old FormInput
2. Pencil icon is always visible (per your feedback)
3. All surfaces have subject fields with appropriate defaults
4. Template selection preview shows rendered subject with actual candidate/job values
5. Sent messages don't show the subject in the thread (Phase 1b scope)
