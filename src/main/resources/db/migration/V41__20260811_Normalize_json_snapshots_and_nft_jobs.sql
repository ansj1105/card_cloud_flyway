CREATE TABLE gatcha_v41_snapshot_backup (
    entity_type VARCHAR(32) NOT NULL,
    entity_id VARCHAR(64) NOT NULL,
    original_snapshot JSONB NOT NULL,
    PRIMARY KEY (entity_type, entity_id)
);

CREATE TABLE gatcha_v41_nft_job_backup (
    job_id BIGINT PRIMARY KEY,
    status VARCHAR(20) NOT NULL,
    metadata_uri VARCHAR(500),
    token_id VARCHAR(120),
    tx_hash VARCHAR(160),
    locked_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE gatcha_v41_inserted_event_backup (
    event_id BIGINT PRIMARY KEY
);

INSERT INTO gatcha_v41_snapshot_backup (entity_type, entity_id, original_snapshot)
SELECT 'DRAW_RATE', draw_id::text, rate_snapshot
FROM gatcha_draws
WHERE jsonb_typeof(rate_snapshot) = 'string'
  AND jsonb_typeof((rate_snapshot #>> '{}')::jsonb) = 'object';

UPDATE gatcha_draws d
SET rate_snapshot = (d.rate_snapshot #>> '{}')::jsonb
FROM gatcha_v41_snapshot_backup b
WHERE b.entity_type = 'DRAW_RATE'
  AND b.entity_id = d.draw_id::text;

INSERT INTO gatcha_v41_snapshot_backup (entity_type, entity_id, original_snapshot)
SELECT 'NFT_EVENT', id::text, snapshot
FROM gatcha_nft_asset_job_events
WHERE jsonb_typeof(snapshot) = 'string'
  AND jsonb_typeof((snapshot #>> '{}')::jsonb) = 'object';

UPDATE gatcha_nft_asset_job_events e
SET snapshot = (e.snapshot #>> '{}')::jsonb
FROM gatcha_v41_snapshot_backup b
WHERE b.entity_type = 'NFT_EVENT'
  AND b.entity_id = e.id::text;

INSERT INTO gatcha_v41_nft_job_backup
    (job_id, status, metadata_uri, token_id, tx_hash, locked_at, processed_at, updated_at)
SELECT j.id, j.status, j.metadata_uri, j.token_id, j.tx_hash, j.locked_at, j.processed_at, j.updated_at
FROM gatcha_nft_asset_jobs j
JOIN gatcha_cards c ON c.id = j.card_id
WHERE c.nft_issued = TRUE
  AND c.nft_status = 'ISSUED'
  AND j.status IN ('UPLOADED', 'PROCESSING');

UPDATE gatcha_nft_asset_jobs j
SET status = 'MINTED',
    metadata_uri = COALESCE(j.metadata_uri, c.nft_token_uri),
    token_id = c.nft_token_id,
    tx_hash = c.nft_tx_hash,
    locked_at = NULL,
    processed_at = COALESCE(j.processed_at, c.nft_minted_at, NOW()),
    updated_at = NOW()
FROM gatcha_cards c, gatcha_v41_nft_job_backup b
WHERE b.job_id = j.id
  AND c.id = j.card_id;

WITH inserted AS (
    INSERT INTO gatcha_nft_asset_job_events
        (job_id, card_id, event_type, status, bucket_name, original_key, original_file_name,
         original_sha256, metadata_uri, ipfs_cid, token_id, tx_hash, message, actor_type, snapshot)
    SELECT
        j.id,
        j.card_id,
        'MINTED',
        'MINTED',
        j.bucket_name,
        j.original_key,
        j.original_file_name,
        j.original_sha256,
        j.metadata_uri,
        j.ipfs_cid,
        j.token_id,
        j.tx_hash,
        'V41 reconciled the NFT job with its issued card.',
        'SYSTEM',
        jsonb_build_object(
            'id', j.id,
            'cardId', j.card_id,
            'status', j.status,
            'metadataUri', j.metadata_uri,
            'tokenId', j.token_id,
            'txHash', j.tx_hash
        )
    FROM gatcha_nft_asset_jobs j
    JOIN gatcha_cards c ON c.id = j.card_id
    WHERE j.status = 'MINTED'
      AND c.nft_issued = TRUE
      AND c.nft_status = 'ISSUED'
      AND NOT EXISTS (
          SELECT 1
          FROM gatcha_nft_asset_job_events e
          WHERE e.job_id = j.id
            AND e.event_type = 'MINTED'
      )
    RETURNING id
)
INSERT INTO gatcha_v41_inserted_event_backup (event_id)
SELECT id FROM inserted;
