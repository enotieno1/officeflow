-- Explicit deny policy documents that provider webhook payload metadata is server-only.
drop policy if exists billing_provider_events_deny_client_access on public.billing_provider_events;
create policy billing_provider_events_deny_client_access
  on public.billing_provider_events
  for all to anon, authenticated
  using (false) with check (false);
revoke all on public.billing_provider_events from anon, authenticated;
