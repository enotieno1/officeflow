# WhatsApp Interactive Flows and Credit-Readiness: Safe Implementation Review

**Date:** 2026-10-26  
**Status:** Code foundation added on PR branch; not deployed or enabled in production.

## Implemented in this change

- Raw-body Meta X-Hub-Signature-256 HMAC-SHA256 verification helper and Deno unit tests.
- supabase/functions/whatsapp-webhook/index.ts: GET verification challenge and signed POST receipt ingestion. It stores only a payload digest, event kind, provider event key, and phone-number ID; it does not persist full message bodies. Duplicate event keys are ignored by the database unique constraint/upsert.
- Migration 20261026090000_whatsapp_credit_readiness_foundation.sql: private receipt storage, hashed one-time flow-token records, organization consent records, and report snapshot records. anon and authenticated have no table privileges; trusted server-side functions use the service role.
- This endpoint records receipts only. It does not execute approvals, payroll, payouts, task mutations, or credit decisions.

## Decisions and security boundaries

### WhatsApp ingress: separate authenticity from authority

1. The initial GET challenge uses META_WHATSAPP_VERIFY_TOKEN. For POST delivery, validate X-Hub-Signature-256 using HMAC-SHA256 over the exact raw HTTP request bytes and the Meta app secret. Do not JSON-stringify a parsed body before checking the signature.
2. WhatsApp Flow data exchange is a separate protocol: encrypted Flow endpoint requests require Meta's documented decryption/response procedure. Do not treat a regular Cloud API nfm_reply webhook as an encrypted Flow endpoint request.
3. Treat flow_token as an opaque, server-issued, short-lived, one-time capability. Never parse a database ID from a client-provided token. The migration stores only a token hash and binds records to organization, actor, allowed action, entity, expiry, and consumption state. A trusted token-issuance/atomic-consumption service is still required before using these records.
4. A phone number is not sufficient authorization. The sender must map to an actively verified OfficeFlow profile/organization binding, and the token-bound action must be authorized at execution time. Phone-binding and opt-in management are not yet implemented.
5. Do not perform arbitrary table updates from webhook handlers. Approvals must use the existing guarded workflow decision path and preserve segregation of duties. Payroll/payout execution must remain separate and must never be triggered by an unverified WhatsApp action.
6. Idempotency is enforced at the receipt boundary using unique provider event keys. A later action processor must atomically claim a receipt and ensure an action is applied no more than once.
7. Retain only necessary message metadata and action evidence. Do not log secrets, access tokens, or full message payloads by default. GPS must be optional and policy-driven; coordinates are sensitive personal data.

### Credit-readiness: report operational evidence, not an invented lending score

The supplied SQL references operational_audit_ledger, action_type, payload_snapshot, financial_payouts, and internal_users, which are not the current core schema verified for OfficeFlow. The live schema currently has audit_events, transactions, tasks, profiles, and organizations. The supplied SQL therefore cannot be deployed as-is.

The proposed coefficients are not a calibrated model and have no demonstrated predictive validation. A 300–850 score and automatic ALLOW/DENY recommendation would create false precision.

**Safer first release:**
- Publish an organization-authorized, explainable operational-readiness report: data completeness, observed cash-flow regularity, task completion timeliness, data recency, and audit-data coverage, with definitions and missing-data warnings.
- Do not infer cash flow from generic transaction labels without verified transaction semantics, reconciliation status, and currency.
- Do not expose organization data to a lender without explicit, revocable organization consent, a registered partner identity, least-privilege scopes, purpose, expiry, rate limits, and a disclosure/audit trail.
- Use a documented API contract with key rotation, request IDs, TLS, and server-side secrets. Never put partner secrets in browser code.
- Do not return a credit decision or deny/approve recommendation until the model has representative historical outcome data, local legal/privacy review, fairness/error testing, human review, and a clear correction/appeal process. The lender retains its own decision responsibility.

## Remaining work before production enablement

1. Add and run Deno tests for the webhook handler and the signature helper in the repository's CI.
2. Apply the migration through a reviewed deployment and verify grants/RLS in the target environment.
3. Configure META_WHATSAPP_VERIFY_TOKEN, META_APP_SECRET, and Supabase function environment securely; configure Meta's callback URL and subscribed webhook fields.
4. Implement verified phone binding, opt-in/consent capture, token issuance, and atomic one-time token consumption.
5. Build a receipt worker that claims events safely, retries failures, and routes only low-risk, pre-authorized actions through guarded business APIs.
6. Implement a readiness report over the actual schema with tests for empty, partial, inconsistent, stale, and multi-tenant data.
7. Add a partner registry and API authorization before any external lender endpoint is exposed.

## Production release gates

- Invalid signatures are rejected; exact raw-body signature tests pass.
- Duplicate webhook deliveries do not create duplicate business actions.
- Tenant isolation, expiry, replay, inactive user, revoked phone binding, insufficient role, and segregation-of-duties tests pass.
- No action executes when audit/receipt persistence fails.
- Partner endpoints have explicit consent and scope checks, rate limits, revocation, and access auditing.
- End-to-end tests and deployment status confirm the deployed function matches the reviewed commit.

**Not enabled by this change:** WhatsApp account connection, message delivery, action execution, payout approvals, lender credentials, credit decisions, or partner access. The endpoint and migration are in the pull-request branch only. Vercel build checks have previously been blocked by the account's build-rate-limit; this change has not been verified as live.
