-- NFT 원본 업로드/민팅 작업의 append-only 처리 이력.
-- gatcha_nft_asset_jobs 는 현재 작업 상태를 보관하고, 이 테이블은 상태 변경/수동 처리 흐름을 보존한다.

CREATE TABLE IF NOT EXISTS gatcha_nft_asset_job_events (
    id                   BIGSERIAL PRIMARY KEY,
    job_id               BIGINT REFERENCES gatcha_nft_asset_jobs(id) ON DELETE SET NULL,
    card_id              BIGINT NOT NULL REFERENCES gatcha_cards(id),
    event_type           VARCHAR(40) NOT NULL,
    status               VARCHAR(24) NOT NULL,
    bucket_name          VARCHAR(120),
    original_key         VARCHAR(500),
    original_file_name   VARCHAR(500),
    original_sha256      CHAR(64),
    metadata_uri         VARCHAR(700),
    ipfs_cid             VARCHAR(120),
    token_id             VARCHAR(120),
    tx_hash              VARCHAR(120),
    message              TEXT,
    actor_type           VARCHAR(24) NOT NULL DEFAULT 'SYSTEM',
    actor_id             BIGINT,
    actor_ip             VARCHAR(80),
    snapshot             JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_asset_job_events_type
        CHECK (event_type IN ('UPLOADED', 'CLAIMED', 'MINTED', 'FAILED', 'CANCELLED', 'RETRIED', 'DELETED')),
    CONSTRAINT chk_gatcha_nft_asset_job_events_actor
        CHECK (actor_type IN ('ADMIN', 'WORKER', 'SYSTEM'))
);

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_job_events_created
    ON gatcha_nft_asset_job_events (created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_job_events_job
    ON gatcha_nft_asset_job_events (job_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_job_events_card
    ON gatcha_nft_asset_job_events (card_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_job_events_status_created
    ON gatcha_nft_asset_job_events (status, created_at DESC);
