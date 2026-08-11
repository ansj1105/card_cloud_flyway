DELETE FROM gatcha_nft_asset_job_events e
USING gatcha_v41_inserted_event_backup b
WHERE e.id = b.event_id;

UPDATE gatcha_nft_asset_jobs j
SET status = b.status,
    metadata_uri = b.metadata_uri,
    token_id = b.token_id,
    tx_hash = b.tx_hash,
    locked_at = b.locked_at,
    processed_at = b.processed_at,
    updated_at = b.updated_at
FROM gatcha_v41_nft_job_backup b
WHERE j.id = b.job_id;

UPDATE gatcha_draws d
SET rate_snapshot = b.original_snapshot
FROM gatcha_v41_snapshot_backup b
WHERE b.entity_type = 'DRAW_RATE'
  AND b.entity_id = d.draw_id::text;

UPDATE gatcha_nft_asset_job_events e
SET snapshot = b.original_snapshot
FROM gatcha_v41_snapshot_backup b
WHERE b.entity_type = 'NFT_EVENT'
  AND b.entity_id = e.id::text;

DROP TABLE gatcha_v41_inserted_event_backup;
DROP TABLE gatcha_v41_nft_job_backup;
DROP TABLE gatcha_v41_snapshot_backup;
