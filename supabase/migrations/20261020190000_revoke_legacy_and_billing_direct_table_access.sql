-- Legacy employee/transaction/fraud registers are not active customer-facing modules.
-- Organization provisioning, billing and audit operations must go through guarded RPCs.
REVOKE ALL ON TABLE public.audit_events, public.organizations FROM PUBLIC, anon, authenticated;

-- Billing rows contain subscription and provider metadata. Clients read their own
-- organization overview only through fn_get_billing_overview().
REVOKE ALL ON TABLE public.billing_plans, public.billing_subscriptions, public.billing_payment_attempts, public.billing_provider_events FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_billing_overview() TO authenticated;
