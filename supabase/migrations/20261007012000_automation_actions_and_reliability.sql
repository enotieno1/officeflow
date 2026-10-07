-- Extend OfficeFlow automation actions: create tasks and queue requester email.
create or replace function private.fn_run_automation(p_event_type text,p_request_id uuid,p_step_id uuid default null)
returns integer language plpgsql security definer set search_path='public','private','pg_temp' as $$
declare r record; req public.requests; st public.request_steps; action jsonb; cnt int:=0; msg text; new_sla numeric; v_def uuid; target_role text; target uuid;
begin
 select * into req from public.requests where id=p_request_id; if not found then return 0; end if;
 select wv.workflow_definition_id into v_def from public.workflow_versions wv where wv.id=req.workflow_version_id;
 if p_step_id is not null then select * into st from public.request_steps where id=p_step_id; end if;
 for r in select * from public.automation_rules ar where ar.organization_id=req.organization_id and ar.is_active and ar.event_type=p_event_type and (ar.workflow_definition_id is null or ar.workflow_definition_id=v_def) and (ar.unit_id is null or ar.unit_id=req.origin_unit_id)
 loop
  if not private.fn_automation_conditions_match(req,st,r.conditions) then
   insert into public.automation_runs(organization_id,rule_id,request_id,request_step_id,event_type,status,details) values(r.organization_id,r.id,req.id,p_step_id,p_event_type,'skipped',jsonb_build_object('reason','conditions_not_met')); continue;
  end if;
  begin
   for action in select value from jsonb_array_elements(r.actions) loop
    if action->>'type'='set_priority' then
      if action->>'value' not in ('low','normal','high','urgent') then raise exception 'invalid priority'; end if;
      update public.requests set priority=action->>'value',updated_at=now() where id=req.id;
    elsif action->>'type'='notify_requester' then
      msg:=coalesce(action->>'message','Automation rule triggered for your request.');
      insert into public.notifications(organization_id,recipient_id,request_id,type,title,body) values(req.organization_id,req.submitted_by,req.id,'automation',coalesce(action->>'title',r.name),msg);
    elsif action->>'type'='notify_role' then
      msg:=coalesce(action->>'message','Automation rule triggered.');
      insert into public.notifications(organization_id,recipient_id,request_id,type,title,body)
      select req.organization_id,p.id,req.id,'automation',coalesce(action->>'title',r.name),msg from public.profiles p where p.organization_id=req.organization_id and p.role=action->>'role' and (p.unit_id=req.origin_unit_id or p.role in ('administrator','super_admin'));
    elsif action->>'type'='queue_email_requester' then
      insert into public.email_outbox(organization_id,recipient_id,request_id,template,subject,payload,status,attempts) values(req.organization_id,req.submitted_by,req.id,coalesce(action->>'template','automation'),coalesce(action->>'subject',r.name),jsonb_build_object('message',coalesce(action->>'message','Automation rule triggered.')),'pending',0);
    elsif action->>'type'='create_task' then
      target_role:=action->>'role';
      select p.id into target from public.profiles p where p.organization_id=req.organization_id and (target_role is null or p.role=target_role) and (p.unit_id=req.origin_unit_id or p.role in ('administrator','super_admin')) order by (p.unit_id=req.origin_unit_id) desc,p.created_at limit 1;
      insert into public.tasks(title,description,status,priority,assigned_to,due_date,owner_id,organization_id) values(coalesce(action->>'title',req.title),coalesce(action->>'description','Created by OfficeFlow automation for request '||req.id::text),'pending',coalesce(action->>'priority',req.priority),coalesce(target::text,req.submitted_by::text),case when action ? 'due_days' then current_date+greatest(1,(action->>'due_days')::int) else null end,req.submitted_by,req.organization_id);
    elsif action->>'type'='set_sla_hours' and p_step_id is not null then
      new_sla:=(action->>'hours')::numeric; if new_sla<0.5 or new_sla>720 then raise exception 'invalid SLA hours'; end if;
      update public.request_steps set due_at=now()+(new_sla||' hours')::interval where id=p_step_id and status='pending';
    elsif action->>'type'='audit' then
      insert into public.audit_events(organization_id,request_id,actor_id,action,details) values(req.organization_id,req.id,null,coalesce(action->>'action','automation'),jsonb_build_object('rule_id',r.id,'event_type',p_event_type));
    else raise exception 'unsupported automation action'; end if;
   end loop;
   insert into public.automation_runs(organization_id,rule_id,request_id,request_step_id,event_type,status,details) values(r.organization_id,r.id,req.id,p_step_id,p_event_type,'executed',jsonb_build_object('action_count',jsonb_array_length(r.actions))); cnt:=cnt+1;
  exception when others then
   insert into public.automation_runs(organization_id,rule_id,request_id,request_step_id,event_type,status,details) values(r.organization_id,r.id,req.id,p_step_id,p_event_type,'failed',jsonb_build_object('error',sqlerrm));
  end;
 end loop; return cnt;
end $$;