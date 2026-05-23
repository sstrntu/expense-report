-- Fixes "permission denied for table users" on sign-in.
--
-- The users table was moved from public to turfmapp_expenses in migration
-- 20260516097000_move_expense_schema_to_turfmapp_expenses.sql. The RLS
-- policies (users can read/update/insert own profile) carried over, but the
-- table-level GRANTs that Supabase auto-applies to the public schema did
-- NOT — table privileges don't transfer across schemas, so authenticated
-- has no SELECT/INSERT/UPDATE rights on turfmapp_expenses.users at all.
-- PostgreSQL rejects the request before RLS gets to evaluate.
--
-- service_role also needs SELECT in case any future edge function reads
-- users (none does today, but matches the device_tokens pattern we already
-- have for the send-push function).

grant select, insert, update on turfmapp_expenses.users to authenticated;
grant select on turfmapp_expenses.users to service_role;
