# OfficeFlow Master Commercial Readiness Register
**Baseline date:** 2026-11-06  
**Repository:** `enotieno1/officeflow`  
**Live application:** `https://office-sort.vercel.app`  
**Supabase project:** `oghowrilrhummzvrljdt`  
**Operating rule:** Audit → Fix → Test → Verify → Release → Grow.

> This register distinguishes implementation evidence from tested, production-verified and customer-ready outcomes. A code artifact, database object or active function is not proof of an end-to-end customer workflow. Unknown means not yet verified, not necessarily broken.

## 1. Evidence-based baseline

| Area | Observed evidence | Status / next action |
|---|---|---|
| Supabase project | Project exists, status ACTIVE_HEALTHY; PostgreSQL 17; region eu-west-1 | Connected and operational at infrastructure level; assess suitability, latency, resilience and cost |
| Database schema | 46 public tables; RLS enabled on all 46 | Strong foundation; inspect table-by-table policies and data access |
| RLS policies | 83 policies reported | Verify tenant boundaries and least privilege with adversarial tests |
| Organisations / profiles | 1 organisation row; 6 profile rows | Existing data is present; validate onboarding and tenant lifecycle |
| Migrations | 94 migration records reported | Reconcile repository migration history with production; identify drift |
| Edge Functions | 7 active functions reported | Review code, secrets, auth, logs, tests and provider dependencies |
| Billing | Active `billing-checkout` and `intasend-webhook`; payment attempts/subscriptions/provider events tables exist | Implementation present; real sandbox/live payment lifecycle still needs end-to-end proof |
| AI | `officeflow-ai` function is active; code validates bearer session and requires `OPENAI_API_KEY` | Verify secret configuration, provider billing, authorization, data handling, rate limits and live responses |
| Invitations | Active `organization-invite` function; validates administrator and invitation context in inspected source | Test actual email delivery, expiry, acceptance and cross-tenant rejection |
| Vercel config | Root `vercel.json` has security headers and a build ignore command | Inspect Vercel project settings, domains, environment variables, previews, build logs and rollback |
| Repository documentation | Root README still describes legacy OOES / five-systems positioning; root `package.json` and `supabase/config.toml` were not found | Documentation/configuration drift to investigate; do not infer app framework from this alone |
| Recent code activity | Latest inspected commits dated 2026-11-01 include idle-timeout and auth-gate fixes | Review subsequent changes and release/deployment correspondence |

## 2. Supabase security findings requiring triage

The Supabase security advisor returned these findings on 2026-11-06:

1. **Two RLS-enabled tables have no policies:** `public.social_media_connections` and `public.social_media_oauth_states`. Determine whether these are intentionally service-role-only. Verify grants and test that client roles cannot access them. Do not add permissive policies merely to silence the finding.
2. **34 GraphQL exposure warnings:** authenticated role can discover objects through the GraphQL schema. Review which objects should be exposed; distinguish schema discoverability from row-level access. Restrict unnecessary GraphQL exposure without breaking legitimate application paths.
3. **23 SECURITY DEFINER function warnings:** inspect each function's body, search_path, EXECUTE grants, caller authorization, tenant scoping and intended exposure. Revoke or redesign only after dependency and access tests.
4. **Leaked-password protection is disabled:** enable after checking current Supabase Auth configuration and impact on signup/password reset.

Performance advisor reports unused indexes. Do not drop them based solely on low/zero observed usage; the database has limited observed activity. Reassess after representative workload and query-plan review.

## 3. Master workstreams and acceptance gates

Statuses below are the baseline at the time of inspection. `Implemented` means there is evidence of code/schema/functionality; it does not imply production verification.

| Programme | Baseline status | Required acceptance evidence |
|---|---|---|
| 1. Product and module audit | In progress | Inventory all nine modules and every workflow; map UI → API/RPC → database → permissions; classify each capability |
| 2. Cloud and infrastructure | Partially evidenced | Verify Vercel, Supabase, DNS, TLS, secrets, staging/production separation, monitoring, backups, restore, capacity and cost |
| 3. Engineering and release quality | Not verified | CI checks, unit/integration/E2E/regression tests, dependency scans, migration reconciliation, preview deployment and rollback |
| 4. Security and compliance | Findings open | Resolve/accept advisor findings with evidence; tenant isolation tests; MFA/session controls; incident response; privacy and data lifecycle controls |
| 5. Nine core modules | Schema and code foundations present; end-to-end status unknown | HR; Finance & Administration; Tasks & Workflow; Document Management; Email & Communication; Calendar; AI Productivity; Reports & Insights; Security & Access each pass real workflows |
| 6. Integrations and AI | Several foundations present; provider readiness unknown | Verified email, OAuth, IntaSend, AI provider, supported APIs, webhook replay/idempotency and failure handling |
| 7. Commercialisation | Billing foundation present; live commerce unverified | Plans/entitlements, real payment verification, renewals, failed payment, cancellation, invoices, tax treatment and subscription state tests |
| 8. Customer experience | Not verified | Public website, trial, onboarding, tutorials, help centre, accessible mobile experience and support channel |
| 9. Legal and corporate governance | Not verified | Entity/IP ownership, customer terms, privacy/data processing terms, vendor terms, applicable Kenyan and target-market obligations |
| 10. Financial sustainability | Not verified | Unit economics, cloud cost per tenant, CAC, MRR/ARR, churn, gross margin, runway and break-even model |
| 11. Sales and customer success | Not started / not evidenced | Pilot recruitment, CRM pipeline, demo process, implementation, support SLAs, retention and referral process |
| 12. Expansion and ecosystem | Deferred | Public API, integrations, developer/partner ecosystem, regional localisation, mobile/low-data strategy and market validation |

