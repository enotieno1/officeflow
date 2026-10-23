# OfficeFlow payroll provider integration

## Current implementation
- The production Supabase project has the payroll-provider foundation tables: provider accounts, payment batches, individual payment transactions, and provider events.
- Client writes are revoked for these tables; the authenticated client can read only records within its own organization and authorized payroll roles.
- No salary transfer is initiated by this schema change.
- Existing payroll records are separate from billing checkout. IntaSend billing webhooks must not be reused to confirm salary payouts.

## First provider: Safaricom M-Pesa B2C
Before enabling production disbursement:
1. Each organization must connect its own eligible Safaricom business shortcode / B2C account and obtain production approval.
2. Store provider credentials in a server-side secret store (never in browser code or ordinary client-readable tables). Provider-account rows store only a secret reference.
3. Add a payout destination workflow that verifies an employee's M-Pesa number and restricts access to authorized HR/payroll roles.
4. Build a server-side function that authenticates the caller, verifies organization membership and role, requires an approved payroll run and a different approver from the initiator, validates the net-pay total against the approved batch, and uses an idempotency key before calling B2C.
5. Configure provider result and timeout callbacks. Verify callbacks against the provider's authenticated status query before marking a transfer successful.
6. Reconcile per-employee provider references, failed/reversed transactions and the payroll control total. Never mark a run paid from a client request or an unverified callback.

## Bank payout support
Use the same batch/transaction lifecycle with a bank-approved corporate bulk-payment API. Keep bank account data tokenized or encrypted and tenant-scoped. Provider-specific authentication and callbacks must remain separate adapters.

## Safety gates before live use
- Test only in sandbox first.
- Confirm production credentials, callback URLs, funding account and provider limits with Safaricom / the bank.
- Run duplicate callback, timeout, partial failure, reversal and cross-organization access tests.
- Require explicit human approval for each payroll batch. Do not enable automatic salary release.
- Production credentials and provider approval are not supplied by this repository change; live payout is therefore not enabled.
