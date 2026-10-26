# WhatsApp Interactive Flows and Credit-Readiness: Safe Implementation Review

**Date:** 2026-10-26  
**Status:** Implementation design and verified primitives; no WhatsApp or lender integration is active yet.

## Decisions

The supplied blueprint is a useful product direction, but its example code must not be copied directly into production. It assumes tables and identity fields that are not present in the current OfficeFlow schema, and it mixes message authenticity, user authorization, transaction execution, and credit assessment in one path.

### WhatsApp ingress: separate authenticity from authority

1. **Meta webhook verification:** the initial GET challenge uses the configured verification token. For POST delivery, validate `X-Hub-Signature-256` using HMAC-SHA256 over the exact raw HTTP request bytes and the Meta app secret. Do not JSON.stringify a parsed body before checking the signature.
2. **WhatsApp Flow data exchange is a separate protocol:** encrypted Flow endpoint requests require the Meta-documented decryption/response procedure. Do not treat the regular Cloud API `nfm_reply` webhook as the encrypted Flow endpoint request.
3. **Treat `flow_token` as an opaque, server-issued, short-lived, one-time capability.** Never parse a database ID from a client-provided token. Store only a token hash; bind the token to an organization, actor, allowed action, entity, expiry, and consumption state.
4. **A phone number is not sufficient authorization.** The sender must map to an actively verified OfficeFlow profile/organization binding, and the token-bound action must be authorized at execution time.
5. **No direct arbitrary table updates from webhook handlers.** Approvals must use the existing guarded workflow decision path and preserve segregation of duties. Payroll/payout execution must remain separate and must never be triggered by an unverified WhatsApp action.
6. **Idempotency:** persist the provider message ID and enforce a unique constraint; duplicate webhook deliveries must not apply the same action twice. Acknowledge delivery only after durable receipt, or use a durable retryable queue.
7. **Privacy:** retain only necessary message metadata and action evidence. Do not log secrets, access tokens, or full message payloads by default. GPS must be optional/policy-driven and should include accuracy and capture time; coordinates are sensitive personal data.

### Credit-readiness: report operational evidence, not an invented lending score

The supplied SQL references `operational_audit_ledger`, `action_type`, `payload_snapshot`, `financial_payouts`, and `internal_users`, which are not the current core schema verified for OfficeFlow. The live schema currently has `audit_events`, `transactions`, `tasks`, `profiles`, and `organizations`. The supplied SQL therefore cannot be deployed as-is.

The proposed coefficients also do not sum to a calibrated model, have no demonstrated predictive validation, and use hard-coded currency thresholds that are not portable across countries or business sizes. A resulting 300–850 score and automatic `ALLOW`/`DENY` recommendation would create false precision.

**Safer first release:**
- Publish an organization-authorized, explainable operational-readiness report: completeness/coverage, observed cash-flow regularity, task completion timeliness, data recency, and audit-data coverage, with definitions and missing-data warnings.
- Do not infer cash flow solely from generic transaction labels without verified transaction semantics, reconciliation status, and currency.
- Do not expose organization data to a lender without explicit, revocable organization consent, a registered partner identity, least-privilege scopes, purpose, expiry, rate limits, and a disclosure/audit trail.
- Use a documented API contract with key rotation, request IDs, TLS, and server-side secrets. Never put partner secrets in browser code or compare a raw API token to an environment variable in a route.
- Do not return a credit decision or deny/approve recommendation until the model has representative historical outcome data, local legal/privacy review, fairness/error testing, human review and a clear correction/appeal process. The lender retains its own decision responsibility.

### Implementation order

1. Add and test the raw-body Meta signature verification primitive (included in this PR).
2. Design and migrate tenant-scoped phone verification, one-time flow-token and idempotent receipt records. Add RLS/grants and a server-side processing function before enabling any action.
3. Connect only workflow actions that already have a guarded RPC and tests. Keep payout execution out of scope.
4. Define an operational-readiness report using the actual schema and tests for empty, partial, inconsistent and multi-tenant data.
5. Add partner-consent and partner-client registry before exposing any API externally.

### Production release gates

- Secret configuration and Meta app setup verified in the target environment.
- Raw-body signature tests pass; invalid signatures are rejected.
- Duplicate webhook deliveries are idempotent.
- Tenant isolation, expiry, replay, inactive user, revoked phone binding, insufficient role, and segregation-of-duties tests pass.
- No action executes when audit persistence fails.
- Partner endpoints have explicit consent and scope checks, rate limits, revocation and access auditing.
- End-to-end tests and deployment status confirm the deployed function matches the reviewed commit.

**Not enabled by this PR:** WhatsApp account connection, message delivery, live webhook processing, payout approvals, lender credentials, credit decisions, or partner access. Those require provider configuration and the database/API controls above.
