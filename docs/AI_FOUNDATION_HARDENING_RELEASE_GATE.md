# OfficeFlow AI Foundation — Hardening and Release Gate

**Status:** Engineering hold — not approved for production sign-off  
**Environment inspected:** Supabase project `oghowrilrhummzvrljdt`  
**Inspection date:** 2026-11-06  
**Scope:** Existing AI gateway, usage metering, workflow grounding, recommendation security. No UI changes and no new AI features.

## 1. Verified production facts

The deployed `officeflow-ai` Edge Function is active at version 2. Its current implementation:
- manually validates the bearer token through Supabase Auth;
- uses the caller's JWT for organisation-scoped RPC reads;
- grounds only `workflow-automation` using `fn_ai_workflow_timing` and `fn_operational_intelligence`;
- logs usage through the authenticated `fn_ai_log_usage` RPC;
- checks a per-user daily limit by counting only rows with status `ok`;
- calls OpenAI directly and does not record provider token usage, cost, or latency;
- has no atomic reservation/finalisation flow;
- does not ground HR, Finance, document, email, calendar, or compliance features in live module data.

Production database inspection confirms:
- `ai_usage_log` exists but currently has zero rows;
- `ai_recommendations` exists but currently has zero rows;
- `ai_org_limits` does not exist;
- `ai_model_pricing` does not exist;
- `ai_usage_log.request_id` does not exist;
- authenticated users currently have EXECUTE on public wrappers for `fn_ai_log_usage` and `fn_ai_record_recommendation`, as well as the read/decision wrappers;
- the production migration ledger records the original AI foundation migration as version `20261106103130` named `ai_foundation_usage_recommendations_timing`.

The production Edge Function currently has `verify_jwt=false`, but its code manually validates the bearer token against Supabase Auth. This is not, by itself, proof of an authentication bypass. Keep the manual check until a tested replacement is deployed; preferably enable platform JWT verification after confirming compatibility.

## 2. Required engineering corrections

### A. Atomic request reservation and quota enforcement
- Use a server-only reservation RPC before any provider call.
- Enforce per-user and per-organisation daily request limits atomically under a transaction/advisory lock.
- Count billable and non-billable attempts according to an explicit abuse-control policy. A provider failure, timeout, invalid response, and blocked attempt must not silently disappear from abuse quotas.
- Add a unique idempotency constraint for `request_id`; retries with the same request ID must not create additional reservations.
- Reserve a conservative maximum token budget before the provider call. Reconcile the reservation to actual provider-reported prompt and completion tokens during finalisation.
- Until verified model prices are configured, enforce request and token limits and report monetary cost as unknown/null. Never fabricate estimated cost.

### B. Trusted finalisation
- Finalisation must be server-only and tied to the exact reservation, verified user, and organisation.
- Reject unknown reservations, cross-user/cross-organisation finalisation, duplicate finalisation, negative token counts, negative latency, invalid status transitions, and unrecognised provider/model identifiers.
- Make finalisation idempotent only when the repeated payload exactly matches the already-finalised record; otherwise reject and alert.
- Record provider errors, timeouts, invalid responses, and cancellation outcomes without losing the reservation history.
- Never expose the service-role key to the browser or send it to the model provider.

### C. Recommendation recording and audit
- Replace any service-role recorder that depends on `auth.uid()` with a trusted server-side recorder accepting the verified user and organisation IDs.
- Validate that the verified user belongs to the supplied organisation and has the required permission.
- Enforce feature/title/summary/evidence size limits in the database as well as the Edge Function.
- Recommendation decisions must be audited transactionally. If the audit write fails, the decision must fail and roll back; do not return success.
- Keep recommendation generation disabled until the recorder, decision flow, permissions, and audit path pass tests.

### D. Tenant and unit isolation
- Continue using the end-user JWT for tenant-scoped read RPCs. Never use service-role credentials to retrieve broad organisational data for model grounding.
- Confirm managers can only receive their assigned unit's analytics; a manager with no assigned unit must be denied or receive an explicitly empty scope.
- Confirm administrators' organisation-wide access is intentional and auditor access is read-only.
- Never include individual employee performance rankings or sensitive HR details in generic management grounding.

