-- Complete first-run organization onboarding: tenant details, selected plan and initial administrator invitations.
ALTER TABLE public.organizations
  ADD COLUMN IF NOT EXISTS industry text,
  ADD COLUMN IF NOT EXISTS website text,
  ADD COLUMN IF NOT EXISTS country text NOT NULL DEFAULT 'Kenya',
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS phone text;

CREATE OR REPLACE FUNCTION public.fn_onboard_organization(
  p_org_name text,
  p_plan_id text,
  p_org_details jsonb DEFAULT '{}'::jsonb,
  p_admin_emails text[] DEFAULT ARRAY[]::text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'private', 'pg_temp'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles;
  v_org public.organizations;
  v_plan public.billing_plans;
  v_name text := trim(coalesce(p_org_name, ''));
  v_email text;
  v_invite_count integer := 0;
  v_subscription_id uuid;
  v_details jsonb := coalesce(p_org_details, '{}'::jsonb);
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF length(v_name) < 2 OR length(v_name) > 120 THEN
    RAISE EXCEPTION 'organization name must be between 2 and 120 characters';
  END IF;
  IF p_plan_id IS NULL OR length(trim(p_plan_id)) = 0 THEN
    RAISE EXCEPTION 'select an active subscription package';
  END IF;
  IF jsonb_typeof(v_details) <> 'object' THEN
    RAISE EXCEPTION 'organization details must be an object';
  END IF;
  IF length(coalesce(v_details->>'industry','')) > 120
     OR length(coalesce(v_details->>'website','')) > 240
     OR length(coalesce(v_details->>'country','Kenya')) > 100
     OR length(coalesce(v_details->>'contact_email','')) > 320
     OR length(coalesce(v_details->>'phone','')) > 40 THEN
    RAISE EXCEPTION 'one or more organization details exceed the allowed length';
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'your account profile is not ready; please sign out and sign in again'; END IF;
  IF v_profile.organization_id IS DISTINCT FROM '00000000-0000-0000-0000-000000000001'::uuid
     OR v_profile.role IS DISTINCT FROM 'employee' THEN
    RAISE EXCEPTION 'this account is already assigned to an organization';
  END IF;

  SELECT * INTO v_plan FROM public.billing_plans WHERE id = trim(p_plan_id) AND is_active = true;
  IF NOT FOUND THEN RAISE EXCEPTION 'the selected package is unavailable; refresh and choose an active package'; END IF;

  IF coalesce(array_length(p_admin_emails, 1), 0) > 3 THEN
    RAISE EXCEPTION 'you can invite up to three additional administrators during setup';
  END IF;

  INSERT INTO public.organizations (name, industry, website, country, contact_email, phone)
  VALUES (
    v_name,
    nullif(trim(coalesce(v_details->>'industry','')), ''),
    nullif(trim(coalesce(v_details->>'website','')), ''),
    coalesce(nullif(trim(coalesce(v_details->>'country','Kenya')), ''), 'Kenya'),
    nullif(lower(trim(coalesce(v_details->>'contact_email',''))), ''),
    nullif(trim(coalesce(v_details->>'phone','')), '')
  ) RETURNING * INTO v_org;

  PERFORM set_config('app.profile_provisioning', 'true', true);
  UPDATE public.profiles SET organization_id = v_org.id, role = 'administrator' WHERE id = v_user_id;

  INSERT INTO public.billing_subscriptions (organization_id, plan_id, status, provider, created_by)
  VALUES (v_org.id, v_plan.id, 'pending', 'intasend', v_user_id)
  RETURNING id INTO v_subscription_id;

  FOREACH v_email IN ARRAY coalesce(p_admin_emails, ARRAY[]::text[]) LOOP
    v_email := lower(trim(coalesce(v_email, '')));
    IF v_email = '' THEN CONTINUE; END IF;
    IF length(v_email) > 320 OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
      RAISE EXCEPTION 'an additional administrator email address is invalid';
    END IF;
    IF v_email = lower(coalesce((SELECT email FROM auth.users WHERE id = v_user_id), '')) THEN
      RAISE EXCEPTION 'the registering administrator is already an administrator; do not invite the same email again';
    END IF;
    INSERT INTO public.organization_invitations (organization_id, email, role, invited_by)
    VALUES (v_org.id, v_email, 'administrator', v_user_id);
    v_invite_count := v_invite_count + 1;
  END LOOP;

  INSERT INTO public.audit_events (organization_id, request_id, actor_id, action, details)
  VALUES (v_org.id, NULL, v_user_id, 'organization_onboarded',
    jsonb_build_object(
      'organization_name', v_org.name,
      'created_by_user', v_user_id,
      'plan_id', v_plan.id,
      'subscription_status', 'pending',
      'administrator_invitations_created', v_invite_count
    ));

  RETURN jsonb_build_object(
    'organization_id', v_org.id,
    'subscription_id', v_subscription_id,
    'plan_id', v_plan.id,
    'plan_name', v_plan.name,
    'invitation_count', v_invite_count,
    'invitation_emails_created', v_invite_count
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_onboard_organization(text, text, jsonb, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_onboard_organization(text, text, jsonb, text[]) TO authenticated;
