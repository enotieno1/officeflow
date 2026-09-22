CREATE OR REPLACE FUNCTION public.fn_decide_request_step(p_request_step_id uuid,p_decision text,p_comment text DEFAULT NULL)
RETURNS public.request_steps LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_org uuid; v_caller_role text; v_step public.request_steps; v_request public.requests; v_approver text; v_is_override boolean:=false; v_min_pending int; v_next RECORD;
BEGIN
 v_org:=public.fn_current_org(); IF v_org IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
 IF p_decision NOT IN ('approved','rejected','returned') THEN RAISE EXCEPTION 'invalid decision'; END IF;
 SELECT role INTO v_caller_role FROM public.profiles WHERE id=auth.uid();
 SELECT * INTO v_step FROM public.request_steps WHERE id=p_request_step_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request step not found'; END IF;
 SELECT * INTO v_request FROM public.requests WHERE id=v_step.request_id AND organization_id=v_org FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'request not found'; END IF;
 IF v_request.status<>'pending' THEN RAISE EXCEPTION 'request is not awaiting a decision'; END IF;
 IF v_step.attempt_no<>v_request.attempt_no THEN RAISE EXCEPTION 'step does not belong to the current attempt'; END IF;
 IF v_step.status<>'pending' THEN RAISE EXCEPTION 'step is not pending'; END IF;
 SELECT min(step_order) INTO v_min_pending FROM public.request_steps WHERE request_id=v_request.id AND attempt_no=v_request.attempt_no AND status='pending';
 IF v_step.step_order<>v_min_pending THEN RAISE EXCEPTION 'step is not the current pending step'; END IF;
 SELECT approver_role INTO v_approver FROM public.workflow_steps WHERE id=v_step.workflow_step_id;
 IF v_caller_role='super_admin' THEN v_is_override:=true;
 ELSIF v_caller_role=v_approver THEN
   IF v_request.submitted_by=auth.uid() THEN RAISE EXCEPTION 'submitter cannot decide their own request'; END IF;
 ELSE RAISE EXCEPTION 'not authorized to decide this step'; END IF;
 UPDATE public.request_steps SET status=p_decision,decided_by=auth.uid(),decided_at=now() WHERE id=v_step.id RETURNING * INTO v_step;
 IF p_decision='rejected' THEN UPDATE public.requests SET status='rejected',updated_at=now() WHERE id=v_request.id;
 ELSIF p_decision='returned' THEN UPDATE public.requests SET status='returned',updated_at=now() WHERE id=v_request.id;
 ELSIF p_decision='approved' THEN
   SELECT rs.id,ws.sla_hours INTO v_next FROM public.request_steps rs JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id WHERE rs.request_id=v_request.id AND rs.attempt_no=v_request.attempt_no AND rs.status='pending' ORDER BY rs.step_order LIMIT 1 FOR UPDATE OF rs;
   IF v_next.id IS NOT NULL THEN UPDATE public.request_steps SET due_at=CASE WHEN v_next.sla_hours IS NOT NULL THEN now()+(v_next.sla_hours||' hours')::interval ELSE NULL END WHERE id=v_next.id;
   ELSE UPDATE public.requests SET status='completed',updated_at=now() WHERE id=v_request.id; END IF;
 END IF;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details) VALUES(v_org,v_request.id,auth.uid(),CASE WHEN v_is_override THEN 'decision:override:'||p_decision ELSE 'decision:'||p_decision END,jsonb_build_object('request_step_id',v_step.id,'comment',p_comment));
 IF p_comment IS NOT NULL THEN INSERT INTO public.request_comments(organization_id,request_id,author_id,body) VALUES(v_org,v_request.id,auth.uid(),p_comment); END IF;
 RETURN v_step;
END;$function$;