# OfficeFlow Feature Verification Matrix
**Audit date:** 2026-10-19  
**Production project:** `oghowrilrhummzvrljdt`

Status values: **PASS** means the stated SQL invariant passed; **PARTIAL** means some structural evidence exists but end-to-end behavior is not verified; **NOT RUN** means no suitable test was run; **GAP** means the required capability was not found in the inspected schema.

| ID | Capability / test | Status | Evidence / next test |
|---|---|---|---|
| DB-01 | RLS enabled on every public table (including partitioned tables) | PASS | Read-only production SQL, T01 |
| DB-02 | Every RLS table has a policy | PASS | Read-only production SQL, T02; policy correctness requires separate test |
| DB-03 | anon cannot execute public functions | PASS | T03 |
| DB-04 | anon has no listed public table grants | PASS | T04 |
| DB-05 | authenticated lacks TRUNCATE/REFERENCES/TRIGGER table grants | PASS | T04b |
| DB-06 | every non-organization public table has organization_id | PASS | T05 |
| DB-07 | organization_id columns are NOT NULL | PASS | T06 and strengthened T16 |
| DB-08 | authenticated cannot directly mutate audit_events | PASS | T07 |
| DB-09 | authenticated cannot directly mutate requests/request_steps | PASS | T08 |
| DB-10 | escalation RPC callable only by service_role | PASS | T09 |
| DB-11 | profile roles restricted to six approved non-null values | PASS | T10 and T17 |
| DB-12 | no profile/request rows lack organization | PASS | T11 |
| DB-13 | SLA cron job active | PASS | T12 |
| DB-14 | request step organization matches parent request | PASS | strengthened NULL-safe T13 |
| DB-15 | max one pending request step with due_at per request | PASS | T14 |
| DB-16 | effective anon table privileges are absent | PASS | strengthened T15 |
| AUTH-01 | sign-up and profile provision in fresh browser | NOT RUN | Browser test with new controlled account |
| AUTH-02 | session refresh/expiry/sign-out | NOT RUN | Test all protected pages with expired session |
| AUTH-03 | package selection protected by Supabase session, not localStorage flag | PARTIAL / ISSUE | `dashboard/package-selection.html` begins with localStorage guard |
| ORG-01 | self-service organization creation RPC exists | PARTIAL | `fn_create_organization_for_current_user`; end-to-end test required |
| ORG-02 | second tenant cannot read/write first tenant data | NOT RUN in this audit | Run separate authenticated identity tests; do not infer from RLS enabled |
| WF-01 | workflow definitions, versions and steps exist | PARTIAL | Schema and RPCs present |
| WF-02 | request submit/approve/reject/return/cancel/resubmit | PARTIAL | RPCs and UI present; full role-separated browser test not run |
| WF-03 | immutable in-flight workflow version | NOT RUN | Publish new version while old request pending |
| SLA-01 | scheduler configured active | PASS | T12 |
| SLA-02 | actual overdue step escalates exactly once | NOT RUN in this audit | Staging fixture and cron/job history |
| AUTO-01 | automation rules/runs schema and RPCs exist | PARTIAL | Current production counts: 0 rules, 0 runs |
| AUTO-02 | automation action reliability and duplicate protection | NOT RUN end-to-end | Test each action and forced failure |
| HR-01 | employee records | PARTIAL | `employees` table exists; full CRUD/security test absent |
| HR-02 | leave/onboarding/transfer/attendance lifecycle | PARTIAL | Workflow catalog evidence; complete operational test absent |
| FIN-01 | transaction register | PARTIAL | `transactions` table exists; not a complete accounting ledger |
| FIN-02 | finance workflow page provides integrated live operations | PARTIAL / ISSUE | `financial-management.html` redirects to `operational-module.html?category=Finance`; separate accountant portal uses hard-coded sample records. PR #7 removed false success responses for non-persistent invoice/expense creation and bill payment, but persistent finance operations remain unimplemented. |
| PROC-01 | supplier/quotation/PO/receipt lifecycle | UNKNOWN / GAP | Dedicated data tables not found in inspected public schema |
| TASK-01 | task create/assign/update/complete lifecycle | PARTIAL | `tasks` table and automation create-task action; UI lifecycle not verified |
| DOC-01 | document metadata register | PARTIAL | `documents` table and read-only register page |
| DOC-02 | secure upload/download/version/retention | NOT RUN / UNKNOWN | Storage bucket and full lifecycle not verified |
| NOTIF-01 | in-app notifications and mark read | PARTIAL | RPCs exist; 4 rows at snapshot; event coverage not end-to-end tested |
| EMAIL-01 | email delivery | NOT RUN / BLOCKED | outbox exists; 0 queued rows at snapshot; sender/provider delivery not demonstrated |
| CT-01 | Control Tower data accuracy | PARTIAL | RPCs/pages and latest unit-attribution migration exist; KPI-to-SQL reconciliation not run |
| BILL-01 | subscriptions/payment collection | GAP / SAFETY ISSUE | No subscription/payment/billing tables found in inspected public schema. Baseline package-selection UI simulated payment success and logged card/CVV-bearing purchase data; remediation PR #6 disables this UI and removes credential handling. |
| INT-01 | external integrations and SSO | BLOCKED / UNKNOWN | Credentials/provider setup and successful external calls not verified |
| MOB-01 | responsive layouts | PARTIAL | mobile.css linked on key pages; no viewport/accessibility suite run |
| PILOT-01 | sustained real organization use | NOT RUN | Requires pilot users and agreed success measures |

## Production snapshot (read-only; 2026-10-19)

| Table | Rows |
|---|---:|
| organizations | 1 |
| profiles | 3 |
| workflow_definitions | 9 |
| requests | 2 |
| request_steps | 3 |
| notifications | 4 |
| automation_rules | 0 |
| automation_runs | 0 |
| email_outbox | 0 |

These counts are not a user-quality measure. They indicate that automation/email and pilot evidence should be generated in controlled tests rather than inferred from existing production activity.

## Security advisor
Supabase's security advisor reported 15 objects visible in the GraphQL schema to authenticated users. This is an advisory requiring object-by-object intended-exposure and RLS/grant validation. It is not proof of cross-tenant data access. Re-run advisors after remediation and document any intentionally exposed objects.
