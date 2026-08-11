DROP INDEX IF EXISTS uk_gatcha_nft_transfer_active_deposit_card;

DROP INDEX IF EXISTS idx_gatcha_cards_nft_in_custody;

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_custody_state,
    DROP COLUMN IF EXISTS nft_custodied_at,
    DROP COLUMN IF EXISTS nft_custody_address,
    DROP COLUMN IF EXISTS nft_in_custody;

ALTER TABLE gatcha_nft_transfers
    DROP COLUMN IF EXISTS retryable;

DROP TABLE IF EXISTS gatcha_nft_withdrawal_challenges;
