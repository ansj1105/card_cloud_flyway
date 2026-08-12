ALTER TABLE gatcha_nft_withdrawal_challenges
    ADD COLUMN gas_funding_method VARCHAR(32),
    ADD COLUMN gas_funding_wallet_id BIGINT,
    ADD COLUMN gas_payer_address VARCHAR(80),
    ADD COLUMN email_token_hash VARCHAR(64),
    ADD COLUMN email_token_expires_at TIMESTAMPTZ,
    ADD COLUMN email_verified_at TIMESTAMPTZ,
    ADD COLUMN email_sent_at TIMESTAMPTZ,
    ADD COLUMN email_resend_count INTEGER NOT NULL DEFAULT 0;

UPDATE gatcha_nft_withdrawal_challenges
   SET gas_funding_method = CASE
       WHEN COALESCE(gas_required_amount_wei, 0) > 0 THEN 'SERVICE_WALLET_DEPOSIT'
       ELSE 'METAMASK'
   END;

UPDATE gatcha_nft_withdrawal_challenges
   SET status = 'CANCELLED', updated_at = NOW()
 WHERE status = 'EMAIL_PENDING' AND consumed_at IS NULL;

ALTER TABLE gatcha_nft_withdrawal_challenges
    ALTER COLUMN gas_funding_method SET NOT NULL,
    ALTER COLUMN gas_funding_method SET DEFAULT 'METAMASK',
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_gas_funding_method
        CHECK (gas_funding_method IN ('KORION_WALLET', 'METAMASK', 'SERVICE_WALLET_DEPOSIT'));

ALTER TABLE gatcha_nft_withdrawal_challenges
    DROP CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status,
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status
        CHECK (status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING', 'EMAIL_VERIFIED',
                          'CONSUMED', 'EXPIRED', 'CANCELLED'));

DROP INDEX uk_gatcha_nft_withdrawal_challenge_active_card;

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_challenge_active_card
    ON gatcha_nft_withdrawal_challenges (user_id, card_id)
    WHERE status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING', 'EMAIL_VERIFIED');

CREATE INDEX idx_gatcha_nft_withdrawal_gas_wallet
    ON gatcha_nft_withdrawal_challenges (gas_funding_wallet_id)
    WHERE gas_funding_method = 'KORION_WALLET';
