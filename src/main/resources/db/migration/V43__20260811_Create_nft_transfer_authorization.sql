CREATE TABLE gatcha_nft_withdrawal_challenges (
    challenge_id       UUID PRIMARY KEY,
    user_id            BIGINT NOT NULL,
    card_id            BIGINT NOT NULL REFERENCES gatcha_cards(id) ON DELETE RESTRICT,
    data_scope         VARCHAR(16) NOT NULL,
    wallet_address     VARCHAR(80) NOT NULL,
    network            VARCHAR(40) NOT NULL,
    chain_id           BIGINT NOT NULL,
    contract_address   VARCHAR(80) NOT NULL,
    token_id           VARCHAR(120),
    typed_data_json    JSONB NOT NULL,
    nonce              VARCHAR(64) NOT NULL UNIQUE,
    status             VARCHAR(32) NOT NULL DEFAULT 'SIGNATURE_PENDING',
    otp_hash           VARCHAR(128),
    otp_salt           VARCHAR(128),
    otp_attempts       INTEGER NOT NULL DEFAULT 0,
    otp_resend_count   INTEGER NOT NULL DEFAULT 0,
    otp_sent_at        TIMESTAMPTZ,
    otp_expires_at     TIMESTAMPTZ,
    wallet_verified_at TIMESTAMPTZ,
    consumed_at        TIMESTAMPTZ,
    expires_at         TIMESTAMPTZ NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_withdrawal_challenge_scope
        CHECK (data_scope IN ('TEST', 'PRODUCTION')),
    CONSTRAINT chk_gatcha_nft_withdrawal_challenge_status
        CHECK (status IN ('SIGNATURE_PENDING', 'EMAIL_PENDING', 'CONSUMED', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT chk_gatcha_nft_withdrawal_challenge_attempts
        CHECK (otp_attempts BETWEEN 0 AND 5),
    CONSTRAINT chk_gatcha_nft_withdrawal_challenge_resends
        CHECK (otp_resend_count BETWEEN 0 AND 3)
);

CREATE UNIQUE INDEX uk_gatcha_nft_withdrawal_challenge_active_card
    ON gatcha_nft_withdrawal_challenges (user_id, card_id)
    WHERE status IN ('SIGNATURE_PENDING', 'EMAIL_PENDING');

CREATE INDEX idx_gatcha_nft_withdrawal_challenge_expiry
    ON gatcha_nft_withdrawal_challenges (status, expires_at);

ALTER TABLE gatcha_nft_transfers
    ADD COLUMN retryable BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE gatcha_cards
    ADD COLUMN nft_in_custody BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN nft_custodied_at TIMESTAMPTZ,
    ADD COLUMN nft_custody_address VARCHAR(128),
    ADD CONSTRAINT chk_gatcha_cards_nft_custody_state CHECK (
        nft_in_custody = FALSE
        OR (
            nft_issued = FALSE
            AND nft_token_id IS NOT NULL
            AND nft_contract_address IS NOT NULL
            AND nft_chain IS NOT NULL
            AND nft_custodied_at IS NOT NULL
            AND nft_custody_address IS NOT NULL
        )
    );

CREATE INDEX idx_gatcha_cards_nft_in_custody
    ON gatcha_cards (nft_in_custody, updated_at DESC)
    WHERE nft_in_custody = TRUE;

CREATE UNIQUE INDEX uk_gatcha_nft_transfer_active_deposit_card
    ON gatcha_nft_transfers (user_id, card_id)
    WHERE direction = 'DEPOSIT' AND status IN ('AUTH_PENDING', 'REQUESTED', 'CONFIRMING');
