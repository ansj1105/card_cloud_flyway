-- Roll back to the pre-withdrawal-request NFT status set.
-- Run only after moving any WITHDRAWAL_REQUESTED rows to NOT_REQUESTED or FAILED.

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_status;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN (
            'NOT_REQUESTED',
            'READY_TO_MINT',
            'REQUESTED',
            'ISSUED',
            'FAILED'
        ));
