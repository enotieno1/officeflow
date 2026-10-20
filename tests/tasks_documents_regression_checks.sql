-- Read-only regression checks for task CRUD/assignment and private document storage.
select 'TASK-T01 RLS enabled' as test, c.relrowsecurity as pass
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname='tasks';
select 'TASK-T02 assignment user ID column exists' as test,
 exists(select 1 from information_schema.columns where table_schema='public' and table_name='tasks' and column_name='assigned_to_user_id') as pass;
select 'TASK-T03 authenticated update grant exists' as test,
 has_table_privilege('authenticated','public.tasks','UPDATE') as pass;
select 'TASK-T04 four scoped task policies exist' as test,
 (select count(*)=4 from pg_policies where schemaname='public' and tablename='tasks'
  and policyname in ('tasks_read_owner_assignee_or_admin','tasks_insert_owner_or_admin','tasks_update_owner_assignee_or_admin','tasks_delete_owner_or_admin')) as pass;
select 'TASK-T05 assignee list RPC is authenticated-only' as test,
 has_function_privilege('authenticated','public.fn_list_task_assignees()','EXECUTE')
 and not has_function_privilege('anon','public.fn_list_task_assignees()','EXECUTE') as pass;
select 'TASK-T06 assignment trigger installed' as test,
 exists(select 1 from information_schema.triggers where event_object_schema='public' and event_object_table='tasks' and trigger_name='tasks_validate_assignment') as pass;
select 'DOC-T01 private bucket exists' as test,
 exists(select 1 from storage.buckets where id='officeflow-documents' and public=false and file_size_limit=10485760) as pass;
select 'DOC-T02 authenticated metadata insert/delete grants exist' as test,
 has_table_privilege('authenticated','public.documents','INSERT')
 and has_table_privilege('authenticated','public.documents','DELETE') as pass;
select 'DOC-T03 owner-scoped metadata insert policy exists' as test,
 exists(select 1 from pg_policies where schemaname='public' and tablename='documents' and policyname='documents_insert_owner' and cmd='INSERT') as pass;
select 'DOC-T04 three private storage policies exist' as test,
 (select count(*)=3 from pg_policies where schemaname='storage' and tablename='objects'
  and policyname in ('officeflow_documents_read_scoped','officeflow_documents_insert_owner','officeflow_documents_delete_scoped')) as pass;
select 'DOC-T05 no public storage policy for OfficeFlow bucket' as test,
 not exists(select 1 from pg_policies where schemaname='storage' and tablename='objects'
  and roles::text like '%anon%' and (coalesce(qual,'') like '%officeflow-documents%' or coalesce(with_check,'') like '%officeflow-documents%')) as pass;
