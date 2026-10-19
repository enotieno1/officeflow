-- HR confidentiality and visible department directory access.
CREATE OR REPLACE FUNCTION private.fn_is_hr_workflow(p_workflow_definition_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','private','pg_temp' AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.workflow_definitions wd
  LEFT JOIN public.departments d ON d.id=wd.department_id
  WHERE wd.id=p_workflow_definition_id AND (
   lower(coalesce(wd.category,'')) IN ('hr','human resources','human resource')
   OR lower(coalesce(wd.category,'')) LIKE '%human resource%'
   OR upper(coalesce(d.code,''))='HR'
   OR lower(coalesce(d.name,''))='human resources'
  )
 );
$$;
CREATE OR REPLACE FUNCTION private.fn_is_hr_request(p_request_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public','private','pg_temp' AS $$
 SELECT EXISTS (
  SELECT 1 FROM public.requests r
  JOIN public.workflow_versions wv ON wv.id=r.workflow_version_id
  WHERE r.id=p_request_id AND private.fn_is_hr_workflow(wv.workflow_definition_id)
 );
$$;
REVOKE ALL ON FUNCTION private.fn_is_hr_workflow(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION private.fn_is_hr_request(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.fn_is_hr_workflow(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION private.fn_is_hr_request(uuid) TO authenticated;

DROP POLICY IF EXISTS employees_org_isolation ON public.employees;
DROP POLICY IF EXISTS employees_admin_only ON public.employees;
CREATE POLICY employees_admin_only ON public.employees FOR ALL TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=employees.organization_id AND p.role IN ('administrator','super_admin')))
WITH CHECK (organization_id=(SELECT public.fn_current_org()) AND EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=employees.organization_id AND p.role IN ('administrator','super_admin')));

DROP POLICY IF EXISTS departments_select_org ON public.departments;
CREATE POLICY departments_select_org ON public.departments FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org()));

DROP POLICY IF EXISTS workflow_definitions_select_org ON public.workflow_definitions;
CREATE POLICY workflow_definitions_select_org ON public.workflow_definitions FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND (
 NOT private.fn_is_hr_workflow(id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=workflow_definitions.organization_id
 AND p.role IN ('administrator','super_admin'))));

DROP POLICY IF EXISTS workflow_versions_select_org ON public.workflow_versions;
CREATE POLICY workflow_versions_select_org ON public.workflow_versions FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND (
 NOT private.fn_is_hr_workflow(workflow_definition_id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=workflow_versions.organization_id
 AND p.role IN ('administrator','super_admin'))));

DROP POLICY IF EXISTS workflow_steps_select_org ON public.workflow_steps;
CREATE POLICY workflow_steps_select_org ON public.workflow_steps FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND (
 NOT EXISTS(SELECT 1 FROM public.workflow_versions wv WHERE wv.id=workflow_steps.workflow_version_id
 AND private.fn_is_hr_workflow(wv.workflow_definition_id))
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=workflow_steps.organization_id AND p.role IN ('administrator','super_admin'))));

DROP POLICY IF EXISTS requests_select_org ON public.requests;
CREATE POLICY requests_select_org ON public.requests FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org())
 AND (NOT private.fn_is_hr_request(id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=requests.organization_id
 AND p.role IN ('administrator','super_admin')))
 AND (submitted_by=(SELECT auth.uid()) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=requests.organization_id
 AND p.role IN ('administrator','manager','auditor','super_admin'))
 OR public.fn_is_current_step_approver(id) OR public.fn_has_decided_request(id)));

DROP POLICY IF EXISTS request_steps_select_org ON public.request_steps;
CREATE POLICY request_steps_select_org ON public.request_steps FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org())
 AND (NOT private.fn_is_hr_request(request_id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=request_steps.organization_id
 AND p.role IN ('administrator','super_admin')))
 AND (public.fn_is_request_submitter(request_id) OR public.fn_has_decided_request(request_id)
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=request_steps.organization_id AND p.role IN ('administrator','manager','auditor','super_admin'))
 OR EXISTS(SELECT 1 FROM public.workflow_steps ws WHERE ws.id=request_steps.workflow_step_id
 AND ws.approver_role=(SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid()))));

