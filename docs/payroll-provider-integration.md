# OfficeFlow payroll provider integration

## Current implementation
- Production Supabase contains tenant-scoped provider accounts, payment batches, payment transactions and provider event tables with RLS.
- Client-side direct writes to payout tables are revoked; server functions own sensitive mutations.
- payroll-payment-batch prepares a batch only after an approved payroll run and different approver are present. It does not send a provider request.
- mpesa-b2c-readiness is deployed with JWT verification. It checks presence of server-side configuration without returning secret values and explicitly reports live disbursement as disabled.
- No salary transfer has been initiated by this integration work.
- OfficeFlow subscription billing is separate from payroll payout. Billing payment callbacks must never confirm employee salary transfers.

## Safaricom M-Pesa B2C onboarding
Safaricom's official B2C documentation states that production use requires an approved Bulk Disbursement Account/B2C shortcode (or an eligible converted shortcode), production API credentials, an authorized B2C API initiator and publicly reachable HTTPS callback URLs. B2C is asynchronous: an immediate acknowledgement is not proof of payment; a final result callback and reconciliation are required.

1. Apply for B2C/Bulk Disbursement through Safaricom Business / M-PESA Business. Official starting points:
   - https://developer.safaricom.co.ke/apis/BusinessToCustomer
   - https://pay.m-pesaforbusiness.co.ke/
   - Safaricom business support: M-PESABusiness@Safaricom.co.ke
2. Create a Daraja developer account and sandbox app. Keep sandbox and production credentials separate.
3. After approval, have the business administrator create an API operator and assign the ORG B2C API Initiator role. Protect and rotate the operator password.
4. Add provider credentials only in Supabase Dashboard → Edge Functions → Secrets. Never paste secrets into chat, commit them to Git, put them in browser code, or store raw credentials in ordinary database rows.
5. Keep the organization's provider account pending_verification until the legal business, shortcode, environment, callback URL and credentials have been independently verified.
6. Configure and test HTTPS result and timeout callbacks. Deduplicate callbacks; store a minimal audit record; never trust a client-side success state or an unverified callback. Reconcile ambiguous timeouts through Safaricom's transaction-status facilities before retrying.
7. Verify employee M-Pesa destination numbers through an authorized HR/payroll workflow. The current payroll item schema does not itself store a verified destination number; do not infer a recipient from email or a display name.
8. Complete sandbox tests, cross-organization access tests, duplicate-request tests, callback replay tests, partial-failure tests and a finance sign-off before any production payout path is enabled.

## Readiness function
Invoke mpesa-b2c-readiness with an authenticated administrator session. It returns only booleans for whether expected secrets are present, organization-scoped provider account metadata, and explicit gates. It does not call Safaricom, expose secret values, or initiate payments.

Expected server-side secret names for future adapter work:
- OFFICEFLOW_DARAJA_ENV = sandbox or production
- DARAJA_CONSUMER_KEY
- DARAJA_CONSUMER_SECRET
- DARAJA_B2C_SHORTCODE
- DARAJA_INITIATOR_NAME
- DARAJA_INITIATOR_PASSWORD
- DARAJA_PUBLIC_CERT_PEM
- DARAJA_CALLBACK_SECRET

Do not set production values before Safaricom approval. The presence check is not itself proof that the shortcode or account is approved.

## Bank payout support
Use a separate bank-approved corporate bulk-payment adapter. Tokenize or encrypt bank account data, keep it tenant-scoped and never reuse M-Pesa callbacks to confirm bank payments.

## Hard safety gates
- The current provider adapter is not enabled for live transfers.
- Require an explicitly approved payroll run and separate explicit payment-batch approval by another authorized person.
- Use idempotency keys and reconcile provider references per employee.
- Never automatically retry an ambiguous or timed-out payout without checking provider status.
- Do not mark a payroll run paid based on a client request or unverified callback.
- No live payout is enabled until onboarding, secrets, adapter, callback reconciliation, tests and authorization controls are completed.
