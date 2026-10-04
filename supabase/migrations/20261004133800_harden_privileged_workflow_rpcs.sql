-- Keep privileged workflow mutations behind non-exposed SECURITY DEFINER functions.
create schema if not exists private;

alter function public.fn_cancel_request(uuid) set schema private;
alter function public.fn_decide_request_step(uuid,text,text) set schema private;
alter function public.fn_publish_workflow_version(uuid) set schema private;
alter function public.fn_resubmit_request(uuid) set schema private;
alter function public.fn_submit_request(uuid,text,jsonb,text) set schema private;
alter function public.fn_update_profile_role(uuid,text) set schema private;

revoke all on function private.fn_cancel_request(uuid) from public, anon, authenticated;
revoke all on function private.fn_decide_request_step(uuid,text,text) from public, anon, authenticated;
revoke all on function private.fn_publish_workflow_version(uuid) from public, anon, authenticated;
revoke all on function private.fn_resubmit_request(uuid) from public, anon, authenticated;
revoke all on function private.fn_submit_request(uuid,text,jsonb,text) from public, anon, authenticated;
revoke all on function private.fn_update_profile_role(uuid,text) from public, anon, authenticated;

grant execute on function private.fn_cancel_request(uuid) to authenticated;
grant execute on function private.fn_decide_request_step(uuid,text,text) to authenticated;
grant execute on function private.fn_publish_workflow_version(uuid) to authenticated;
grant execute on function private.fn_resubmit_request(uuid) to authenticated;
grant execute on function private.fn_submit_request(uuid,text,jsonb,text) to authenticated;
grant execute on function private.fn_update_profile_role(uuid,text) to authenticated;

create or replace function public.fn_cancel_request(p_request_id uuid)
returns public.requests language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_cancel_request(p_request_id); $$;

create or replace function public.fn_decide_request_step(p_request_step_id uuid, p_decision text, p_comment text default null)
returns public.request_steps language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_decide_request_step(p_request_step_id, p_decision, p_comment); $$;

create or replace function public.fn_publish_workflow_version(p_workflow_version_id uuid)
returns public.workflow_versions language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_publish_workflow_version(p_workflow_version_id); $$;

create or replace function public.fn_resubmit_request(p_request_id uuid)
returns public.requests language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_resubmit_request(p_request_id); $$;

create or replace function public.fn_submit_request(p_workflow_version_id uuid, p_title text, p_payload jsonb default '{}'::jsonb, p_priority text default 'normal')
returns public.requests language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_submit_request(p_workflow_version_id, p_title, p_payload, p_priority); $$;

create or replace function public.fn_update_profile_role(p_target_id uuid, p_new_role text)
returns public.profiles language sql security invoker
set search_path = public, pg_temp
as $$ select private.fn_update_profile_role(p_target_id, p_new_role); $$;

revoke execute on function public.fn_cancel_request(uuid) from public, anon;
revoke execute on function public.fn_decide_request_step(uuid,text,text) from public, anon;
revoke execute on function public.fn_publish_workflow_version(uuid) from public, anon;
revoke execute on function public.fn_resubmit_request(uuid) from public, anon;
revoke execute on function public.fn_submit_request(uuid,text,jsonb,text) from public, anon;
revoke execute on function public.fn_update_profile_role(uuid,text) from public, anon;

grant execute on function public.fn_cancel_request(uuid) to authenticated;
grant execute on function public.fn_decide_request_step(uuid,text,text) to authenticated;
grant execute on function public.fn_publish_workflow_version(uuid) to authenticated;
grant execute on function public.fn_resubmit_request(uuid) to authenticated;
grant execute on function public.fn_submit_request(uuid,text,jsonb,text) to authenticated;
grant execute on function public.fn_update_profile_role(uuid,text) to authenticated;
