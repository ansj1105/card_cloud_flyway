ALTER TABLE gatcha_nft_withdrawal_challenges
    ALTER COLUMN wallet_address DROP NOT NULL,
    ALTER COLUMN typed_data_json DROP NOT NULL,
    ADD COLUMN gas_deposit_address VARCHAR(80),
    ADD COLUMN gas_required_amount_wei NUMERIC(78, 0),
    ADD COLUMN gas_deposit_tx_hash VARCHAR(160),
    ADD COLUMN gas_deposit_amount_wei NUMERIC(78, 0),
    ADD COLUMN gas_deposit_block BIGINT,
    ADD COLUMN gas_deposit_confirmations INTEGER,
    ADD COLUMN gas_verified_at TIMESTAMPTZ;

ALTER TABLE gatcha_nft_withdrawal_challenges
    DROP CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status,
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status
        CHECK (status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING', 'CONSUMED', 'EXPIRED', 'CANCELLED')),
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_gas_amounts CHECK (
        (gas_required_amount_wei IS NULL OR gas_required_amount_wei > 0)
        AND (gas_deposit_amount_wei IS NULL OR gas_deposit_amount_wei > 0)
    ),
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_gas_confirmations
        CHECK (gas_deposit_confirmations IS NULL OR gas_deposit_confirmations >= 0);

DROP INDEX uk_gatcha_nft_withdrawal_challenge_active_card;

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_challenge_active_card
    ON gatcha_nft_withdrawal_challenges (user_id, card_id)
    WHERE status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING');

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_gas_deposit_tx
    ON gatcha_nft_withdrawal_challenges (network, lower(gas_deposit_tx_hash))
    WHERE gas_deposit_tx_hash IS NOT NULL;

ALTER TABLE gatcha_nft_transfers
    ADD COLUMN gas_deposit_tx_hash VARCHAR(160),
    ADD COLUMN gas_fee_amount_wei NUMERIC(78, 0);
