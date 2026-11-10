# Document Extraction

A multi-tenant API that turns uploaded invoices and other business documents into structured, validated data.

## Tenancy and access

**Organization**:
The tenant: the company whose documents, extractions and credentials are kept apart from everyone else's.
_Avoid_: Tenant, customer, account, client

**API key**:
A credential belonging to one organization, carrying the scopes that decide what it may do.
_Avoid_: Token, secret, password

## Documents and extraction

**Document**:
A file an organization has uploaded (PDF, PNG or JPEG), together with its metadata.
_Avoid_: File, upload, attachment

**File** (narrow sense):
The raw bytes of a document as sent in the multipart `file` field. Use it only for those bytes, as in the upload error codes `unsupported_file_type`, `file_too_large` and `unreadable_file`; the domain concept is always a document.

**Extraction schema**:
A versioned definition of the fields to pull out of a document; a version never changes once published.
_Avoid_: Template, form

**Extraction**:
One request to pull data out of a document against a specific extraction schema version, together with its lifecycle from queued to completed or failed.
_Avoid_: Job, request, task

**Extraction result**:
The data a completed extraction produced, with its validation report.
_Avoid_: Output, response

**Validation report**:
The outcome of checking an extraction result against its extraction schema and business rules: passed, or the list of what failed.
_Avoid_: Errors, warnings

**Business rule**:
A check on extracted data that a schema cannot express, such as line items summing to the total or VAT matching its rate.
_Avoid_: Constraint, sanity check

## Lifecycle

**Run**:
One pass of an extraction from queued to completed or failed.
_Avoid_: Attempt, execution

**Re-prompt**:
The single extra model call within a run that feeds the validation failures back to the model.
_Avoid_: Retry, second attempt

**Retry**:
A client-requested new run of a failed extraction. Nothing else in the domain is called a retry.
_Avoid_: Re-run, resubmit
