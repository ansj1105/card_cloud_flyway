ALTER TABLE gatcha_cards
    ADD COLUMN nft_chain VARCHAR(40);

UPDATE gatcha_cards
   SET nft_chain = 'POLYGON_AMOY'
 WHERE nft_issued = TRUE
   AND nft_contract_address IS NOT NULL;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT chk_gatcha_cards_nft_chain
    CHECK (
        nft_chain IS NULL OR nft_chain IN (
            'POLYGON_AMOY',
            'POLYGON',
            'ETHEREUM_SEPOLIA',
            'ETHEREUM'
        )
    );
