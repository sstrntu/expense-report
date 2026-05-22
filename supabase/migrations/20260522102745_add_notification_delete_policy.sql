-- Lets a recipient delete (clear) their own notifications from the in-app
-- inbox. The existing read/update policies already restrict to the recipient
-- via current_membership_id; we mirror that here for delete.
--
-- Grants DELETE explicitly because the schema move from public to
-- turfmapp_expenses did not carry forward the default authenticated grants
-- (the previous policies only needed SELECT/UPDATE/INSERT).

grant delete on turfmapp_expenses.notifications to authenticated;

create policy "members can delete own notifications" on turfmapp_expenses.notifications
for delete using (recipient_membership_id = turfmapp_expenses.current_membership_id(workspace_id));
