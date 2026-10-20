-- Run in staging after applying 20261020210000_intasend_recurring_card_subscriptions.sql.
select 'REC-01 provider subscription mapping is unique' as test,
  exists (select 1 from pg_indexes where schemaname='public'
    and indexname='billing_subscriptions_provider_subscription_id_key') as pass
union all
select 'REC-02 recurring subscription columns exist',
  (select count(*)=7 from information_schema.columns where table_schema='public'
    and table_name='billing_subscriptions' and column_name in (
      'provider_customer_id','provider_plan_id','provider_setup_url',
      'provider_subscription_status','next_billing_at',
      'provider_subscription_failure_reason','completed_cycles'))
union all
select 'REC-03 provider event supports status-only subscription events',
  exists (select 1 from information_schema.columns where table_schema='public'
    and table_name='billing_provider_events' and column_name='provider_subscription_id')
  and exists (select 1 from information_schema.columns where table_schema='public'
    and table_name='billing_provider_events' and column_name='provider_invoice_id' and is_nullable='YES')
union all
select 'REC-04 payment reconciliation is service-role-only',
  has_function_privilege('service_role','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE')
  and not has_function_privilege('authenticated','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE')
  and not has_function_privilege('anon','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE')
union all
select 'REC-05 subscription status sync is service-role-only',
  has_function_privilege('service_role','public.fn_sync_intasend_subscription_status(text,text,text,text,date,integer,text)','EXECUTE')
  and not has_function_privilege('authenticated','public.fn_sync_intasend_subscription_status(text,text,text,text,date,integer,text)','EXECUTE')
  and not has_function_privilege('anon','public.fn_sync_intasend_subscription_status(text,text,text,text,date,integer,text)','EXECUTE')
union all
select 'REC-06 billing rows are not directly readable by clients',
  not has_table_privilege('authenticated','public.billing_subscriptions','SELECT')
  and not has_table_privilege('authenticated','public.billing_payment_attempts','SELECT')
  and not has_table_privilege('anon','public.billing_subscriptions','SELECT')
  and not has_table_privilege('anon','public.billing_payment_attempts','SELECT')
union all
select 'REC-07 billing overview RPC remains available only to authenticated users',
  has_function_privilege('authenticated','public.fn_get_billing_overview()','EXECUTE')
  and not has_function_privilege('anon','public.fn_get_billing_overview()','EXECUTE');
