-- Published Starter and Professional prices copied from dashboard/pricing.html.
-- Enterprise remains custom-priced and is intentionally not a checkout plan.
insert into public.billing_plans (id,name,description,amount,currency,interval_unit,interval_count,seat_limit,is_active)
values
 ('starter_monthly','Starter','Published Starter monthly plan for up to 10 staff.',10000,'KES','month',1,10,true),
 ('professional_monthly','Professional','Published Professional monthly plan for up to 50 staff.',40000,'KES','month',1,50,true)
on conflict (id) do update set
 name=excluded.name, description=excluded.description, amount=excluded.amount, currency=excluded.currency,
 interval_unit=excluded.interval_unit, interval_count=excluded.interval_count, seat_limit=excluded.seat_limit,
 is_active=excluded.is_active, updated_at=now();