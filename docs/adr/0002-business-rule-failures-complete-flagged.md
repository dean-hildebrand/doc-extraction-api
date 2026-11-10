# Business-rule failures complete with a failing validation report

When an extraction result still breaks a business rule (line items don't sum to the total, VAT doesn't match its rate) after the re-prompt, the extraction moves to `completed` with a validation report marked `passed: false`, not to `failed`. The model is often right and the invoice itself is wrong, so failing would discard correct data; the client decides what to trust. A result that still fails JSON Schema validation after the re-prompt is structurally unusable and does fail, with `schema_validation_failed`.

This deviates from the original spec, which failed the extraction on either kind of validation failure.
