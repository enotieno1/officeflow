-- Run after the frontend release and after applying
-- 20261020200000_revoke_legacy_module_table_access_after_frontend_release.sql.
select 'PRIV-01 no direct SELECT on legacy HR/finance/fraud tables' as test,
  not has_table_privilege('authenticated','public.employees','SELECT')
  and not has_table_privilege('authenticated','public.transactions','SELECT')
  and not has_table_privilege('authenticated','public.fraud_alerts','SELECT') as pass
union all
select 'PRIV-02 no direct SELECT on billing records',
  not has_table_privilege('authenticated','public.billing_plans','SELECT')
  and not has_table_privilege('authenticated','public.billing_subscriptions','SELECT')
  and not has_table_privilege('authenticated','public.billing_payment_attempts','SELECT')
  and not has_table_privilege('authenticated','public.billing_provider_events','SELECT')
union all
select 'PRIV-03 organization and audit tables are RPC-only',
  not has_table_privilege('authenticated','public.organizations','SELECT')
  and not has_table_privilege('authenticated','public.audit_events','SELECT')
union all
select 'PRIV-04 billing overview remains available to authenticated admins',
  has_function_privilege('authenticated','public.fn_get_billing_overview()','EXECUTE')
  and not has_function_privilege('anon','public.fn_get_billing_overview()','EXECUTE');
