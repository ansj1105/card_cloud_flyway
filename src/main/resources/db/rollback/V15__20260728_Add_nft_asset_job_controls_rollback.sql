UPDATE gatcha_nft_asset_jobs
   SET status = 'FAILED',
       error_message = COALESCE(error_message, 'Rolled back from CANCELLED status.'),
       updated_at = now()
 WHERE status = 'CANCELLED';

DROP TABLE IF EXISTS gatcha_nft_asset_worker_settings;

ALTER TABLE gatcha_nft_asset_jobs
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_asset_jobs_status;

ALTER TABLE gatcha_nft_asset_jobs
    ADD CONSTRAINT chk_gatcha_nft_asset_jobs_status
        CHECK (status IN ('UPLOADED', 'PROCESSING', 'MINTED', 'FAILED'));
