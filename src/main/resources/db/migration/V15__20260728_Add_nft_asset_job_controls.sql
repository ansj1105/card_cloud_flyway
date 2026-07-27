ALTER TABLE gatcha_nft_asset_jobs
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_asset_jobs_status;

ALTER TABLE gatcha_nft_asset_jobs
    ADD CONSTRAINT chk_gatcha_nft_asset_jobs_status
        CHECK (status IN ('UPLOADED', 'PROCESSING', 'MINTED', 'FAILED', 'CANCELLED'));

CREATE TABLE IF NOT EXISTS gatcha_nft_asset_worker_settings (
    id              SMALLINT PRIMARY KEY DEFAULT 1,
    auto_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by      BIGINT,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_gatcha_nft_asset_worker_settings_singleton CHECK (id = 1)
);

INSERT INTO gatcha_nft_asset_worker_settings (id, auto_enabled)
VALUES (1, FALSE)
ON CONFLICT (id) DO NOTHING;
