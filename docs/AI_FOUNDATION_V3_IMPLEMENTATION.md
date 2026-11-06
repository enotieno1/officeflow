# AI Foundation v3 — implementation and deployment notes

## Current implementation branch

`ai-foundation/hardening-release-gate-2026-11-06`

The branch contains a first implementation candidate:
- `supabase/migrations/20261106150000_ai_usage_controls_v2.sql`
- `supabase/functions/officeflow-ai/index.ts`
- `supabase/config.toml` (JWT verification enabled for the AI Edge Function)
- `supabase/tests/ai_foundation_hardening_test.sql`
- `docs/AI_FOUNDATION_HARDENING_RELEASE_GATE.md`

This is a review branch, not a production deployment.

## Important behaviour

- The Edge Function validates the user session, then reads the user's own `profiles.organization_id` under that user's JWT. It does not accept a tenant ID from the browser.
- The Edge Function uses the service-role key only server-side to call trusted reservation and finalisation functions.
- Workflow grounding continues to use the caller's JWT, preserving existing RLS and role checks.
- The migration introduces atomic request reservations, daily user and organisation request limits, a monthly token budget, unique request IDs, usage token/latency/error fields, and trusted server-only finalisation.
- Provider pricing is deliberately not seeded. Cost remains null/unknown until the current model pricing is independently verified and entered.
- The trusted recommendation recorder validates user/organisation membership and does not depend on `auth.uid()`.
- Recommendation decisions are audited transactionally; an audit insert failure rolls back the decision.
- The gateway uses a 30-second provider timeout, caps message count and total input size, caps completion tokens, and requires an explicit allowed-origin list for browser requests.

## Required Edge Function secrets

Set these in the Supabase Edge Function secrets manager; never commit them:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (or supported publishable key)
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENAI_API_KEY`
- `OFFICEFLOW_ALLOWED_ORIGINS` — comma-separated exact production frontend origins, no wildcard
- Optional: `OPENAI_MODEL`, `OPENAI_MODEL_SMALL`, `OPENAI_MODEL_LARGE`, `AI_RESERVED_TOKENS_PER_REQUEST`

The provider secret and current model identifiers have not yet been independently verified. Do not claim the live provider is working until a real end-to-end request succeeds and its token usage is reconciled.

## Safe deployment sequence

1. Create or use a non-production Supabase development branch/database.
2. Apply `20261106150000_ai_usage_controls_v2.sql` there.
3. Run `supabase/tests/ai_foundation_hardening_test.sql`.
4. Run the authenticated multi-tenant and concurrency integration tests listed at the bottom of that SQL test file.
5. Deploy the new Edge Function to the test environment with the required secrets.
6. Confirm the frontend sends a valid JWT and that its exact origin is in `OFFICEFLOW_ALLOWED_ORIGINS`.
7. Test successful responses, provider failure, timeout, missing provider key, quota exhaustion, tenant isolation and manager unit isolation.
8. Confirm every request is reserved before provider execution and finalised with actual provider token usage.
9. Only after the replacement gateway is deployed and verified should a separate Part B migration revoke authenticated execution on the legacy `fn_ai_log_usage` and `fn_ai_record_recommendation` wrappers.
10. Production deployment requires an approved backup/recovery plan and explicit release approval.

## Current limitations and release blockers

- The migration has not been applied to production.
- The new Edge Function has not been deployed.
- Automated SQL assertions and authenticated integration tests have not yet been run.
- The live provider secret and provider billing/model configuration have not been verified.
- Legacy client-executable usage/recommendation RPC permissions have intentionally not been revoked because the old gateway still depends on the usage logger.
- A Supabase development branch could not be created because the connector requires the organisation-specific branch cost to be disclosed and explicitly approved first.

Do not mark this work production-ready until every release acceptance criterion in the release-gate document is evidenced.
