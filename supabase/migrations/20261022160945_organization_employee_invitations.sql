-- Organization-scoped employee invitations. Invitations are managed only by guarded RPCs
-- and a server-side Edge Function; authenticated clients have no direct table access.
CREATE TABLE IF NOT EXISTS public.organization_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  email text NOT NULL,
  role text NOT NULL DEFAULT 'employee' CHECK (role IN ('employee','officer','manager','administrator','auditor')),
  unit_id uuid NULL,
  invited_by uuid NOT NULL REFERENCES auth.users(id),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','revoked','expired')),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_by uuid NULL REFERENCES auth.users(id),
  accepted_at timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT organization_invitations_email_normalized CHECK (email = lower(btrim(email)))
);
CREATE INDEX IF NOT EXISTS organization_invitations_org_status_idx
  ON public.organization_invitations (organization_id, status, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS organization_invitations_one_pending_email
  ON public.organization_invitations (organization_id, email) WHERE status = 'pending';
ALTER TABLE public.organization_invitations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.organization_invitations FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.organization_invitations TO service_role;

CREATE OR REPLACE FUNCTION public.fn_create_org_invitation(p_email text, p_role text DEFAULT 'employee', p_unit_id uuid DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles;
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_invitation_id uuid;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF v_email = '' OR length(v_email) > 320 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'enter a valid email address';
  END IF;
  IF p_role NOT IN ('employee','officer','manager','administrator','auditor') THEN
    RAISE EXCEPTION 'role is not permitted for organization invitations';
  END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id;
  IF NOT FOUND OR v_profile.role <> 'administrator' OR v_profile.organization_id IS NULL
     OR v_profile.organization_id = '00000000-0000-0000-0000-000000000001'::uuid THEN
    RAISE EXCEPTION 'only an organization administrator can invite employees';
  END IF;
  IF p_unit_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.departments d WHERE d.id = p_unit_id AND d.organization_id = v_profile.organization_id
  ) THEN RAISE EXCEPTION 'selected department does not belong to your organization'; END IF;
  IF EXISTS (
    SELECT 1 FROM auth.users u JOIN public.profiles p ON p.id = u.id
    WHERE lower(u.email) = v_email AND p.organization_id = v_profile.organization_id
  ) THEN RAISE EXCEPTION 'this email already belongs to a user in your organization'; END IF;
  INSERT INTO public.organization_invitations (organization_id,email,role,unit_id,invited_by)
  VALUES (v_profile.organization_id,v_email,p_role,p_unit_id,v_user_id)
  RETURNING id INTO v_invitation_id;
  RETURN v_invitation_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.fn_create_org_invitation(text,text,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_create_org_invitation(text,text,uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_list_org_invitations()
RETURNS TABLE(id uuid,email text,role text,status text,expires_at timestamptz,created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE v_profile public.profiles;
BEGIN
  SELECT * INTO v_profile FROM public.profiles WHERE profiles.id = auth.uid();
  IF NOT FOUND OR v_profile.role <> 'administrator' OR v_profile.organization_id IS NULL THEN
    RAISE EXCEPTION 'only organization administrators can view invitations';
  END IF;
  RETURN QUERY SELECT i.id,i.email,i.role,i.status,i.expires_at,i.created_at
    FROM public.organization_invitations i WHERE i.organization_id = v_profile.organization_id
    ORDER BY i.created_at DESC LIMIT 100;
END;
$function$;
REVOKE ALL ON FUNCTION public.fn_list_org_invitations() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_list_org_invitations() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_accept_org_invitation()
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','private','pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid(); v_email text; v_confirmed_at timestamptz;
  v_profile public.profiles; v_invitation public.organization_invitations;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT lower(u.email),u.email_confirmed_at INTO v_email,v_confirmed_at FROM auth.users u WHERE u.id=v_user_id;
  IF v_email IS NULL OR v_confirmed_at IS NULL THEN RAISE EXCEPTION 'confirm your email address before accepting this invitation'; END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id=v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'account profile is not ready; sign out and sign in again'; END IF;
  SELECT * INTO v_invitation FROM public.organization_invitations i
    WHERE i.email=v_email AND i.status='pending' AND i.expires_at>now()
    ORDER BY i.created_at DESC LIMIT 1 FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no valid invitation was found for this email address'; END IF;
  IF v_profile.organization_id IS DISTINCT FROM '00000000-0000-0000-0000-000000000001'::uuid
     OR v_profile.role IS DISTINCT FROM 'employee' THEN RAISE EXCEPTION 'this account is already assigned to a workspace'; END IF;
  PERFORM set_config('app.profile_provisioning','true',true);
  UPDATE public.profiles SET organization_id=v_invitation.organization_id,role=v_invitation.role,unit_id=v_invitation.unit_id WHERE id=v_user_id;
  UPDATE public.organization_invitations SET status='accepted',accepted_by=v_user_id,accepted_at=now() WHERE id=v_invitation.id;
  INSERT INTO public.audit_events (organization_id,request_id,actor_id,action,details)
  VALUES (v_invitation.organization_id,NULL,v_user_id,'organization_invitation_accepted',
    jsonb_build_object('invitation_id',v_invitation.id,'email',v_email,'role',v_invitation.role));
  RETURN v_invitation.organization_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.fn_accept_org_invitation() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_accept_org_invitation() TO authenticated;
