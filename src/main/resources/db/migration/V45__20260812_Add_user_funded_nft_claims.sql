ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_status;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN (
            'NOT_REQUESTED', 'WITHDRAWAL_REQUESTED', 'READY_TO_MINT', 'REQUESTED',
            'READY_TO_CLAIM', 'CLAIM_SUBMITTED', 'ISSUED', 'FAILED'
        ));

ALTER TABLE gatcha_nft_transfers
    DROP CONSTRAINT chk_gatcha_nft_transfers_status,
    ADD CONSTRAINT chk_gatcha_nft_transfers_status
        CHECK (status IN (
            'REQUESTED', 'AUTH_PENDING', 'APPROVED', 'CLAIM_READY', 'SUBMITTED',
            'CONFIRMING', 'COMPLETED', 'FAILED', 'CANCELLED'
        )),
    ADD COLUMN claim_request_hash VARCHAR(66),
    ADD COLUMN claim_data TEXT,
    ADD COLUMN claim_expires_at TIMESTAMPTZ,
    ADD COLUMN claim_payer_address VARCHAR(80);

CREATE UNIQUE INDEX uk_gatcha_nft_transfers_claim_request_hash
    ON gatcha_nft_transfers (network, lower(claim_request_hash))
    WHERE claim_request_hash IS NOT NULL;

ALTER TABLE gatcha_nft_transfers
    ADD CONSTRAINT chk_gatcha_nft_transfers_claim_shape CHECK (
        (status <> 'CLAIM_READY')
        OR (
            claim_request_hash IS NOT NULL
            AND claim_data IS NOT NULL
            AND claim_expires_at IS NOT NULL
            AND to_address IS NOT NULL
        )
    );
