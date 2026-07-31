-- Separate mint approval from mint execution.
-- READY_TO_MINT means the card has an owner, a matched original asset job, and is approved for the worker.

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_status;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT chk_gatcha_cards_nft_status
        CHECK (nft_status IN ('NOT_REQUESTED', 'READY_TO_MINT', 'REQUESTED', 'ISSUED', 'FAILED'));
