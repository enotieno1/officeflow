-- OfficeFlow request-detail authorization regression checks.
-- Structural checks are read-only. The transaction-based role test below is run separately
-- against a dedicated staging environment because it requires a test identity.
select 'REQ-01 approver predicate is executable by authenticated only' as test,
  has_function_privilege('authenticated','public.fn_is_current_step_approver(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.fn_is_current_step_approver(uuid)','EXECUTE') as pass
union all
select 'REQ-02 submitter predicate is executable by authenticated only',
  has_function_privilege('authenticated','public.fn_is_request_submitter(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.fn_is_request_submitter(uuid)','EXECUTE')
union all
select 'REQ-03 decided-request predicate is executable by authenticated only',
  has_function_privilege('authenticated','public.fn_has_decided_request(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.fn_has_decided_request(uuid)','EXECUTE')
union all
select 'REQ-04 request policy keeps tenant predicate outside access branches',
  (select qual like '((organization_id = % AND ((EXISTS%'
   from pg_policies where schemaname='public' and tablename='requests' and policyname='requests_select_authorized')
union all
select 'REQ-05 request-step policy keeps tenant predicate outside access branches',
  (select qual like '((organization_id = % AND ((EXISTS%'
   from pg_policies where schemaname='public' and tablename='request_steps' and policyname='request_steps_select_authorized');
