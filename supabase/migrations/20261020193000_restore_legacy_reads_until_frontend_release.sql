-- Temporary compatibility grants for the current production frontend.
-- Keep until the replacement HR/finance/fraud pages are deployed; then apply
-- 20261020200000_revoke_legacy_module_table_access_after_frontend_release.sql.
GRANT SELECT ON TABLE public.employees, public.transactions TO authenticated;
GRANT SELECT, UPDATE ON TABLE public.fraud_alerts TO authenticated;
