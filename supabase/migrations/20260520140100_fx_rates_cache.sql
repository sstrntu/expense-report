-- Cache of historical FX rates so the convert-currency edge function only
-- hits Frankfurter once per (from, to, date) triple. Service-role writes
-- through the cache; authenticated users read it (handy for offline-ish
-- clients that already have a rate locally and want to verify).

create table if not exists turfmapp_expenses.fx_rates (
  from_currency char(3) not null,
  to_currency   char(3) not null,
  as_of_date    date    not null,
  rate          numeric(18, 8) not null,
  source        text    not null,
  fetched_at    timestamptz not null default now(),
  primary key (from_currency, to_currency, as_of_date),
  constraint fx_rates_currency_upper
    check (from_currency = upper(from_currency) and to_currency = upper(to_currency)),
  constraint fx_rates_rate_positive check (rate > 0)
);

create index if not exists fx_rates_fetched_at_idx
  on turfmapp_expenses.fx_rates(fetched_at desc);

alter table turfmapp_expenses.fx_rates enable row level security;

-- Any authenticated user can read rates — they're public market data and
-- it's useful for the iOS client to fall back to cached rows when the
-- edge function is unreachable. Writes are restricted to service_role,
-- which is what the convert-currency function runs as.
create policy "authenticated can read fx rates"
  on turfmapp_expenses.fx_rates
  for select
  to authenticated
  using (true);

grant select on turfmapp_expenses.fx_rates to authenticated;
grant insert, update on turfmapp_expenses.fx_rates to service_role;
