DROP INDEX IF EXISTS idx_gatcha_nft_asset_jobs_assignment;
DROP INDEX IF EXISTS ux_gatcha_nft_asset_jobs_design_serial_open;

ALTER TABLE gatcha_nft_asset_jobs
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_asset_jobs_assignment_status;

DELETE FROM gatcha_nft_asset_job_events
 WHERE card_id IS NULL;

DELETE FROM gatcha_nft_asset_jobs
 WHERE card_id IS NULL;

ALTER TABLE gatcha_nft_asset_job_events
    ALTER COLUMN card_id SET NOT NULL;

ALTER TABLE gatcha_nft_asset_jobs
    ALTER COLUMN card_id SET NOT NULL;

ALTER TABLE gatcha_nft_asset_jobs
    DROP COLUMN IF EXISTS assignment_status,
    DROP COLUMN IF EXISTS rarity_code,
    DROP COLUMN IF EXISTS serial_no,
    DROP COLUMN IF EXISTS design_id;
