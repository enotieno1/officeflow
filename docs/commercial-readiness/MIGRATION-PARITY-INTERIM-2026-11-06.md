# OfficeFlow production migration parity — interim register

**Review date:** 6 November 2026  
**Production project:** `oghowrilrhummzvrljdt`  
**Scope:** Read-only comparison of the production migration ledger with GitHub migration directories and Git history.  
**Safety:** No production migration, schema change, migration-history repair, or file restoration was performed.

## Executive result

- Production migration ledger: **99 applied records**.
- Current `main` migration directory: **27 SQL files**.
- Unique SQL migration filenames located across the inspected refs: **48**.
- Production versions with an exact version-prefixed filename in inspected refs: **19**.
- Additional production versions with a plausible alternate-timestamp / historical source filename: **22**.
- Production versions for which no filename-level source was located in inspected refs: **58**.

The “candidate source” category is **not yet proof of equivalence**. The production ledger records version/name, not the original SQL body. A file with a similar name or purpose must be compared against deployment evidence, schema effects and commit history before being accepted as the source for a production version. “Not located” does not prove the migration was manually applied or irretrievably lost; this review did not inspect every historical branch or external developer backup.

## Important findings

1. Some migrations exist only on feature branches. The `feat/secure-intasend-billing` branch contains billing and task-related SQL sources absent from `main`.
2. Two SQL files were deliberately removed from `main` in commits titled “Remove unreviewed billing migration from default branch” and “Remove unreviewed task trigger migration from default branch”. Their historical versions remain in `feat/secure-intasend-billing`:
   - `20261020143000_atomic_intasend_reconciliation.sql` is a candidate for production version `20261020092424`.
   - `20261020161000_task_assignment_trigger_fix.sql` is a candidate for production version `20261020093347`.
   Do not restore or apply either until its exact SQL is reviewed and its production effects are verified.
3. The old `20261004134000_production_auth_profile_hardening.sql` appears in a historical branch/commit, but is not a production ledger version in the current 99-record list. The deployment runbook says it was superseded and unapplied; keep it excluded unless contrary evidence is found.
4. Several source filenames have different timestamps from their production ledger versions. These are marked as candidates, not silently treated as exact matches.
5. The repository's migration history must not be “fixed” by fabricating empty SQL files, renaming files blindly, rerunning DDL, or using `migration repair` without a version-by-version reviewed plan.

## Version-by-version production ledger

