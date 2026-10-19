-- OfficeFlow regression checks — READ ONLY.
-- Run in the Supabase SQL editor or via MCP against the intended project.
-- These checks validate catalog/data invariants, not full browser behavior.
-- Audit run: 2026-10-19; 17/17 checks passed against project oghowrilrhummzvrljdt.
WITH checks AS (
 SELECT 'T01 every public table has RLS enabled (including partitioned tables)' name,
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND NOT c.relrowsecurity)=0 pass
 UNION ALL SELECT 'T02 every RLS table has at least one policy',
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND c.relrowsecurity
      AND NOT EXISTS(SELECT 1 FROM pg_policy p WHERE p.polrelid=c.oid))=0
 UNION ALL SELECT 'T03 anon cannot execute any public function',
   (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND has_function_privilege('anon',p.oid,'execute'))=0
 UNION ALL SELECT 'T04 anon has no explicit public table grants',
   (SELECT count(*) FROM information_schema.role_table_grants
    WHERE table_schema='public' AND grantee='anon')=0
 UNION ALL SELECT 'T04b authenticated has no TRUNCATE/REFERENCES/TRIGGER table grants',
   (SELECT count(*) FROM information_schema.role_table_grants
    WHERE table_schema='public' AND grantee='authenticated'
      AND privilege_type IN ('TRUNCATE','REFERENCES','TRIGGER'))=0
 UNION ALL SELECT 'T05 every business table has organization_id (except organizations)',
   (SELECT count(*) FROM information_schema.tables t
    WHERE t.table_schema='public' AND t.table_type='BASE TABLE' AND t.table_name<>'organizations'
      AND NOT EXISTS(SELECT 1 FROM information_schema.columns c
        WHERE c.table_schema=t.table_schema AND c.table_name=t.table_name AND c.column_name='organization_id'))=0
 UNION ALL SELECT 'T06 no public organization_id column is nullable',
   (SELECT count(*) FROM information_schema.columns
    WHERE table_schema='public' AND column_name='organization_id' AND is_nullable='YES')=0
 UNION ALL SELECT 'T07 authenticated cannot modify audit_events directly',
   (SELECT count(*) FROM information_schema.role_table_grants
    WHERE table_schema='public' AND table_name='audit_events' AND grantee='authenticated'
      AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))=0
 UNION ALL SELECT 'T08 authenticated cannot write requests/request_steps directly',
   (SELECT count(*) FROM information_schema.role_table_grants
    WHERE table_schema='public' AND table_name IN ('requests','request_steps') AND grantee='authenticated'
      AND privilege_type IN ('INSERT','UPDATE','DELETE','TRUNCATE'))=0
 UNION ALL SELECT 'T09 escalation function callable only by service_role',
   has_function_privilege('service_role','public.fn_escalate_overdue_steps()','execute')
   AND NOT has_function_privilege('authenticated','public.fn_escalate_overdue_steps()','execute')
   AND NOT has_function_privilege('anon','public.fn_escalate_overdue_steps()','execute')
 UNION ALL SELECT 'T10 profiles use only six approved non-null roles',
   (SELECT count(*) FROM public.profiles WHERE role IS NULL
     OR role NOT IN ('employee','officer','manager','administrator','auditor','super_admin'))=0
 UNION ALL SELECT 'T11 no profile/request row lacks an organization',
   (SELECT count(*) FROM public.profiles WHERE organization_id IS NULL)
   +(SELECT count(*) FROM public.requests WHERE organization_id IS NULL)=0
 UNION ALL SELECT 'T12 SLA escalation cron job active',
   EXISTS(SELECT 1 FROM cron.job WHERE jobname='officeflow_escalate_overdue_steps' AND active)
 UNION ALL SELECT 'T13 request_steps organization matches parent request (NULL-safe)',
   (SELECT count(*) FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id
    WHERE rs.organization_id IS DISTINCT FROM r.organization_id)=0
 UNION ALL SELECT 'T14 at most one pending SLA clock per request',
   (SELECT count(*) FROM (
     SELECT request_id FROM public.request_steps
     WHERE status='pending' AND due_at IS NOT NULL GROUP BY request_id HAVING count(*)>1
   ) s)=0
 UNION ALL SELECT 'T15 effective anon privileges absent for all public tables',
   (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relkind IN ('r','p') AND (
      has_table_privilege('anon',c.oid,'SELECT') OR has_table_privilege('anon',c.oid,'INSERT')
      OR has_table_privilege('anon',c.oid,'UPDATE') OR has_table_privilege('anon',c.oid,'DELETE')
      OR has_table_privilege('anon',c.oid,'TRUNCATE') OR has_table_privilege('anon',c.oid,'REFERENCES')
      OR has_table_privilege('anon',c.oid,'TRIGGER')))=0
 UNION ALL SELECT 'T16 every non-organization public table has NOT NULL organization_id',
   (SELECT count(*) FROM information_schema.tables t
    WHERE t.table_schema='public' AND t.table_type='BASE TABLE' AND t.table_name<>'organizations'
      AND NOT EXISTS(SELECT 1 FROM information_schema.columns c
        WHERE c.table_schema=t.table_schema AND c.table_name=t.table_name
          AND c.column_name='organization_id' AND c.is_nullable='NO'))=0
 UNION ALL SELECT 'T17 no profile role is NULL',
   (SELECT count(*) FROM public.profiles WHERE role IS NULL)=0
)
SELECT name, CASE WHEN pass THEN 'PASS' ELSE 'FAIL' END AS result
FROM checks ORDER BY name;

-- Important limitations:
-- 1. At least one RLS policy does not prove the policy is correct.
-- 2. Privilege checks do not replace cross-tenant authenticated tests.
-- 3. The cron existence check does not prove recent successful execution.
-- 4. This script does not test UI, email delivery, payment, or onboarding end-to-end.
