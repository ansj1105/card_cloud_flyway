ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS chk_gatcha_cards_nft_chain;

ALTER TABLE gatcha_cards
    DROP COLUMN IF EXISTS nft_chain;
