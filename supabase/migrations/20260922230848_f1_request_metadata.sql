-- F.1 request metadata
ALTER TABLE public.requests ADD COLUMN IF NOT EXISTS title text, ADD COLUMN IF NOT EXISTS payload jsonb NOT NULL DEFAULT '{}'::jsonb, ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'normal';
UPDATE public.requests SET title=COALESCE(NULLIF(trim(title),''),'Untitled Request') WHERE title IS NULL;
ALTER TABLE public.requests ALTER COLUMN title SET NOT NULL;
ALTER TABLE public.requests ADD CONSTRAINT requests_title_length_check CHECK (char_length(trim(title)) BETWEEN 1 AND 200);
ALTER TABLE public.requests ADD CONSTRAINT requests_payload_object_check CHECK (jsonb_typeof(payload)='object');
ALTER TABLE public.requests ADD CONSTRAINT requests_priority_check CHECK (priority IN ('low','normal','high','urgent'));
DROP FUNCTION IF EXISTS public.fn_submit_request(uuid);
CREATE FUNCTION public.fn_submit_request(p_workflow_version_id uuid,p_title text,p_payload jsonb DEFAULT '{}'::jsonb,p_priority text DEFAULT 'normal')
RETURNS public.requests LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_org uuid; v_version public.workflow_versions; v_request public.requests; v_first RECORD; v_title text; v_payload jsonb;
BEGIN
 v_org:=public.fn_current_org(); IF v_org IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
 v_title:=NULLIF(trim(p_title),''); IF v_title IS NULL OR char_length(v_title)>200 THEN RAISE EXCEPTION 'title is required and must be 1-200 characters'; END IF;
 IF p_priority NOT IN ('low','normal','high','urgent') THEN RAISE EXCEPTION 'invalid priority'; END IF;
 v_payload:=COALESCE(p_payload,'{}'::jsonb); IF jsonb_typeof(v_payload)<>'object' THEN RAISE EXCEPTION 'payload must be a JSON object'; END IF;
 SELECT * INTO v_version FROM public.workflow_versions WHERE id=p_workflow_version_id AND organization_id=v_org AND status='published';
 IF NOT FOUND THEN RAISE EXCEPTION 'workflow version not found'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.workflow_steps WHERE workflow_version_id=v_version.id) THEN RAISE EXCEPTION 'workflow version has no steps'; END IF;
 INSERT INTO public.requests(organization_id,workflow_version_id,submitted_by,title,payload,priority,status,attempt_no)
 VALUES(v_org,p_workflow_version_id,(SELECT auth.uid()),v_title,v_payload,p_priority,'pending',1) RETURNING * INTO v_request;
 INSERT INTO public.request_steps(request_id,organization_id,workflow_step_id,attempt_no,step_order,status,due_at)
 SELECT v_request.id,v_org,ws.id,1,ws.step_order,'pending',NULL FROM public.workflow_steps ws WHERE ws.workflow_version_id=v_version.id ORDER BY ws.step_order;
 SELECT rs.id,ws.sla_hours INTO v_first FROM public.request_steps rs JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id WHERE rs.request_id=v_request.id AND rs.attempt_no=1 ORDER BY rs.step_order LIMIT 1 FOR UPDATE OF rs;
 IF v_first.id IS NOT NULL AND v_first.sla_hours IS NOT NULL THEN UPDATE public.request_steps SET due_at=now()+(v_first.sla_hours||' hours')::interval WHERE id=v_first.id; END IF;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details) VALUES(v_org,v_request.id,(SELECT auth.uid()),'submit',jsonb_build_object('workflow_version_id',p_workflow_version_id,'title',v_title,'priority',p_priority));
 RETURN v_request;
END;$function$;
REVOKE ALL ON FUNCTION public.fn_submit_request(uuid,text,jsonb,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_submit_request(uuid,text,jsonb,text) TO authenticated;