DROP POLICY IF EXISTS request_comments_select_org ON public.request_comments;
CREATE POLICY request_comments_select_org ON public.request_comments FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org())
 AND (NOT private.fn_is_hr_request(request_id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=request_comments.organization_id
 AND p.role IN ('administrator','super_admin')))
 AND (public.fn_is_request_submitter(request_id) OR public.fn_has_decided_request(request_id)
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=request_comments.organization_id AND p.role IN ('administrator','manager','auditor','super_admin'))
 OR EXISTS(SELECT 1 FROM public.request_steps rs JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id
 WHERE rs.request_id=request_comments.request_id AND ws.approver_role=(SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid()))));

DROP POLICY IF EXISTS request_comments_insert_org ON public.request_comments;
CREATE POLICY request_comments_insert_org ON public.request_comments FOR INSERT TO authenticated
WITH CHECK (organization_id=(SELECT public.fn_current_org()) AND author_id=(SELECT auth.uid())
 AND (NOT private.fn_is_hr_request(request_id) OR EXISTS(SELECT 1 FROM public.profiles p
 WHERE p.id=(SELECT auth.uid()) AND p.organization_id=request_comments.organization_id
 AND p.role IN ('administrator','super_admin')))
 AND (EXISTS(SELECT 1 FROM public.requests r WHERE r.id=request_comments.request_id AND r.submitted_by=(SELECT auth.uid()))
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.role IN ('administrator','super_admin'))
 OR EXISTS(SELECT 1 FROM public.requests r JOIN public.request_steps rs ON rs.request_id=r.id
 AND rs.attempt_no=r.attempt_no AND rs.status='pending' AND rs.step_order=(SELECT min(rs2.step_order)
 FROM public.request_steps rs2 WHERE rs2.request_id=r.id AND rs2.attempt_no=r.attempt_no AND rs2.status='pending')
 JOIN public.workflow_steps ws ON ws.id=rs.workflow_step_id WHERE r.id=request_comments.request_id
 AND ws.approver_role=(SELECT p.role FROM public.profiles p WHERE p.id=(SELECT auth.uid()))));

DROP POLICY IF EXISTS notifications_select_own ON public.notifications;
CREATE POLICY notifications_select_own ON public.notifications FOR SELECT TO authenticated
USING (recipient_id=(SELECT auth.uid()) AND organization_id=(SELECT public.fn_current_org())
 AND (request_id IS NULL OR NOT private.fn_is_hr_request(request_id) OR EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=notifications.organization_id
 AND p.role IN ('administrator','super_admin'))));

DROP POLICY IF EXISTS notifications_update_own ON public.notifications;
CREATE POLICY notifications_update_own ON public.notifications FOR UPDATE TO authenticated
USING (recipient_id=(SELECT auth.uid()) AND organization_id=(SELECT public.fn_current_org())
 AND (request_id IS NULL OR NOT private.fn_is_hr_request(request_id) OR EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=notifications.organization_id
 AND p.role IN ('administrator','super_admin'))))
WITH CHECK (recipient_id=(SELECT auth.uid()) AND organization_id=(SELECT public.fn_current_org())
 AND (request_id IS NULL OR NOT private.fn_is_hr_request(request_id) OR EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=notifications.organization_id
 AND p.role IN ('administrator','super_admin'))));

DROP POLICY IF EXISTS audit_events_select_org_privileged ON public.audit_events;
CREATE POLICY audit_events_select_org_privileged ON public.audit_events FOR SELECT TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=audit_events.organization_id
 AND p.role IN ('administrator','auditor','super_admin'))
 AND (request_id IS NULL OR NOT private.fn_is_hr_request(request_id) OR EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=audit_events.organization_id
 AND p.role IN ('administrator','super_admin'))));