### E. Gateway hardening
- Validate request JSON shape, message roles, maximum message count, per-message and total character limits, feature allowlist, and content type.
- Apply request timeout and provider timeout handling; cap output tokens and total provider spend.
- Do not log prompts, completions, secrets, or personal data. Log only minimum metadata and controlled source identifiers.
- Return generic client errors; retain detailed diagnostics in protected server logs.
- Use restrictive CORS origins for the production application rather than wildcard CORS once the exact production origins are confirmed.
- Set `Cache-Control: no-store` on every response containing user-specific data.
- Prefer `verify_jwt=true` after end-to-end validation of the function's JWT path.

## 3. Mandatory automated test matrix

| Test | Required result |
|---|---|
| Two concurrent reservations at the daily limit | Exactly the permitted number succeeds |
| Same request ID submitted twice | One reservation only |
| Provider failure / timeout | Attempt remains accounted for |
| Monthly token cap under concurrency | Reserved plus consumed tokens never exceed cap |
| Missing pricing row | Cost is null/unknown; token/request controls still apply |
| Finalise another user's reservation | Rejected |
| Finalise another organisation's reservation | Rejected |
| Finalise the same reservation twice | No duplicate usage or cost |
| Negative tokens or latency | Rejected |
| Unknown provider/model/status | Rejected |
| Manager requests another unit ID | Rejected or safely scoped to assigned unit |
| Manager has no assigned unit | No cross-unit data returned |
| User from tenant A requests tenant B data | No data returned |
| Auditor attempts a decision/write | Rejected |
| Browser directly calls trusted reserve/finalise/record RPC | Permission denied |
| Recommendation audit insert fails | Decision rolls back |
| Oversized recommendation evidence | Rejected |
| Invalid message role / oversized payload | Rejected before provider call |
| Provider returns empty/invalid JSON | Safe error; attempt finalised as failure |
| Provider key absent | Explicit not-configured response; no fake answer |

Tests must use at least two test organisations and multiple roles. Do not use real employee data.

## 4. Migration and deployment sequence

1. **Reconcile source first.** Locate the exact migration and Edge Function source corresponding to the deployed production version. The live migration ledger already contains version `20261106103130`; do not reapply a migration under a different timestamp or rename history casually.
2. **Prepare a new, forward-only migration.** It must be idempotent where practical, preserve existing rows, validate constraints before adding them, add indexes/uniqueness safely, and include explicit grants/revokes. Do not rewrite the historical migration.
3. **Test on an isolated Supabase development branch/database.** Apply the migration there and run all SQL and role-isolation tests.
4. **Deploy the revised Edge Function to the test environment.** Confirm required secrets are present without printing or exposing secret values.
5. **Run end-to-end tests** for successful requests, provider failures, timeout, quota exhaustion, tenant isolation, unit isolation, and audit failure.
6. **Deploy the new gateway to production only after approval and backup.** It must use the caller JWT for scoped reads and server-side service credentials only for reservation/finalisation.
7. **Verify production behaviour** with controlled test accounts and synthetic data.
8. **Only then revoke authenticated execution** on legacy client-writable usage/recommendation RPCs. Do not revoke these grants before the new gateway is live and verified, because the current gateway still uses the user JWT for logging.
9. **Rollback plan:** retain the previous Edge Function source/version and a tested forward-fix path. Do not drop usage records or reverse security controls in a way that reopens client writes.

## 5. Release acceptance criteria

AI foundation may be marked **production verified** only when:
- migration reconciliation is documented and the new migration is tested;
- all mandatory tests pass, including concurrency and cross-tenant tests;
- trusted writes are service-role-only and ownership-validated;
- tenant/unit read paths remain caller-JWT scoped;
- quotas and token reservations are atomic;
- provider token usage and latency are captured accurately;
- cost is either calculated from verified pricing or explicitly unknown;
- provider success and failure paths are verified in production;
- direct browser calls to trusted write RPCs fail;
- audit failures prevent false success;
- operational logs contain no secrets or conversation content.

**Until every criterion is evidenced, the status remains: NOT APPROVED FOR PRODUCTION SIGN-OFF.**
