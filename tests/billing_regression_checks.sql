-- Read-only billing security regression checks. Every row should pass.
select 'BILL-T01 RLS enabled' as test, bool_and(c.relrowsecurity) as pass
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('billing_plans','billing_subscriptions','billing_payment_attempts','billing_provider_events');
select 'BILL-T02 anon has no table privileges' as test, not exists (
 select 1 from information_schema.role_table_grants where grantee='anon' and table_schema='public'
 and table_name in ('billing_plans','billing_subscriptions','billing_payment_attempts','billing_provider_events')
 and privilege_type in ('SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER')) as pass;
select 'BILL-T03 clients cannot mutate billing state' as test,
 not has_table_privilege('authenticated','public.billing_payment_attempts','INSERT')
 and not has_table_privilege('authenticated','public.billing_payment_attempts','UPDATE')
 and not has_table_privilege('authenticated','public.billing_subscriptions','INSERT')
 and not has_table_privilege('authenticated','public.billing_subscriptions','UPDATE') as pass;
select 'BILL-T04 published prices match existing pricing page' as test,
 (select amount=10000 and seat_limit=10 and is_active from public.billing_plans where id='starter_monthly')
 and (select amount=40000 and seat_limit=50 and is_active from public.billing_plans where id='professional_monthly')
 and not exists (select 1 from public.billing_plans where id='enterprise_monthly') as pass;
select 'BILL-T05 no direct authenticated billing table reads' as test,
 not has_table_privilege('authenticated','public.billing_plans','SELECT')
 and not has_table_privilege('authenticated','public.billing_subscriptions','SELECT')
 and not has_table_privilege('authenticated','public.billing_payment_attempts','SELECT') as pass;
select 'BILL-T06 scoped overview RPC is authenticated-only' as test,
 has_function_privilege('authenticated','public.fn_get_billing_overview()','EXECUTE')
 and not has_function_privilege('anon','public.fn_get_billing_overview()','EXECUTE')
 and not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace cross join lateral aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) a where n.nspname='public' and p.proname='fn_get_billing_overview' and a.grantee=0 and a.privilege_type='EXECUTE') as pass;
select 'BILL-T07 reconciliation RPC is service-role-only' as test,
 has_function_privilege('service_role','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE')
 and not has_function_privilege('authenticated','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE')
 and not has_function_privilege('anon','public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text)','EXECUTE') as pass;

select 'BILL-T08 hosted checkout ID is distinct from invoice ID' as test,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='billing_payment_attempts' and column_name='provider_checkout_id')
 and exists(select 1 from information_schema.columns where table_schema='public' and table_name='billing_payment_attempts' and column_name='provider_invoice_id') as pass;
