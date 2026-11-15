# OfficeFlow production source reconciliation — 15 November 2026

## Purpose and safety boundary

This recovery record compares the migration ledger of Supabase project `oghowrilrhummzvrljdt` with migration files tracked on GitHub `enotieno1/officeflow` branch `main`, and restores deployed Edge Function source into Git.

**This is a source-recovery change only.** No SQL migration was applied, no Edge Function was deployed, no production setting or secret was changed, and no existing file on `main` was modified. The recovered Edge Function files below are copied from the currently deployed project source without intentional edits. Treat them as recovered production snapshots, not as approval to redeploy.

## Migration reconciliation

- Supabase migration ledger entries: **100**
- SQL files under `supabase/migrations/` on `main`: **27**
- Exact version-and-name filename matches: **16**
- Same/near-same migration-name candidates with a different version or recorded name: **10**
- Ledger entries with no exact or name-based source candidate in the repository: **74**
- Repository migration files with no exact or name-based ledger candidate: **1**

The simple count difference is 73, but that is not the same as the number of missing SQL sources. 10 files appear to have a related migration name but a different migration version/name in the database ledger; those require SQL-content comparison before they can be reconciled safely.

### Exact filename matches

- `20260922230751_f4_access_path_repair.sql`
- `20260922230848_f1_request_metadata.sql`
- `20260922232940_harden_truncate_privileges.sql`
- `20260922233019_harden_request_approval_sod.sql`
- `20260922233047_enable_workflow_sla_scheduler.sql`
- `20261007010316_performance_indexes_and_rls_initplan_hardening.sql`
- `20261018025834_self_service_organization_onboarding.sql`
- `20261019125640_department_visibility_and_hr_confidentiality.sql`
- `20261019125746_enforce_hr_access_in_workflow_actions.sql`
- `20261019130105_close_legacy_employee_policy_and_hr_document_access.sql`
- `20261019130520_exclude_hr_activity_from_management_aggregates.sql`
- `20261020114716_calendar_events_module.sql`
- `20261020115127_tasks_category_field.sql`
- `20261022160945_organization_employee_invitations.sql`
- `20261022161117_bind_invitation_acceptance_to_invite_id.sql`
- `20261022161637_explicitly_deny_client_invitation_table_access.sql`

### Probable name matches — do not assume equivalence

The filename and database ledger identity differ. Confirm actual SQL content and application history before renaming or changing migration versions.

- Database: `20261004104338_production_auth_profile_and_grant_hardening`; repository candidate: `20261004133700_production_auth_profile_and_grant_hardening.sql`
- Database: `20261004104400_harden_privileged_workflow_rpcs`; repository candidate: `20261004133800_harden_privileged_workflow_rpcs.sql`
- Database: `20261007004446_20261007040000_multidomain_workflow_catalog`; repository candidate: `20261007040000_multidomain_workflow_catalog.sql`
- Database: `20261007010716_automation_actions_and_reliability`; repository candidate: `20261007012000_automation_actions_and_reliability.sql`
- Database: `20261009212256_production_automation_notification_hardening`; repository candidate: `20261010002000_production_automation_notification_hardening.sql`
- Database: `20261020203410_create_secure_payroll_records`; repository candidate: `20261020203000_create_secure_payroll_records.sql`
- Database: `20261023104319_payroll_provider_integration_foundation`; repository candidate: `20261023140000_payroll_provider_integration_foundation.sql`
- Database: `20261026072250_social_media_connections`; repository candidate: `20261026120000_social_media_connections.sql`
- Database: `20261027035650_complete_organization_onboarding`; repository candidate: `20261027070000_complete_organization_onboarding.sql`
- Database: `20261027044950_restore_employee_write_privileges`; repository candidate: `20261027080000_restore_employee_write_privileges.sql`

### Ledger entries without a source candidate

