-- Ensure privileged workflow RPCs do not bypass HR confidentiality.
CREATE OR REPLACE FUNCTION private.fn_my_work()
RETURNS TABLE(request_id uuid,request_title text,request_priority text,request_status text,submitted_by uuid,
 submitted_at timestamptz,request_step_id uuid,step_order integer,step_name text,approver_role text,
 sla_hours numeric,due_at timestamptz,escalated_at timestamptz)
LANGUAGE sql SECURITY DEFINER SET search_path TO 'public','private','pg_temp' AS $$
 SELECT r.id,r.title,r.priority,r.status,r.submitted_by,r.created_at,rs.id,rs.step_order,ws.name,
 ws.approver_role,ws.sla_hours,rs.due_at,rs.escalated_at
 FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id
 JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id
 CROSS JOIN LATERAL (SELECT ctx.role,ctx.organization_id,ctx.unit_id FROM private.fn_profile_context_with_unit() ctx LIMIT 1) me
 WHERE rs.organization_id=me.organization_id AND r.organization_id=me.organization_id AND r.status='pending'
 AND rs.attempt_no=r.attempt_no AND rs.status='pending' AND ws.approver_role=me.role
 AND (me.role IN ('administrator','super_admin') OR rs.unit_id IS NULL OR rs.unit_id=me.unit_id)
 AND (NOT private.fn_is_hr_request(r.id) OR me.role IN ('administrator','super_admin'))
 ORDER BY CASE r.priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END,rs.due_at NULLS LAST,r.created_at;
$$;

CREATE OR REPLACE FUNCTION private.fn_decide_request_step(p_request_step_id uuid,p_decision text,p_comment text DEFAULT NULL::text)
RETURNS public.request_steps LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public','private','pg_temp' AS $$
DECLARE v_org uuid;v_caller_role text;v_caller_unit uuid;v_step public.request_steps;v_request public.requests;
 v_approver text;v_is_override boolean:=false;v_min_pending int;v_next record;
BEGIN
 v_org:=public.fn_current_org(); IF v_org IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
 IF p_decision NOT IN ('approved','rejected','returned') THEN RAISE EXCEPTION 'invalid decision'; END IF;
 SELECT role,unit_id INTO v_caller_role,v_caller_unit FROM public.profiles WHERE id=auth.uid() AND organization_id=v_org;
 SELECT * INTO v_step FROM public.request_steps WHERE id=p_request_step_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request step not found'; END IF;
 SELECT * INTO v_request FROM public.requests WHERE id=v_step.request_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
 IF private.fn_is_hr_request(v_request.id) AND v_caller_role NOT IN ('administrator','super_admin') THEN
  RAISE EXCEPTION 'HR records are restricted to administrators and top management'; END IF;
 IF v_request.status<>'pending' THEN RAISE EXCEPTION 'request is not awaiting a decision'; END IF;
 IF v_step.attempt_no<>v_request.attempt_no THEN RAISE EXCEPTION 'step does not belong to the current attempt'; END IF;
 IF v_step.status<>'pending' THEN RAISE EXCEPTION 'step is not pending'; END IF;
 SELECT min(step_order) INTO v_min_pending FROM public.request_steps WHERE request_id=v_request.id AND attempt_no=v_request.attempt_no AND status='pending';
 IF v_step.step_order<>v_min_pending THEN RAISE EXCEPTION 'step is not the current pending step'; END IF;
 SELECT approver_role INTO v_approver FROM public.workflow_steps WHERE id=v_step.workflow_step_id;
 IF v_caller_role='super_admin' THEN v_is_override:=true;
 ELSIF v_caller_role=v_approver THEN
  IF v_request.submitted_by=auth.uid() THEN RAISE EXCEPTION 'submitter cannot decide their own request'; END IF;
  IF v_caller_role NOT IN ('administrator','super_admin') AND v_step.unit_id IS NOT NULL AND v_caller_unit IS DISTINCT FROM v_step.unit_id THEN
   RAISE EXCEPTION 'not authorized for this organizational unit'; END IF;
 ELSE RAISE EXCEPTION 'not authorized to decide this step'; END IF;
 UPDATE public.request_steps SET status=p_decision,decided_by=auth.uid(),decided_at=now() WHERE id=v_step.id RETURNING * INTO v_step;
 IF p_decision='rejected' THEN UPDATE public.requests SET status='rejected',updated_at=now() WHERE id=v_request.id;
 ELSIF p_decision='returned' THEN UPDATE public.requests SET status='returned',updated_at=now() WHERE id=v_request.id;
 ELSIF p_decision='approved' THEN
  SELECT rs.id,ws.sla_hours INTO v_next FROM public.request_steps rs JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id
  WHERE rs.request_id=v_request.id AND rs.attempt_no=v_request.attempt_no AND rs.status='pending' ORDER BY rs.step_order LIMIT 1 FOR UPDATE OF rs;
  IF v_next.id IS NOT NULL THEN UPDATE public.request_steps SET due_at=CASE WHEN v_next.sla_hours IS NOT NULL THEN now()+(v_next.sla_hours||' hours')::interval ELSE NULL END WHERE id=v_next.id;
  ELSE UPDATE public.requests SET status='completed',updated_at=now() WHERE id=v_request.id; END IF;
 END IF;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details) VALUES(v_org,v_request.id,auth.uid(),
 CASE WHEN v_is_override THEN 'decision:override:'||p_decision ELSE 'decision:'||p_decision END,
 jsonb_build_object('request_step_id',v_step.id,'comment',p_comment,'unit_id',v_step.unit_id));
 IF p_comment IS NOT NULL THEN INSERT INTO public.request_comments(organization_id,request_id,author_id,body) VALUES(v_org,v_request.id,auth.uid(),p_comment); END IF;
 RETURN v_step;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_cancel_request(p_request_id uuid)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp' AS $$
