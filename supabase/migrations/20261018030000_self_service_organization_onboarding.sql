-- Self-service organization onboarding.
-- Existing sign-ups are placed in the shared bootstrap organization. This RPC
-- lets an authenticated employee create a tenant and become its first admin.
CREATE OR REPLACE FUNCTION public.fn_enforce_profiles_organization_immutable()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT (current_user = 'postgres' AND current_setting('app.profile_provisioning', true) = 'true') THEN
      RAISE EXCEPTION 'profiles may only be created through the organization-provisioning path';
    END IF;
    IF NEW.organization_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.organizations WHERE id = NEW.organization_id) THEN
      RAISE EXCEPTION 'organization_id must reference an existing organization';
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
       AND NOT (current_user = 'postgres' AND current_setting('app.profile_provisioning', true) = 'true') THEN
      RAISE EXCEPTION 'profiles.organization_id is immutable outside the organization-provisioning path';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_enforce_profiles_role_no_self_escalation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NOT (current_user = 'postgres' AND current_setting('app.profile_provisioning', true) = 'true') THEN
      NEW.role := 'employee';
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.role IS DISTINCT FROM OLD.role
       AND OLD.id = auth.uid()
       AND NOT (current_user = 'postgres' AND current_setting('app.profile_provisioning', true) = 'true') THEN
      RAISE EXCEPTION 'you cannot change your own role';
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_create_organization_for_current_user(p_org_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles;
  v_org public.organizations;
  v_name text := trim(coalesce(p_org_name, ''));
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF length(v_name) < 2 OR length(v_name) > 120 THEN
    RAISE EXCEPTION 'organization name must be between 2 and 120 characters';
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'your account profile is not ready; please sign out and sign in again';
  END IF;
  IF v_profile.organization_id IS DISTINCT FROM '00000000-0000-0000-0000-000000000001'::uuid
     OR v_profile.role IS DISTINCT FROM 'employee' THEN
    RAISE EXCEPTION 'this account is already assigned to an organization';
  END IF;

  INSERT INTO public.organizations (name) VALUES (v_name) RETURNING * INTO v_org;
  PERFORM set_config('app.profile_provisioning', 'true', true);
  UPDATE public.profiles SET organization_id = v_org.id, role = 'administrator' WHERE id = v_user_id;

  INSERT INTO public.audit_events (organization_id, request_id, actor_id, action, details)
  VALUES (v_org.id, NULL, v_user_id, 'organization_provisioned',
          jsonb_build_object('organization_name', v_org.name, 'created_by_user', v_user_id));
  RETURN v_org.id;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_create_organization_for_current_user(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_create_organization_for_current_user(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.fn_create_organization_for_current_user(text) TO authenticated;