| Production version | Production ledger name | Source status | Candidate/source file |
|---|---|---|---|
| 20260829002402 | `consolidated_auth_and_rls` | Source not located in inspected refs | — |
| 20260829002809 | `phase_1_5_six_role_model` | Source not located in inspected refs | — |
| 20260831043846 | `f23_tenant_isolation` | Source not located in inspected refs | — |
| 20260901090828 | `f24_organization_provisioning` | Source not located in inspected refs | — |
| 20260903043854 | `fix_profiles_rls_recursion` | Source not located in inspected refs | — |
| 20260904171951 | `f2_3b_legacy_table_tenant_isolation` | Source not located in inspected refs | — |
| 20260913131355 | `f3_sla_clock_and_escalation` | Source not located in inspected refs | — |
| 20260922170604 | `production_fk_indexes_and_anon_hardening` | Source not located in inspected refs | — |
| 20260922170833 | `optimize_rls_auth_initplans` | Source not located in inspected refs | — |
| 20260922230751 | `f4_access_path_repair` | Exact filename | `20260922230751_f4_access_path_repair.sql` |
| 20260922230848 | `f1_request_metadata` | Exact filename | `20260922230848_f1_request_metadata.sql` |
| 20260922232940 | `harden_truncate_privileges` | Exact filename | `20260922232940_harden_truncate_privileges.sql` |
| 20260922233019 | `harden_request_approval_sod` | Exact filename | `20260922233019_harden_request_approval_sod.sql` |
| 20260922233047 | `enable_workflow_sla_scheduler` | Exact filename | `20260922233047_enable_workflow_sla_scheduler.sql` |
| 20261004104338 | `production_auth_profile_and_grant_hardening` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261004133700_production_auth_profile_and_grant_hardening.sql` |
| 20261004104400 | `harden_privileged_workflow_rpcs` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261004133800_harden_privileged_workflow_rpcs.sql` |
| 20261005125353 | `grant_usage_private_schema_to_authenticated` | Source not located in inspected refs | — |
| 20261005130704 | `production_workflow_control_hardening` | Source not located in inspected refs | — |
| 20261005130724 | `workflow_builder_and_control_tower` | Source not located in inspected refs | — |
| 20261005130911 | `restrict_control_tower_access` | Source not located in inspected refs | — |
| 20261005134535 | `revoke_private_function_execute` | Source not located in inspected refs | — |
| 20261005135058 | `in_app_notifications` | Source not located in inspected refs | — |
| 20261005135116 | `notification_escalation_hardening` | Source not located in inspected refs | — |
| 20261005140515 | `operational_intelligence_control_tower` | Source not located in inspected refs | — |
| 20261005191417 | `organizational_units_control_tower` | Source not located in inspected refs | — |
| 20261005191434 | `remove_unit_function_overloads` | Source not located in inspected refs | — |
| 20261005191442 | `unit_control_tower_wrapper_security` | Source not located in inspected refs | — |
| 20261005191551 | `workflow_unit_routing` | Source not located in inspected refs | — |
| 20261005191620 | `workflow_builder_wrapper_security` | Source not located in inspected refs | — |
| 20261005192002 | `automation_engine_foundation` | Source not located in inspected refs | — |
| 20261005192447 | `fix_workflow_rpc_wrappers_and_requests_rls_recursion` | Source not located in inspected refs | — |
| 20261005192621 | `restore_fn_profile_context_execute_for_rls` | Source not located in inspected refs | — |
| 20261005192837 | `exclude_closed_requests_from_my_work_and_escalation` | Source not located in inspected refs | — |
| 20261005193106 | `security_unit_scope_and_overdue_automation` | Source not located in inspected refs | — |
| 20261005193706 | `production_hardening_scope_resubmit_escalation_v2` | Source not located in inspected refs | — |
| 20261005200214 | `fix_escalation_job_service_role_guard_for_cron` | Source not located in inspected refs | — |
| 20261005200253 | `fix_run_automation_workflow_definition_lookup` | Source not located in inspected refs | — |
| 20261005200320 | `approvers_can_read_requests_they_decided` | Source not located in inspected refs | — |
| 20261007004446 | `20261007040000_multidomain_workflow_catalog` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261007040000_multidomain_workflow_catalog.sql` |
| 20261007004854 | `20261007050000_general_office_execution_engine` | Source not located in inspected refs | — |
| 20261007010316 | `performance_indexes_and_rls_initplan_hardening` | Exact filename | `20261007010316_performance_indexes_and_rls_initplan_hardening.sql` |
| 20261007010716 | `automation_actions_and_reliability` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261007012000_automation_actions_and_reliability.sql` |
| 20261009212256 | `production_automation_notification_hardening` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261010002000_production_automation_notification_hardening.sql` |
| 20261018025834 | `self_service_organization_onboarding` | Exact filename | `20261018025834_self_service_organization_onboarding.sql` |
| 20261019112544 | `fix_control_tower_unit_attribution_and_age` | Source not located in inspected refs | — |
| 20261019112626 | `revoke_truncate_and_anon_from_automation_tables` | Source not located in inspected refs | — |
| 20261019112637 | `revoke_truncate_from_notifications` | Source not located in inspected refs | — |
| 20261019121421 | `fix_signup_profile_provisioning` | Source not located in inspected refs | — |
| 20261019125640 | `department_visibility_and_hr_confidentiality` | Exact filename | `20261019125640_department_visibility_and_hr_confidentiality.sql` |
| 20261019125746 | `enforce_hr_access_in_workflow_actions` | Exact filename | `20261019125746_enforce_hr_access_in_workflow_actions.sql` |
| 20261019130105 | `close_legacy_employee_policy_and_hr_document_access` | Exact filename | `20261019130105_close_legacy_employee_policy_and_hr_document_access.sql` |
| 20261019130520 | `exclude_hr_activity_from_management_aggregates` | Exact filename | `20261019130520_exclude_hr_activity_from_management_aggregates.sql` |
| 20261019133404 | `allow_assigned_hr_staff_to_view_hr_workflows` | Source not located in inspected refs | — |
| 20261020091036 | `secure_intasend_billing` | Exact filename | `20261020091036_secure_intasend_billing.sql` |
| 20261020091249 | `seed_public_billing_plans` | Exact filename | `20261020091249_seed_public_billing_plans.sql` |
| 20261020091417 | `deny_client_billing_event_access` | Exact filename | `20261020091417_deny_client_billing_event_access.sql` |
| 20261020092424 | `atomic_intasend_reconciliation` | Candidate source — Historical feature branch; deleted from main | `20261020143000_atomic_intasend_reconciliation.sql` |
| 20261020092522 | `billing_read_rpc` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020144500_billing_read_rpc.sql` |
| 20261020092809 | `billing_checkout_reference` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020150000_billing_checkout_reference.sql` |
| 20261020093049 | `restrict_organization_wide_visibility` | Source not located in inspected refs | — |
| 20261020093118 | `fix_request_step_policy_recursion` | Source not located in inspected refs | — |
| 20261020093131 | `tasks_update_grant` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020153000_tasks_update_grant.sql` |
| 20261020093211 | `limit_management_visibility_to_admins` | Source not located in inspected refs | — |
| 20261020093239 | `task_assignee_security` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020160000_task_assignee_security.sql` |
| 20261020093347 | `task_assignment_trigger_fix` | Candidate source — Historical feature branch; deleted from main | `20261020161000_task_assignment_trigger_fix.sql` |
| 20261020093415 | `enforce_admin_only_management_insights` | Source not located in inspected refs | — |
| 20261020093512 | `repair_operational_intelligence_admin_query` | Source not located in inspected refs | — |
| 20261020093724 | `private_document_storage` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020170000_private_document_storage.sql` |
| 20261020094856 | `add_fraud_detection_alerts` | Source not located in inspected refs | — |
| 20261020095652 | `remove_unenforced_billing_seat_claims` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020180000_remove_unenforced_billing_seat_claims.sql` |
| 20261020095825 | `restore_request_policy_helper_grants_and_tenant_scope` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020182000_restore_request_policy_helper_grants_and_tenant_scope.sql` |
| 20261020101236 | `revoke_legacy_and_billing_direct_table_access` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020190000_revoke_legacy_and_billing_direct_table_access.sql` |
| 20261020101357 | `restore_legacy_reads_until_frontend_release` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020193000_restore_legacy_reads_until_frontend_release.sql` |
| 20261020114716 | `calendar_events_module` | Exact filename | `20261020114716_calendar_events_module.sql` |
| 20261020115127 | `tasks_category_field` | Exact filename | `20261020115127_tasks_category_field.sql` |
| 20261020193749 | `fix_audit_events_read_grant` | Source not located in inspected refs | — |
| 20261020203410 | `create_secure_payroll_records` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261020203000_create_secure_payroll_records.sql` |
| 20261020203415 | `restrict_payroll_visibility_to_authorized_roles` | Source not located in inspected refs | — |
| 20261020205007 | `enable_hr_attendance_and_leave_records` | Source not located in inspected refs | — |
| 20261020205137 | `grant_authenticated_access_to_hr_records` | Source not located in inspected refs | — |
| 20261020205327 | `hr_operations_records` | Source not located in inspected refs | — |
| 20261021103620 | `risk_intelligence_detection_engine` | Source not located in inspected refs | — |
| 20261022160945 | `organization_employee_invitations` | Exact filename | `20261022160945_organization_employee_invitations.sql` |
| 20261022161117 | `bind_invitation_acceptance_to_invite_id` | Exact filename | `20261022161117_bind_invitation_acceptance_to_invite_id.sql` |
| 20261022161637 | `explicitly_deny_client_invitation_table_access` | Exact filename | `20261022161637_explicitly_deny_client_invitation_table_access.sql` |
| 20261023104319 | `payroll_provider_integration_foundation` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261023140000_payroll_provider_integration_foundation.sql` |
| 20261026071404 | `add_append_only_operational_audit_ledger` | Source not located in inspected refs | — |
| 20261026072250 | `social_media_connections` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261026120000_social_media_connections.sql` |
| 20261026072611 | `mirror_audit_events_and_verify_ledger_integrity` | Source not located in inspected refs | — |
| 20261026072628 | `tenant_chain_and_backfill_existing_audit_events` | Source not located in inspected refs | — |
| 20261026072726 | `audit_core_operational_table_changes` | Source not located in inspected refs | — |
| 20261026072744 | `fix_operational_audit_trigger_return_logic` | Source not located in inspected refs | — |
| 20261027035650 | `complete_organization_onboarding` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261027070000_complete_organization_onboarding.sql` |
| 20261027044017 | `organization_configuration_foundations` | Source not located in inspected refs | — |
| 20261027044950 | `restore_employee_write_privileges` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261027080000_restore_employee_write_privileges.sql` |
| 20261028035837 | `harden_document_rls_and_remove_duplicate_index` | Candidate source — Timestamp/name mismatch; verify SQL equivalence | `20261028110000_harden_document_rls_and_remove_duplicate_index.sql` |
| 20261030190113 | `enforce_approval_limits_in_decide_step` | Source not located in inspected refs | — |
| 20261101054458 | `two_currency_kes_usd` | Source not located in inspected refs | — |
| 20261101054733 | `rls_initplan_wrap_and_fk_indexes` | Source not located in inspected refs | — |

## Inspected Git refs

- `main`
- `feat/secure-intasend-billing`
- `fix/officeflow-audit-remediation`
- `feat/org-wide-fraud-intelligence-v2`
- `feature/organization-identity-workspace-control`
- `fix/idle-timeout-and-tenant-security-audit`
- `feat/africa-readiness-architecture`
- `feat/whatsapp-credit-readiness-foundation`
- Additional branch directory spot-checks: `chore/sync-onboarding-migration-history`, `feature/calendar-events-module`, `feature/complete-module-navigation`, `feature/department-directory-hr-privacy`, `feat/customer-platform-admin-separation`, `feature/expanded-hr-workspace`, `feature/session-expiry`, `feature/department-specific-login-portals`, `fix/audit-document-policy-overlap`, `fix/task-management-real-data`, `fix/task-management-two-axis-scroll`, and others.

## Recommended remediation sequence

1. Preserve a read-only snapshot of the current production migration ledger and schema state.
2. For every candidate source, compare the SQL file content, historical commit diff, production schema objects and deployment timeline. Record equivalence only with evidence.
3. Search remaining historical branches, PR patches, developer backups and deployment logs for the 58 unlocated sources.
4. Build a source-to-production map with explicit statuses: exact, equivalent after review, superseded, intentionally omitted, or unrecovered.
5. Reconstruct a reproducible baseline in a disposable/staging database from reviewed source files; compare schema, functions, policies, grants, triggers, extensions and scheduled jobs with production.
6. Only after independent review, choose a safe forward-only baseline/history-reconciliation strategy. Do not replay historical migrations into production.
7. Add CI checks that compare migration ledger and repository history and block production deployment on unexplained drift.

## Release gate

**Status: BLOCKED — migration provenance not yet fully reconciled.**  
The production database is active, but the repository cannot yet be treated as a complete, reproducible record of its database evolution. No production write is authorised by this report.
