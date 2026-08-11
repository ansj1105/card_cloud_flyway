ALTER TABLE gatcha_nft_transfers
    DROP COLUMN IF EXISTS gas_fee_amount_wei,
    DROP COLUMN IF EXISTS gas_deposit_tx_hash;

DROP INDEX IF EXISTS uk_gatcha_nft_withdrawal_gas_deposit_tx;
DROP INDEX IF EXISTS uk_gatcha_nft_withdrawal_challenge_active_card;

UPDATE gatcha_nft_withdrawal_challenges
SET status = 'CANCELLED'
WHERE status = 'GAS_PENDING';

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_challenge_active_card
    ON gatcha_nft_withdrawal_challenges (user_id, card_id)
    WHERE status IN ('SIGNATURE_PENDING', 'EMAIL_PENDING');

ALTER TABLE gatcha_nft_withdrawal_challenges
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_withdrawal_gas_confirmations,
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_withdrawal_gas_amounts,
    DROP CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status,
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status
        CHECK (status IN ('SIGNATURE_PENDING', 'EMAIL_PENDING', 'CONSUMED', 'EXPIRED', 'CANCELLED')),
    DROP COLUMN IF EXISTS gas_verified_at,
    DROP COLUMN IF EXISTS gas_deposit_confirmations,
    DROP COLUMN IF EXISTS gas_deposit_block,
    DROP COLUMN IF EXISTS gas_deposit_amount_wei,
    DROP COLUMN IF EXISTS gas_deposit_tx_hash,
    DROP COLUMN IF EXISTS gas_required_amount_wei,
    DROP COLUMN IF EXISTS gas_deposit_address;

DELETE FROM gatcha_nft_withdrawal_challenges
WHERE wallet_address IS NULL OR typed_data_json IS NULL;

ALTER TABLE gatcha_nft_withdrawal_challenges
    ALTER COLUMN wallet_address SET NOT NULL,
    ALTER COLUMN typed_data_json SET NOT NULL;
