-- The send-push edge function uses SERVICE_ROLE_KEY, which authenticates
-- as the `service_role` Postgres role. The initial device_tokens migration
-- only granted access to `authenticated`, so the edge function got
-- "permission denied for table device_tokens" when trying to look up
-- which devices to push to.

GRANT USAGE ON SCHEMA turfmapp_expenses TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON turfmapp_expenses.device_tokens TO service_role;
