CREATE TABLE gatcha_nft_transfer_settings (
    data_scope          VARCHAR(16) PRIMARY KEY,
    withdrawal_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    deposit_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by         BIGINT,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_transfer_settings_scope
        CHECK (data_scope IN ('TEST', 'PRODUCTION'))
);

INSERT INTO gatcha_nft_transfer_settings
    (data_scope, withdrawal_enabled, deposit_enabled)
VALUES
    ('TEST', FALSE, FALSE),
    ('PRODUCTION', FALSE, FALSE)
ON CONFLICT (data_scope) DO NOTHING;

CREATE TABLE gatcha_nft_transfers (
    id                    BIGSERIAL PRIMARY KEY,
    request_id            UUID NOT NULL UNIQUE,
    user_id               BIGINT NOT NULL,
    card_id               BIGINT NOT NULL REFERENCES gatcha_cards(id) ON DELETE RESTRICT,
    direction             VARCHAR(16) NOT NULL,
    status                VARCHAR(32) NOT NULL,
    data_scope            VARCHAR(16) NOT NULL,
    network               VARCHAR(40) NOT NULL,
    contract_address      VARCHAR(80),
    token_id              VARCHAR(120),
    from_address          VARCHAR(80),
    to_address            VARCHAR(80),
    tx_hash               VARCHAR(160),
    fee_amount            NUMERIC(36,18),
    fee_currency          VARCHAR(16),
    failure_reason        VARCHAR(500),
    idempotency_key       VARCHAR(128),
    requested_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    authorized_at         TIMESTAMPTZ,
    submitted_at          TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_transfers_direction
        CHECK (direction IN ('WITHDRAWAL', 'DEPOSIT')),
    CONSTRAINT chk_gatcha_nft_transfers_status
        CHECK (status IN (
            'REQUESTED', 'AUTH_PENDING', 'APPROVED', 'SUBMITTED',
            'CONFIRMING', 'COMPLETED', 'FAILED', 'CANCELLED'
        )),
    CONSTRAINT chk_gatcha_nft_transfers_scope
        CHECK (data_scope IN ('TEST', 'PRODUCTION'))
);

CREATE UNIQUE INDEX uk_gatcha_nft_transfers_user_idempotency
    ON gatcha_nft_transfers (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX uk_gatcha_nft_transfers_tx_hash
    ON gatcha_nft_transfers (network, lower(tx_hash))
    WHERE tx_hash IS NOT NULL;

CREATE INDEX idx_gatcha_nft_transfers_user_requested
    ON gatcha_nft_transfers (user_id, requested_at DESC);

CREATE INDEX idx_gatcha_nft_transfers_admin_search
    ON gatcha_nft_transfers (data_scope, direction, status, requested_at DESC);

CREATE INDEX idx_gatcha_nft_transfers_card
    ON gatcha_nft_transfers (card_id, requested_at DESC);

INSERT INTO gatcha_nft_transfers (
    request_id,
    user_id,
    card_id,
    direction,
    status,
    data_scope,
    network,
    contract_address,
    token_id,
    to_address,
    tx_hash,
    requested_at,
    submitted_at,
    completed_at,
    updated_at
)
SELECT
    gen_random_uuid(),
    c.user_id,
    c.id,
    'WITHDRAWAL',
    CASE
        WHEN c.nft_status = 'ISSUED' THEN 'COMPLETED'
        WHEN c.nft_status = 'FAILED' THEN 'FAILED'
        WHEN c.nft_status IN ('READY_TO_MINT', 'REQUESTED') THEN 'APPROVED'
        ELSE 'REQUESTED'
    END,
    CASE WHEN c.nft_chain IN ('POLYGON', 'ETHEREUM') THEN 'PRODUCTION' ELSE 'TEST' END,
    COALESCE(c.nft_chain, 'POLYGON_AMOY'),
    c.nft_contract_address,
    c.nft_token_id,
    c.nft_recipient_address,
    c.nft_tx_hash,
    COALESCE(c.nft_requested_at, c.updated_at, c.created_at),
    c.nft_minted_at,
    CASE WHEN c.nft_status = 'ISSUED' THEN c.nft_minted_at END,
    COALESCE(c.nft_minted_at, c.updated_at, c.created_at)
FROM gatcha_cards c
WHERE c.nft_status <> 'NOT_REQUESTED'
  AND NOT EXISTS (
      SELECT 1
      FROM gatcha_nft_transfers t
      WHERE t.card_id = c.id
        AND t.direction = 'WITHDRAWAL'
  );