DECLARE v_org uuid;v_caller_role text;v_caller_unit uuid;v_request public.requests;
BEGIN
 v_org:=public.fn_current_org(); IF v_org IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
 SELECT role,unit_id INTO v_caller_role,v_caller_unit FROM public.profiles WHERE id=auth.uid() AND organization_id=v_org;
 SELECT * INTO v_request FROM public.requests WHERE id=p_request_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
 IF private.fn_is_hr_request(v_request.id) AND v_caller_role NOT IN ('administrator','super_admin') THEN RAISE EXCEPTION 'HR records are restricted to administrators and top management'; END IF;
 IF v_request.status NOT IN ('draft','pending','returned') THEN RAISE EXCEPTION 'request cannot be cancelled in its current state'; END IF;
 IF v_request.submitted_by<>auth.uid() AND v_caller_role NOT IN ('administrator','manager','super_admin') THEN RAISE EXCEPTION 'not authorized to cancel this request'; END IF;
 IF v_caller_role='manager' AND v_request.submitted_by<>auth.uid() AND v_request.origin_unit_id IS DISTINCT FROM v_caller_unit THEN RAISE EXCEPTION 'manager cannot cancel a request outside their organizational unit'; END IF;
 UPDATE public.requests SET status='cancelled',updated_at=now() WHERE id=v_request.id RETURNING * INTO v_request;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details) VALUES(v_org,v_request.id,auth.uid(),'cancel','{}'::jsonb);
 RETURN v_request;
END; $$;

CREATE OR REPLACE FUNCTION private.fn_resubmit_request(p_request_id uuid)
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp' AS $$
DECLARE v_org uuid;v_caller_role text;v_request public.requests;v_new_attempt int;v_first record;
BEGIN
 v_org:=public.fn_current_org(); IF v_org IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
 SELECT p.role INTO v_caller_role FROM public.profiles p WHERE p.id=auth.uid() AND p.organization_id=v_org;
 SELECT * INTO v_request FROM public.requests WHERE id=p_request_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
 IF private.fn_is_hr_request(v_request.id) AND v_caller_role NOT IN ('administrator','super_admin') THEN RAISE EXCEPTION 'HR records are restricted to administrators and top management'; END IF;
 IF v_request.status<>'returned' THEN RAISE EXCEPTION 'request is not in a returned state'; END IF;
 IF v_request.submitted_by<>auth.uid() THEN RAISE EXCEPTION 'only the original submitter may resubmit'; END IF;
 v_new_attempt:=v_request.attempt_no+1;
 INSERT INTO public.request_steps(request_id,organization_id,workflow_step_id,unit_id,attempt_no,step_order,status,due_at)
 SELECT v_request.id,v_org,ws.id,ws.unit_id,v_new_attempt,ws.step_order,'pending',NULL FROM public.workflow_steps ws
 WHERE ws.workflow_version_id=v_request.workflow_version_id ORDER BY ws.step_order;
 SELECT rs.id,ws.sla_hours INTO v_first FROM public.request_steps rs JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id
 WHERE rs.request_id=v_request.id AND rs.attempt_no=v_new_attempt ORDER BY rs.step_order LIMIT 1 FOR UPDATE OF rs;
 IF v_first.id IS NOT NULL AND v_first.sla_hours IS NOT NULL THEN UPDATE public.request_steps SET due_at=now()+(v_first.sla_hours||' hours')::interval WHERE id=v_first.id; END IF;
 UPDATE public.requests SET status='pending',attempt_no=v_new_attempt,updated_at=now() WHERE id=v_request.id RETURNING * INTO v_request;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details) VALUES(v_org,v_request.id,auth.uid(),'resubmit',jsonb_build_object('attempt_no',v_new_attempt));
 RETURN v_request;
END; $$;
