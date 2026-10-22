-- Bind invitation acceptance to the exact invitation that generated the email link.
DROP FUNCTION IF EXISTS public.fn_accept_org_invitation();
CREATE OR REPLACE FUNCTION public.fn_accept_org_invitation(p_invitation_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_email text;
  v_confirmed_at timestamptz;
  v_profile public.profiles;
  v_invitation public.organization_invitations;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT lower(u.email), u.email_confirmed_at INTO v_email, v_confirmed_at FROM auth.users u WHERE u.id = v_user_id;
  IF v_email IS NULL OR v_confirmed_at IS NULL THEN RAISE EXCEPTION 'confirm your email address before accepting this invitation'; END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'account profile is not ready; sign out and sign in again'; END IF;
  SELECT * INTO v_invitation FROM public.organization_invitations i
  WHERE i.id = p_invitation_id AND i.email = v_email AND i.status = 'pending' AND i.expires_at > now()
  FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no valid invitation was found for this verified email address'; END IF;
  IF v_profile.organization_id IS DISTINCT FROM '00000000-0000-0000-0000-000000000001'::uuid
     OR v_profile.role IS DISTINCT FROM 'employee' THEN RAISE EXCEPTION 'this account is already assigned to a workspace'; END IF;
  PERFORM set_config('app.profile_provisioning', 'true', true);
  UPDATE public.profiles SET organization_id = v_invitation.organization_id, role = v_invitation.role, unit_id = v_invitation.unit_id WHERE id = v_user_id;
  UPDATE public.organization_invitations SET status = 'accepted', accepted_by = v_user_id, accepted_at = now() WHERE id = v_invitation.id;
  INSERT INTO public.audit_events (organization_id, request_id, actor_id, action, details)
  VALUES (v_invitation.organization_id, NULL, v_user_id, 'organization_invitation_accepted',
    jsonb_build_object('invitation_id', v_invitation.id, 'email', v_email, 'role', v_invitation.role));
  RETURN v_invitation.organization_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.fn_accept_org_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_accept_org_invitation(uuid) TO authenticated;
