-- APNs device token registry for push notifications.
-- One row per physical device (unique on device_token); membership_id
-- tracks which user on which workspace should receive pushes from that device.

CREATE TABLE turfmapp_expenses.device_tokens (
    id              uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
    membership_id   uuid        NOT NULL
                                REFERENCES turfmapp_expenses.workspace_memberships(id)
                                ON DELETE CASCADE,
    device_token    text        NOT NULL UNIQUE,
    platform        text        NOT NULL DEFAULT 'ios',
    created_at      timestamptz DEFAULT now() NOT NULL,
    updated_at      timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE turfmapp_expenses.device_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only read/write tokens for their own memberships.
CREATE POLICY device_tokens_own ON turfmapp_expenses.device_tokens
    USING (
        membership_id IN (
            SELECT id FROM turfmapp_expenses.workspace_memberships
            WHERE user_id = auth.uid() AND status = 'active'
        )
    );

-- Automatically bump updated_at on upsert.
CREATE OR REPLACE FUNCTION turfmapp_expenses.touch_device_token_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;

CREATE TRIGGER device_tokens_updated_at
    BEFORE UPDATE ON turfmapp_expenses.device_tokens
    FOR EACH ROW EXECUTE PROCEDURE turfmapp_expenses.touch_device_token_updated_at();

-- Allow authenticated role to insert/update their own rows.
GRANT SELECT, INSERT, UPDATE ON turfmapp_expenses.device_tokens TO authenticated;