## 4. Nine-module verification checklist

For each module, record the specific user roles, happy path, negative path, tenant-boundary test, audit event, data persistence, notification and mobile test.

- [ ] HR Management
- [ ] Finance & Administration
- [ ] Tasks & Workflow
- [ ] Document Management
- [ ] Email & Communication
- [ ] Calendar & Scheduling
- [ ] AI Productivity
- [ ] Reports & Insights
- [ ] Security & Access

## 5. Cloud and production checklist

- [ ] Confirm Vercel project ownership, production branch, build settings and current deployment SHA.
- [ ] Verify custom domain, DNS, TLS, security headers and redirect/canonical URL behaviour.
- [ ] Inventory production and preview environment variables; rotate exposed credentials if any are found.
- [ ] Confirm Supabase production project, region, plan, compute, storage, egress and monthly spend.
- [ ] Establish/verify a separate staging environment and safe test data.
- [ ] Reconcile migration files in Git with the 94 migrations reported in production.
- [ ] Verify backup schedule, retention and independent restore test.
- [ ] Define RPO/RTO and test disaster recovery.
- [ ] Configure uptime, frontend/backend error, database, Edge Function and webhook monitoring.
- [ ] Test deployment rollback and incident communications.
- [ ] Load-test representative tenant and concurrent-user workloads.
- [ ] Review CDN, WAF/DDoS controls, rate limiting and abuse protection where appropriate.
- [ ] Assess data residency, cross-border transfer and contractual requirements before choosing any migration or additional cloud vendor.

## 6. Immediate priority queue

| Priority | Action | Exit condition |
|---|---|---|
| P0 | Triage two policyless social-media tables | Confirm service-only access or implement least-privilege policy; prove client denial |
| P0 | Review SECURITY DEFINER functions and GraphQL exposure | Function-by-function authorization review and tested least-privilege grants |
| P0 | Verify tenant isolation | Automated negative tests across two or more test organisations |
| P1 | Reconcile production migrations and repository | Documented migration parity/drift and safe remediation plan |
| P1 | Verify backup and recovery | Successful restore to isolated environment with recorded RPO/RTO |
| P1 | Verify billing end to end | Provider-confirmed payment, idempotent webhook reconciliation, subscription entitlement update, failure/refund handling |
| P1 | Verify signup, email and invitations | New organisation/admin/user lifecycle succeeds without manual database intervention |
| P1 | Verify AI configuration and safeguards | Authenticated live response, permission/privacy controls, quotas and graceful provider failure |
| P2 | Complete module workflow matrix | Each module has passing acceptance evidence |
| P2 | Customer-facing readiness | Independent customer can register, configure, learn, operate and obtain support |

## 7. Release rules

- Do not make destructive production changes during the audit.
- Do not create duplicate infrastructure or migrate cloud providers without a documented technical and financial case.
- Do not expose service-role or secret keys in browser code, logs or public repositories.
- Do not mark a capability customer-ready based on UI presence or a successful build.
- Every fix must have a reproducible test and, where applicable, production verification.
- Record evidence links, test date, commit/deployment SHA, owner and rollback plan.
- Critical security, tenant-isolation, data-integrity or payment-verification failures block commercial launch.

## 8. Status vocabulary

- **Not started:** No implementation evidence.
- **In progress:** Work underway.
- **Implemented:** Code/schema/configuration exists.
- **Tested:** Defined tests passed in a controlled environment.
- **Production verified:** Real deployed workflow passed with evidence.
- **Customer ready:** Independent customer can use the capability successfully with documentation and support.
- **Blocked / Unknown:** Evidence or dependency is missing; never treat as complete.

**Current decision:** Audit and stabilise. No feature expansion or production infrastructure migration until the baseline and critical risks are understood.
