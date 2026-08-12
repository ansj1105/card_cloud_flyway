DROP INDEX IF EXISTS idx_gatcha_nft_withdrawal_gas_wallet;

DROP INDEX IF EXISTS uk_gatcha_nft_withdrawal_challenge_active_card;

UPDATE gatcha_nft_withdrawal_challenges
   SET status = 'EMAIL_PENDING', updated_at = NOW()
 WHERE status = 'EMAIL_VERIFIED';

ALTER TABLE gatcha_nft_withdrawal_challenges
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_withdrawal_challenge_status,
    ADD CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status
        CHECK (status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING',
                          'CONSUMED', 'EXPIRED', 'CANCELLED'));

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_challenge_active_card
    ON gatcha_nft_withdrawal_challenges (user_id, card_id)
    WHERE status IN ('GAS_PENDING', 'SIGNATURE_PENDING', 'EMAIL_PENDING');

ALTER TABLE gatcha_nft_withdrawal_challenges
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_withdrawal_gas_funding_method,
    DROP COLUMN IF EXISTS gas_funding_wallet_id,
    DROP COLUMN IF EXISTS gas_payer_address,
    DROP COLUMN IF EXISTS email_token_hash,
    DROP COLUMN IF EXISTS email_token_expires_at,
    DROP COLUMN IF EXISTS email_verified_at,
    DROP COLUMN IF EXISTS email_sent_at,
    DROP COLUMN IF EXISTS email_resend_count,
    DROP COLUMN IF EXISTS gas_funding_method;
