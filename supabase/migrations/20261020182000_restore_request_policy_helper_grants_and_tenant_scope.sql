-- RLS policies call these SECURITY DEFINER predicates; authenticated users
-- must be able to execute them for PostgREST SELECTs to evaluate the policies.
REVOKE ALL ON FUNCTION public.fn_is_current_step_approver(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_is_request_submitter(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.fn_has_decided_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_is_current_step_approver(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_is_request_submitter(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_has_decided_request(uuid) TO authenticated;

-- Keep the tenant predicate outside every authorization branch.
DROP POLICY IF EXISTS requests_select_authorized ON public.requests;
CREATE POLICY requests_select_authorized
ON public.requests
FOR SELECT TO authenticated
USING (
  organization_id = (SELECT public.fn_current_org())
  AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = requests.organization_id
        AND p.role IN ('administrator','super_admin')
    )
    OR submitted_by = (SELECT auth.uid())
    OR (
      (public.fn_is_current_step_approver(id) OR public.fn_has_decided_request(id))
      AND NOT private.fn_is_hr_request(id)
    )
  )
);

DROP POLICY IF EXISTS request_steps_select_authorized ON public.request_steps;
CREATE POLICY request_steps_select_authorized
ON public.request_steps
FOR SELECT TO authenticated
USING (
  organization_id = (SELECT public.fn_current_org())
  AND (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = request_steps.organization_id
        AND p.role IN ('administrator','super_admin')
    )
    OR public.fn_is_request_submitter(request_id)
    OR (
      (public.fn_has_decided_request(request_id) OR public.fn_is_current_step_approver(request_id))
      AND NOT private.fn_is_hr_request(request_id)
    )
  )
);
