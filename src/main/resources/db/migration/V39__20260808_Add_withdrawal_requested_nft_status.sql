-- Allow user-initiated NFT withdrawal requests before admin mint approval.

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_status;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN (
            'NOT_REQUESTED',
            'WITHDRAWAL_REQUESTED',
            'READY_TO_MINT',
            'REQUESTED',
            'ISSUED',
            'FAILED'
        ));
