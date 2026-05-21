-- FX snapshot columns on expenses.
--
-- Each project already has `budget_currency` — that doubles as the project's
-- *base currency*. When an expense is submitted in a currency different from
-- its project's base, we hit Frankfurter once at submit time and snapshot
-- the rate onto the expense row. The dashboard sums `amount_in_base_minor`,
-- never re-converting, so historical reports are reproducible even when
-- live FX rates drift later.
--
-- All columns are nullable so existing rows survive; a one-time backfill
-- on the client populates them in a follow-up pass.

alter table turfmapp_expenses.expenses
  add column if not exists base_currency        char(3),
  add column if not exists amount_in_base_minor integer,
  add column if not exists fx_rate              numeric(18, 8),
  add column if not exists fx_rate_as_of        date,
  add column if not exists fx_source            text;

-- Same shape constraints as `currency`/`amount_minor`: upper-case ISO codes,
-- non-negative converted amounts, finite positive rates.
alter table turfmapp_expenses.expenses
  add constraint expenses_base_currency_upper
    check (base_currency is null or base_currency = upper(base_currency)),
  add constraint expenses_amount_in_base_nonnegative
    check (amount_in_base_minor is null or amount_in_base_minor >= 0),
  add constraint expenses_fx_rate_positive
    check (fx_rate is null or fx_rate > 0);

-- Same-currency expenses (no conversion needed) get fx_source = 'identity'
-- with rate = 1; cross-currency expenses get fx_source = 'frankfurter' or
-- 'fallback-static' depending on whether the live API responded.
comment on column turfmapp_expenses.expenses.fx_source is
  'Origin of fx_rate: identity (same-currency), frankfurter (live ECB), fallback-static (offline cached table), backfill (one-time post-launch fill).';
