ALTER TABLE gatcha_nft_asset_job_events
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_asset_job_events_type;

ALTER TABLE gatcha_nft_asset_job_events
    ADD CONSTRAINT chk_gatcha_nft_asset_job_events_type
        CHECK (event_type IN (
            'UPLOADED',
            'UPLOAD_SKIPPED',
            'APPROVED',
            'CLAIMED',
            'MINTED',
            'FAILED',
            'CANCELLED',
            'RETRIED',
            'DELETED'
        ));
