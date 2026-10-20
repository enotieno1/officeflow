-- Read-only billing security regression checks. Run after migration; each row should pass.
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
select 'BILL-T04 published prices match existing pricing page' as test, (select amount=10000 and seat_limit=10 and is_active from public.billing_plans where id='starter_monthly') and (select amount=40000 and seat_limit=50 and is_active from public.billing_plans where id='professional_monthly') and not exists (select 1 from public.billing_plans where id='enterprise_monthly') as pass;
select 'BILL-T05 active plans only readable' as test, exists (
 select 1 from pg_policies where schemaname='public' and tablename='billing_plans'
 and policyname='billing_plans_read_active' and qual like '%is_active%') as pass;
