-- Card/NFT issuance metadata.
-- nft_enabled is a design-level operating flag used by admin registration/edit screens.
-- nft_issued fields live on issued cards because minting happens per serial card.

ALTER TABLE gatcha_designs
    ADD COLUMN nft_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE gatcha_cards
    ADD COLUMN nft_issued  BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN nft_token_id VARCHAR(120),
    ADD COLUMN nft_serial_no BIGINT,
    ADD COLUMN nft_tx_hash  VARCHAR(120),
    ADD COLUMN nft_status   VARCHAR(20) NOT NULL DEFAULT 'NOT_REQUESTED',
    ADD COLUMN nft_recipient_address VARCHAR(255),
    ADD COLUMN nft_contract_address  VARCHAR(255),
    ADD COLUMN nft_token_uri VARCHAR(500),
    ADD COLUMN nft_request_id VARCHAR(120),
    ADD COLUMN nft_error_message TEXT,
    ADD COLUMN nft_requested_at TIMESTAMPTZ,
    ADD COLUMN nft_minted_at    TIMESTAMPTZ,
    ADD COLUMN season_serial_no BIGINT,
    ADD COLUMN nyaon_hunters_linked BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN nyaon_hunters_linked_at TIMESTAMPTZ,
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN ('NOT_REQUESTED', 'REQUESTED', 'ISSUED', 'FAILED'));

CREATE SEQUENCE IF NOT EXISTS gatcha_nft_serial_no_seq;

CREATE TABLE IF NOT EXISTS gatcha_season_serial_counters (
    season_code    VARCHAR(20) PRIMARY KEY,
    next_serial_no BIGINT NOT NULL
);

WITH ranked AS (
    SELECT
        id,
        row_number() OVER (PARTITION BY season_code ORDER BY created_at ASC, id ASC) AS rn
    FROM gatcha_cards
)
UPDATE gatcha_cards c
   SET season_serial_no = ranked.rn
  FROM ranked
 WHERE c.id = ranked.id
   AND c.season_serial_no IS NULL;

INSERT INTO gatcha_season_serial_counters (season_code, next_serial_no)
SELECT season_code, COALESCE(MAX(season_serial_no), 0) + 1
FROM gatcha_cards
GROUP BY season_code
ON CONFLICT (season_code) DO UPDATE
SET next_serial_no = GREATEST(
    gatcha_season_serial_counters.next_serial_no,
    EXCLUDED.next_serial_no
);

CREATE OR REPLACE FUNCTION trg_gatcha_cards_assign_season_serial() RETURNS TRIGGER AS $$
DECLARE
    assigned_serial BIGINT;
BEGIN
    IF NEW.season_serial_no IS NOT NULL THEN
        RETURN NEW;
    END IF;

    INSERT INTO gatcha_season_serial_counters (season_code, next_serial_no)
    VALUES (NEW.season_code, 2)
    ON CONFLICT (season_code) DO UPDATE
       SET next_serial_no = gatcha_season_serial_counters.next_serial_no + 1
    RETURNING next_serial_no - 1 INTO assigned_serial;

    NEW.season_serial_no := assigned_serial;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER gatcha_cards_assign_season_serial
    BEFORE INSERT ON gatcha_cards
    FOR EACH ROW EXECUTE FUNCTION trg_gatcha_cards_assign_season_serial();

ALTER TABLE gatcha_cards
    ALTER COLUMN season_serial_no SET NOT NULL;

CREATE INDEX idx_gatcha_cards_nft_issued
    ON gatcha_cards (nft_issued, created_at DESC);

CREATE INDEX idx_gatcha_cards_nyaon_hunters_linked
    ON gatcha_cards (nyaon_hunters_linked, created_at DESC);

CREATE UNIQUE INDEX ux_gatcha_cards_nft_request_id
    ON gatcha_cards (nft_request_id)
    WHERE nft_request_id IS NOT NULL;

CREATE UNIQUE INDEX ux_gatcha_cards_season_serial_no
    ON gatcha_cards (season_code, season_serial_no);

CREATE UNIQUE INDEX ux_gatcha_cards_nft_serial_no
    ON gatcha_cards (nft_serial_no)
    WHERE nft_serial_no IS NOT NULL;
