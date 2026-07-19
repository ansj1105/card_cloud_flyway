DROP INDEX IF EXISTS idx_gatcha_cards_nft_issued;
DROP INDEX IF EXISTS ux_gatcha_cards_nft_request_id;
DROP INDEX IF EXISTS idx_gatcha_cards_nyaon_hunters_linked;
DROP INDEX IF EXISTS ux_gatcha_cards_season_serial_no;
DROP INDEX IF EXISTS ux_gatcha_cards_nft_serial_no;

DROP TRIGGER IF EXISTS gatcha_cards_assign_season_serial ON gatcha_cards;
DROP FUNCTION IF EXISTS trg_gatcha_cards_assign_season_serial();
DROP TABLE IF EXISTS gatcha_season_serial_counters;
DROP SEQUENCE IF EXISTS gatcha_nft_serial_no_seq;

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_status,
    DROP COLUMN IF EXISTS nyaon_hunters_linked_at,
    DROP COLUMN IF EXISTS nyaon_hunters_linked,
    DROP COLUMN IF EXISTS season_serial_no,
    DROP COLUMN IF EXISTS nft_minted_at,
    DROP COLUMN IF EXISTS nft_requested_at,
    DROP COLUMN IF EXISTS nft_error_message,
    DROP COLUMN IF EXISTS nft_request_id,
    DROP COLUMN IF EXISTS nft_token_uri,
    DROP COLUMN IF EXISTS nft_contract_address,
    DROP COLUMN IF EXISTS nft_recipient_address,
    DROP COLUMN IF EXISTS nft_status,
    DROP COLUMN IF EXISTS nft_tx_hash,
    DROP COLUMN IF EXISTS nft_serial_no,
    DROP COLUMN IF EXISTS nft_token_id,
    DROP COLUMN IF EXISTS nft_issued;

ALTER TABLE gatcha_designs
    DROP COLUMN IF EXISTS nft_enabled;