- `20260829002402_consolidated_auth_and_rls.sql`
- `20260829002809_phase_1_5_six_role_model.sql`
- `20260831043846_f23_tenant_isolation.sql`
- `20260901090828_f24_organization_provisioning.sql`
- `20260903043854_fix_profiles_rls_recursion.sql`
- `20260904171951_f2_3b_legacy_table_tenant_isolation.sql`
- `20260913131355_f3_sla_clock_and_escalation.sql`
- `20260922170604_production_fk_indexes_and_anon_hardening.sql`
- `20260922170833_optimize_rls_auth_initplans.sql`
- `20261005125353_grant_usage_private_schema_to_authenticated.sql`
- `20261005130704_production_workflow_control_hardening.sql`
- `20261005130724_workflow_builder_and_control_tower.sql`
- `20261005130911_restrict_control_tower_access.sql`
- `20261005134535_revoke_private_function_execute.sql`
- `20261005135058_in_app_notifications.sql`
- `20261005135116_notification_escalation_hardening.sql`
- `20261005140515_operational_intelligence_control_tower.sql`
- `20261005191417_organizational_units_control_tower.sql`
- `20261005191434_remove_unit_function_overloads.sql`
- `20261005191442_unit_control_tower_wrapper_security.sql`
- `20261005191551_workflow_unit_routing.sql`
- `20261005191620_workflow_builder_wrapper_security.sql`
- `20261005192002_automation_engine_foundation.sql`
- `20261005192447_fix_workflow_rpc_wrappers_and_requests_rls_recursion.sql`
- `20261005192621_restore_fn_profile_context_execute_for_rls.sql`
- `20261005192837_exclude_closed_requests_from_my_work_and_escalation.sql`
- `20261005193106_security_unit_scope_and_overdue_automation.sql`
- `20261005193706_production_hardening_scope_resubmit_escalation_v2.sql`
- `20261005200214_fix_escalation_job_service_role_guard_for_cron.sql`
- `20261005200253_fix_run_automation_workflow_definition_lookup.sql`
- `20261005200320_approvers_can_read_requests_they_decided.sql`
- `20261007004854_20261007050000_general_office_execution_engine.sql`
- `20261019112544_fix_control_tower_unit_attribution_and_age.sql`
- `20261019112626_revoke_truncate_and_anon_from_automation_tables.sql`
- `20261019112637_revoke_truncate_from_notifications.sql`
- `20261019121421_fix_signup_profile_provisioning.sql`
- `20261019133404_allow_assigned_hr_staff_to_view_hr_workflows.sql`
- `20261020091036_secure_intasend_billing.sql`
- `20261020091249_seed_public_billing_plans.sql`
- `20261020091417_deny_client_billing_event_access.sql`
- `20261020092424_atomic_intasend_reconciliation.sql`
- `20261020092522_billing_read_rpc.sql`
- `20261020092809_billing_checkout_reference.sql`
- `20261020093049_restrict_organization_wide_visibility.sql`
- `20261020093118_fix_request_step_policy_recursion.sql`
- `20261020093131_tasks_update_grant.sql`
- `20261020093211_limit_management_visibility_to_admins.sql`
- `20261020093239_task_assignee_security.sql`
- `20261020093347_task_assignment_trigger_fix.sql`
- `20261020093415_enforce_admin_only_management_insights.sql`
- `20261020093512_repair_operational_intelligence_admin_query.sql`
- `20261020093724_private_document_storage.sql`
- `20261020094856_add_fraud_detection_alerts.sql`
- `20261020095652_remove_unenforced_billing_seat_claims.sql`
- `20261020095825_restore_request_policy_helper_grants_and_tenant_scope.sql`
- `20261020101236_revoke_legacy_and_billing_direct_table_access.sql`
- `20261020101357_restore_legacy_reads_until_frontend_release.sql`
- `20261020193749_fix_audit_events_read_grant.sql`
- `20261020203415_restrict_payroll_visibility_to_authorized_roles.sql`
- `20261020205007_enable_hr_attendance_and_leave_records.sql`
- `20261020205137_grant_authenticated_access_to_hr_records.sql`
- `20261020205327_hr_operations_records.sql`
- `20261021103620_risk_intelligence_detection_engine.sql`
- `20261026071404_add_append_only_operational_audit_ledger.sql`
- `20261026072611_mirror_audit_events_and_verify_ledger_integrity.sql`
- `20261026072628_tenant_chain_and_backfill_existing_audit_events.sql`
- `20261026072726_audit_core_operational_table_changes.sql`
- `20261026072744_fix_operational_audit_trigger_return_logic.sql`
- `20261027044017_organization_configuration_foundations.sql`
- `20261028035837_harden_document_rls_and_remove_duplicate_index.sql`
- `20261030190113_enforce_approval_limits_in_decide_step.sql`
- `20261101054458_two_currency_kes_usd.sql`
- `20261101054733_rls_initplan_wrap_and_fk_indexes.sql`
- `20261106103130_ai_foundation_usage_recommendations_timing.sql`

### Repository-only migration file

- `supabase/migrations/20261026100000_platform_admin_workspace.sql`

## Why the missing SQL has not been reconstructed

The Supabase migration-list operation exposes the recorded version and name, not the original SQL body. The live schema is the final accumulated state; it does not reliably reveal the original ordering, intermediate data transformations, grants, policy changes, trigger changes, or one-time backfills.

For that reason, this recovery does **not** create placeholder or guessed SQL files for applied migration versions. Doing so would create a false source-of-truth and could make future migration checks or fresh-environment builds unsafe.

The missing migration bodies must be recovered from a trusted source such as the original Codespace/workstation, developer backups, CI artifacts, prior Git commits/branches, or another retained copy of the migration files. After recovery, compare each body with the production schema and migration ledger before any rename, baseline, or replay plan is approved.

## Recovered deployed Edge Functions

The following deployed functions were retrieved from project `oghowrilrhummzvrljdt` and added to this branch:

| Function | Deployed JWT setting | Recovery note |
|---|---:|---|
| `officeflow-ai` | `verify_jwt: false` | The function performs its own bearer-token validation against Supabase Auth and passes the caller JWT to scoped RPCs. Preserve this setting unless the authentication design is deliberately changed and tested. |
| `billing-checkout` | `verify_jwt: true` | Supabase JWT verification is enabled; source includes authenticated-user and organisation-role checks. |
| `intasend-webhook` | `verify_jwt: false` | Supabase JWT verification is disabled for provider callbacks; the handler performs provider-side verification using configured secrets before reconciliation. |

Only each deployed `index.ts` file was returned by the retrieval operation. No environment secrets or secret values are included in this recovery. Verify required environment variable names and runtime compatibility before any future deployment.

## Validation and remaining work

- [x] Compare the production migration ledger with tracked migration filenames.
- [x] Identify exact matches, probable name matches, missing source candidates and repository-only migration files.
- [x] Retrieve deployed source for the three missing Edge Functions.
- [x] Restore the three Edge Function entrypoints under their standard Supabase folders.
- [ ] Recover the missing migration SQL bodies from a trusted source.
- [ ] Compare all 10 probable migration-name matches at SQL-content level.
- [ ] Explain and resolve the repository-only `platform_admin_workspace` migration.
- [ ] Run Deno type checks/lint and review the recovered functions.
- [ ] Build a clean local database from the recovered migration history and compare it with production.
- [ ] Obtain review approval before merging or deploying anything.

**Do not run `supabase db push`, `supabase migration repair`, `supabase db reset`, or deploy these functions as part of this recovery PR.** Those are separate operations requiring their own review and explicit approval.
