-- F.4 access-path repair
REVOKE ALL ON TABLE public.profiles FROM anon, authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticated;
DROP POLICY IF EXISTS profiles_self_or_org_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_read_write_self_or_org_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_insert_self_or_org_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_delete_self_or_org_admin ON public.profiles;
DROP POLICY IF EXISTS profiles_self_update ON public.profiles;
DROP POLICY IF EXISTS profiles_admin_manage ON public.profiles;
CREATE POLICY profiles_select_self_or_org_admin ON public.profiles
FOR SELECT TO authenticated USING (
 id=(SELECT auth.uid()) OR EXISTS (
   SELECT 1 FROM public.fn_current_profile_context() ctx(role,organization_id)
   WHERE ctx.organization_id=profiles.organization_id
   AND ctx.role=ANY(ARRAY['administrator','manager'])
 )
);
CREATE OR REPLACE FUNCTION public.fn_update_profile_role(p_target_id uuid,p_new_role text)
RETURNS public.profiles LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE v_caller_role text; v_caller_org uuid; v_target_org uuid; v_result public.profiles;
BEGIN
 SELECT p.role,p.organization_id INTO v_caller_role,v_caller_org FROM public.profiles p WHERE p.id=(SELECT auth.uid());
 IF v_caller_role IS NULL THEN RAISE EXCEPTION 'no profile found for current user'; END IF;
 IF v_caller_role NOT IN ('administrator','super_admin') THEN RAISE EXCEPTION 'not authorized to change roles'; END IF;
 IF p_target_id=(SELECT auth.uid()) THEN RAISE EXCEPTION 'you cannot change your own role'; END IF;
 SELECT p.organization_id INTO v_target_org FROM public.profiles p WHERE p.id=p_target_id;
 IF v_target_org IS NULL OR v_target_org IS DISTINCT FROM v_caller_org THEN RAISE EXCEPTION 'target profile not found'; END IF;
 IF p_new_role NOT IN ('employee','officer','manager','administrator','auditor','super_admin') THEN RAISE EXCEPTION 'invalid role'; END IF;
 IF v_caller_role<>'super_admin' AND p_new_role='super_admin' THEN RAISE EXCEPTION 'only super_admin can assign super_admin'; END IF;
 UPDATE public.profiles SET role=p_new_role WHERE id=p_target_id RETURNING * INTO v_result;
 INSERT INTO public.audit_events(organization_id,request_id,actor_id,action,details)
 VALUES(v_caller_org,NULL,(SELECT auth.uid()),'profile_role_changed',jsonb_build_object('target_id',p_target_id,'new_role',p_new_role));
 RETURN v_result;
END;$function$;
REVOKE ALL ON FUNCTION public.fn_update_profile_role(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.fn_update_profile_role(uuid,text) TO authenticated;
REVOKE ALL ON TABLE public.employees,public.tasks,public.documents,public.transactions FROM anon;
REVOKE ALL ON TABLE public.employees,public.tasks,public.documents,public.transactions FROM authenticated;
GRANT SELECT ON TABLE public.employees,public.tasks,public.documents,public.transactions TO authenticated;
GRANT INSERT ON TABLE public.employees,public.tasks TO authenticated;
GRANT DELETE ON TABLE public.tasks TO authenticated;
REVOKE ALL ON SEQUENCE public.employees_id_seq,public.tasks_id_seq,public.documents_id_seq,public.transactions_id_seq FROM anon,authenticated;
GRANT USAGE ON SEQUENCE public.employees_id_seq,public.tasks_id_seq TO authenticated;