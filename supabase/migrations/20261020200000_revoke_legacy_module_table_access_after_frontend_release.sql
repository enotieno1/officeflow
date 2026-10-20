-- Apply only after the replacement frontend is deployed.
-- Legacy HR/finance/fraud screens are retired in this release; their data must
-- not remain directly discoverable after the UI no longer depends on them.
REVOKE ALL ON TABLE public.employees, public.transactions, public.fraud_alerts FROM PUBLIC, anon, authenticated;
