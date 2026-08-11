DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM gatcha_nft_transfers
        WHERE status = 'CLAIM_READY' OR claim_request_hash IS NOT NULL
    ) OR EXISTS (
        SELECT 1 FROM gatcha_cards
        WHERE nft_status IN ('READY_TO_CLAIM', 'CLAIM_SUBMITTED')
    ) THEN
        RAISE EXCEPTION 'Cannot roll back V45 while NFT claims exist';
    END IF;
END $$;

DROP INDEX IF EXISTS uk_gatcha_nft_transfers_claim_request_hash;

ALTER TABLE gatcha_nft_transfers
    DROP CONSTRAINT chk_gatcha_nft_transfers_claim_shape,
    DROP COLUMN claim_payer_address,
    DROP COLUMN claim_expires_at,
    DROP COLUMN claim_data,
    DROP COLUMN claim_request_hash,
    DROP CONSTRAINT chk_gatcha_nft_transfers_status,
    ADD CONSTRAINT chk_gatcha_nft_transfers_status
        CHECK (status IN (
            'REQUESTED', 'AUTH_PENDING', 'APPROVED', 'SUBMITTED',
            'CONFIRMING', 'COMPLETED', 'FAILED', 'CANCELLED'
        ));

ALTER TABLE gatcha_cards
    DROP CONSTRAINT chk_gatcha_cards_nft_status,
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN (
            'NOT_REQUESTED', 'WITHDRAWAL_REQUESTED', 'READY_TO_MINT',
            'REQUESTED', 'ISSUED', 'FAILED'
        ));
