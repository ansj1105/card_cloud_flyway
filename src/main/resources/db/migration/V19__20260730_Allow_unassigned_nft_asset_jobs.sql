-- NFT 원본은 카드가 실제 발급되기 전에도 업로드될 수 있다.
-- 이때 gatcha_cards placeholder를 만들지 않고 design_id/serial_no로 대기시키며,
-- 실제 카드 발급 후 card_id를 매핑한다.

ALTER TABLE gatcha_nft_asset_jobs
    ALTER COLUMN card_id DROP NOT NULL;

ALTER TABLE gatcha_nft_asset_job_events
    ALTER COLUMN card_id DROP NOT NULL;

ALTER TABLE gatcha_nft_asset_jobs
    ADD COLUMN IF NOT EXISTS design_id VARCHAR(40),
    ADD COLUMN IF NOT EXISTS serial_no INT,
    ADD COLUMN IF NOT EXISTS rarity_code VARCHAR(10),
    ADD COLUMN IF NOT EXISTS assignment_status VARCHAR(20) NOT NULL DEFAULT 'UNASSIGNED';

UPDATE gatcha_nft_asset_jobs j
   SET design_id = c.design_id,
       serial_no = c.serial_no,
       rarity_code = c.rarity_code,
       assignment_status = 'ASSIGNED'
  FROM gatcha_cards c
 WHERE j.card_id = c.id
   AND (j.design_id IS NULL OR j.serial_no IS NULL OR j.rarity_code IS NULL OR j.assignment_status <> 'ASSIGNED');

WITH placeholder_cards AS (
    SELECT DISTINCT c.id
    FROM gatcha_cards c
    JOIN gatcha_nft_asset_jobs j ON j.card_id = c.id
    WHERE c.source = 'ADMIN'
      AND c.user_id = 4
      AND c.draw_id IS NULL
      AND c.upgrade_id IS NULL
      AND j.status IN ('UPLOADED', 'PROCESSING')
),
detached_jobs AS (
    UPDATE gatcha_nft_asset_jobs j
       SET card_id = NULL,
           assignment_status = 'UNASSIGNED',
           updated_at = NOW()
      FROM placeholder_cards pc
     WHERE j.card_id = pc.id
     RETURNING j.id, pc.id AS placeholder_card_id
),
detached_events AS (
    UPDATE gatcha_nft_asset_job_events e
       SET card_id = NULL
      FROM detached_jobs dj
     WHERE e.card_id = dj.placeholder_card_id
     RETURNING e.id
)
DELETE FROM gatcha_cards c
 USING placeholder_cards pc
 WHERE c.id = pc.id;

ALTER TABLE gatcha_nft_asset_jobs
    DROP CONSTRAINT IF EXISTS chk_gatcha_nft_asset_jobs_assignment_status;

ALTER TABLE gatcha_nft_asset_jobs
    ADD CONSTRAINT chk_gatcha_nft_asset_jobs_assignment_status
        CHECK (assignment_status IN ('UNASSIGNED', 'ASSIGNED'));

CREATE UNIQUE INDEX IF NOT EXISTS ux_gatcha_nft_asset_jobs_design_serial_open
    ON gatcha_nft_asset_jobs (design_id, serial_no)
    WHERE card_id IS NULL
      AND design_id IS NOT NULL
      AND serial_no IS NOT NULL
      AND status IN ('UPLOADED', 'PROCESSING');

CREATE INDEX IF NOT EXISTS idx_gatcha_nft_asset_jobs_assignment
    ON gatcha_nft_asset_jobs (assignment_status, design_id, serial_no, status);
