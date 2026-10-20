-- A hosted checkout session ID is not the same resource as a collection invoice ID.
alter table public.billing_payment_attempts
  add column if not exists provider_checkout_id text;
create unique index if not exists billing_payment_attempts_provider_checkout_id_unique
  on public.billing_payment_attempts(provider_checkout_id)
  where provider_checkout_id is not null;
comment on column public.billing_payment_attempts.provider_checkout_id
  is 'IntaSend hosted checkout session ID; kept separate from collection invoice ID.';
