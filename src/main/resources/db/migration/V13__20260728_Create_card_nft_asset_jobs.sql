-- NFT 원본 이미지 업로드/민팅 worker 큐.
-- 업로드 요청 전에는 row가 없으므로 worker는 처리할 작업이 없다.

CREATE TABLE IF NOT EXISTS gatcha_nft_asset_jobs (
    id                    BIGSERIAL PRIMARY KEY,
    card_id               BIGINT NOT NULL REFERENCES gatcha_cards(id),
    status                VARCHAR(24) NOT NULL DEFAULT 'UPLOADED',
    bucket_name           VARCHAR(120) NOT NULL,
    original_key          VARCHAR(500) NOT NULL,
    original_content_type VARCHAR(120),
    original_size_bytes   BIGINT,
    original_sha256       CHAR(64),
    thumbnail_key         VARCHAR(500),
    metadata_key          VARCHAR(500),
    metadata_uri          VARCHAR(700),
    ipfs_cid              VARCHAR(120),
    token_id              VARCHAR(120),
    tx_hash               VARCHAR(120),
    archive_tagged        BOOLEAN NOT NULL DEFAULT FALSE,
    request_id            VARCHAR(160) NOT NULL,
    error_message         TEXT,
    requested_by          BIGINT,
    locked_at             TIMESTAMPTZ,
    processed_at          TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_asset_jobs_status
        CHECK (status IN ('UPLOADED', 'PROCESSING', 'MINTED', 'FAILED'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_gatcha_nft_asset_jobs_card_open
    ON gatcha_nft_asset_jobs (card_id)
    WHERE status IN ('UPLOADED', 'PROCESSING');

CREATE UNIQUE INDEX IF NOT EXISTS ux_gatcha_nft_asset_jobs_request_id
    ON gatcha_nft_asset_jobs (request_id);

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_jobs_status_created
    ON gatcha_nft_asset_jobs (status, created_at);
