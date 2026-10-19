-- Prevent control-tower and operational-intelligence aggregates from leaking HR activity.
CREATE OR REPLACE FUNCTION private.fn_control_tower(p_unit_id uuid DEFAULT NULL::uuid)
RETURNS TABLE(total_requests bigint,pending_requests bigint,completed_requests bigint,rejected_requests bigint,overdue_steps bigint,escalated_steps bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp' AS $$
DECLARE v_org uuid;v_role text;v_scope uuid;
BEGIN
 SELECT organization_id,role INTO v_org,v_role FROM public.profiles WHERE id=auth.uid();
 IF v_role NOT IN ('manager','administrator','auditor','super_admin') THEN RAISE EXCEPTION 'You do not have access to the Control Tower'; END IF;
 v_scope:=private.fn_effective_unit_scope(p_unit_id);
 RETURN QUERY
 SELECT count(r.*),count(*) FILTER(WHERE r.status='pending'),count(*) FILTER(WHERE r.status='completed'),count(*) FILTER(WHERE r.status='rejected'),
 (SELECT count(*) FROM public.request_steps rs JOIN public.requests rr ON rr.id=rs.request_id WHERE rs.organization_id=v_org AND rr.organization_id=v_org AND rs.status='pending' AND rs.due_at IS NOT NULL AND rs.due_at<now() AND (v_scope IS NULL OR rs.unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(rr.id))),
 (SELECT count(*) FROM public.request_steps rs JOIN public.requests rr ON rr.id=rs.request_id WHERE rs.organization_id=v_org AND rr.organization_id=v_org AND rs.status='pending' AND rs.escalated_at IS NOT NULL AND (v_scope IS NULL OR rs.unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(rr.id)))
 FROM public.requests r WHERE r.organization_id=v_org AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id));
END; $$;

CREATE OR REPLACE FUNCTION private.fn_operational_intelligence(p_unit_id uuid DEFAULT NULL::uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp' AS $$
DECLARE v_org uuid;v_role text;v_scope uuid;v_result jsonb;
BEGIN
 SELECT organization_id,role INTO v_org,v_role FROM public.profiles WHERE id=auth.uid();
 IF v_role NOT IN ('manager','administrator','auditor','super_admin') THEN RAISE EXCEPTION 'You do not have access to Operational Intelligence'; END IF;
 v_scope:=private.fn_effective_unit_scope(p_unit_id);
 SELECT jsonb_build_object(
  'scope_unit_id',v_scope,
  'summary',jsonb_build_object(
   'active_requests',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   'completed_requests',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='completed' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   'overdue_steps',(SELECT count(*) FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id AND r.organization_id=v_org WHERE rs.organization_id=v_org AND rs.status='pending' AND rs.due_at IS NOT NULL AND rs.due_at<now() AND (v_scope IS NULL OR coalesce(rs.unit_id,r.origin_unit_id)=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   'escalated_steps',(SELECT count(*) FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id AND r.organization_id=v_org WHERE rs.organization_id=v_org AND rs.status='pending' AND rs.escalated_at IS NOT NULL AND (v_scope IS NULL OR coalesce(rs.unit_id,r.origin_unit_id)=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   'high_priority_active',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND r.priority IN ('high','urgent') AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id)))),
  'units',coalesce((SELECT jsonb_agg(jsonb_build_object('unit_id',x.unit_id,'unit_name',x.unit_name,'unit_type',x.unit_type,'active_requests',x.active_requests,'overdue_steps',x.overdue_steps,'escalated_steps',x.escalated_steps,'avg_age_hours',round(x.avg_age_hours::numeric,1)) ORDER BY x.active_requests DESC,x.overdue_steps DESC,x.unit_name)
   FROM (SELECT d.id unit_id,d.name unit_name,d.unit_type,
    (SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND r.origin_unit_id=d.id AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))) active_requests,
    (SELECT count(*) FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id AND r.organization_id=v_org WHERE rs.organization_id=v_org AND rs.status='pending' AND rs.due_at IS NOT NULL AND rs.due_at<now() AND coalesce(rs.unit_id,r.origin_unit_id)=d.id AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))) overdue_steps,
    (SELECT count(*) FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id AND r.organization_id=v_org WHERE rs.organization_id=v_org AND rs.status='pending' AND rs.escalated_at IS NOT NULL AND coalesce(rs.unit_id,r.origin_unit_id)=d.id AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))) escalated_steps,
    coalesce((SELECT extract(epoch FROM avg(now()-r.created_at))/3600 FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND r.origin_unit_id=d.id AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),0) avg_age_hours
    FROM public.departments d WHERE d.organization_id=v_org AND d.is_active AND (v_scope IS NULL OR d.id=v_scope)) x),'[]'::jsonb),
  'bottlenecks',coalesce((SELECT jsonb_agg(jsonb_build_object('step_name',x.step_name,'approver_role',x.approver_role,'unit_id',x.unit_id,'unit_name',x.unit_name,'pending_count',x.pending_count,'overdue_count',x.overdue_count,'avg_age_hours',round(x.avg_age_hours::numeric,1)) ORDER BY x.pending_count DESC,x.overdue_count DESC)
   FROM (SELECT ws.name step_name,ws.approver_role,coalesce(rs.unit_id,r.origin_unit_id) unit_id,d.name unit_name,count(*)::bigint pending_count,count(*) FILTER(WHERE rs.due_at IS NOT NULL AND rs.due_at<now())::bigint overdue_count,extract(epoch FROM avg(now()-r.created_at))/3600 avg_age_hours
    FROM public.request_steps rs JOIN public.requests r ON r.id=rs.request_id AND r.organization_id=v_org JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id AND ws.organization_id=v_org LEFT JOIN public.departments d ON d.id=coalesce(rs.unit_id,r.origin_unit_id) AND d.organization_id=v_org
    WHERE rs.organization_id=v_org AND rs.status='pending' AND (v_scope IS NULL OR coalesce(rs.unit_id,r.origin_unit_id)=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))
    GROUP BY ws.name,ws.approver_role,coalesce(rs.unit_id,r.origin_unit_id),d.name LIMIT 20) x),'[]'::jsonb),
  'priority',coalesce((SELECT jsonb_agg(jsonb_build_object('priority',x.priority,'count',x.cnt) ORDER BY x.cnt DESC) FROM (SELECT r.priority,count(*)::bigint cnt FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id)) GROUP BY r.priority) x),'[]'::jsonb),
  'aging',jsonb_build_object(
   'under_24h',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND now()-r.created_at<interval '24 hours' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   '24_72h',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND now()-r.created_at>=interval '24 hours' AND now()-r.created_at<interval '72 hours' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id))),
   'over_72h',(SELECT count(*) FROM public.requests r WHERE r.organization_id=v_org AND r.status='pending' AND now()-r.created_at>=interval '72 hours' AND (v_scope IS NULL OR r.origin_unit_id=v_scope) AND (v_role IN ('administrator','super_admin') OR NOT private.fn_is_hr_request(r.id)))
  )
 ) INTO v_result;
 RETURN v_result;
END; $$;
