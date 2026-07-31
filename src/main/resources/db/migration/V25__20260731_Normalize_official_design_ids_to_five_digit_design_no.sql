-- Normalize official Season 1 design identifiers to the 5 digit design number policy.
-- Example: KORIS0001COM0001 -> KORIS0001COM00001.
-- Rollback path: restore from pre-migration backup. This also updates dependent cards,
-- design skill mappings, upgrade design-id snapshots, and NFT asset job design_id values.

CREATE TEMP TABLE tmp_official_s01_design_id_map AS
SELECT d.design_id AS old_design_id,
       'KORI'
           || regexp_replace(s.code, '^S([0-9]+)$', 'S')
           || lpad(regexp_replace(s.code, '^S([0-9]+)$', '\1'), 4, '0')
           || r.code
           || lpad(d.design_no::text, 5, '0') AS new_design_id
  FROM gatcha_designs d
  JOIN gatcha_rarities r ON r.id = d.rarity_id
  JOIN gatcha_seasons s ON s.id = r.season_id
 WHERE s.code = 'S01'
   AND (
       (r.code = 'COM' AND d.design_no BETWEEN 1 AND 60)
       OR (r.code = 'ADV' AND d.design_no BETWEEN 61 AND 120)
       OR (r.code = 'RAR' AND d.design_no BETWEEN 121 AND 168)
       OR (r.code = 'HER' AND d.design_no BETWEEN 169 AND 216)
       OR (r.code = 'LEG' AND d.design_no BETWEEN 217 AND 252)
       OR (r.code = 'MYT' AND d.design_no BETWEEN 253 AND 276)
       OR (r.code = 'DIV' AND d.design_no BETWEEN 277 AND 288)
   )
   AND d.design_id IS DISTINCT FROM (
       'KORI'
           || regexp_replace(s.code, '^S([0-9]+)$', 'S')
           || lpad(regexp_replace(s.code, '^S([0-9]+)$', '\1'), 4, '0')
           || r.code
           || lpad(d.design_no::text, 5, '0')
   );

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM tmp_official_s01_design_id_map
         GROUP BY new_design_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Official 5 digit design-id normalization would create duplicate design_id values.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM gatcha_designs d
          JOIN tmp_official_s01_design_id_map m ON m.new_design_id = d.design_id
         WHERE d.design_id <> m.old_design_id
    ) THEN
        RAISE EXCEPTION 'Official 5 digit design-id normalization conflicts with an existing design_id.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM gatcha_cards old_card
          JOIN tmp_official_s01_design_id_map m ON m.old_design_id = old_card.design_id
          JOIN gatcha_cards new_card
            ON new_card.design_id = m.new_design_id
           AND new_card.serial_no = old_card.serial_no
         WHERE new_card.id <> old_card.id
    ) THEN
        RAISE EXCEPTION 'Official 5 digit design-id normalization would create duplicate gatcha_cards serials.';
    END IF;
END $$;

DO $$
BEGIN
    ALTER TABLE gatcha_cards
        ALTER CONSTRAINT gatcha_cards_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
EXCEPTION WHEN undefined_object THEN
    NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE gatcha_design_skills
        ALTER CONSTRAINT gatcha_design_skills_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
EXCEPTION WHEN undefined_object THEN
    NULL;
END $$;

SET CONSTRAINTS gatcha_cards_design_id_fkey, gatcha_design_skills_design_id_fkey DEFERRED;

UPDATE gatcha_nft_asset_jobs old_job
   SET status = 'CANCELLED',
       error_message = '공식 5자리 design_id 정규화 중 같은 design/serial 열린 작업이 있어 중복 작업으로 닫았습니다.',
       updated_at = NOW()
  FROM tmp_official_s01_design_id_map m
 WHERE old_job.design_id = m.old_design_id
   AND old_job.card_id IS NULL
   AND old_job.status IN ('UPLOADED', 'PROCESSING')
   AND EXISTS (
       SELECT 1
         FROM gatcha_nft_asset_jobs keep_job
        WHERE keep_job.design_id = m.new_design_id
          AND keep_job.serial_no = old_job.serial_no
          AND keep_job.card_id IS NULL
          AND keep_job.status IN ('UPLOADED', 'PROCESSING')
          AND keep_job.id <> old_job.id
   );

UPDATE gatcha_designs d
   SET design_id = m.new_design_id,
       updated_at = NOW()
  FROM tmp_official_s01_design_id_map m
 WHERE d.design_id = m.old_design_id;

UPDATE gatcha_cards c
   SET design_id = m.new_design_id,
       card_code = m.new_design_id,
       case_id = 'CASE-' || m.new_design_id || '-' || lpad(c.serial_no::text, 6, '0'),
       updated_at = NOW()
  FROM tmp_official_s01_design_id_map m
 WHERE c.design_id = m.old_design_id;

UPDATE gatcha_design_skills ds
   SET design_id = m.new_design_id
  FROM tmp_official_s01_design_id_map m
 WHERE ds.design_id = m.old_design_id;

UPDATE gatcha_nft_asset_jobs j
   SET design_id = m.new_design_id,
       updated_at = NOW()
  FROM tmp_official_s01_design_id_map m
 WHERE j.design_id = m.old_design_id;

UPDATE gatcha_upgrade_attempts a
   SET consumed_card_design_ids = mapped.next_design_ids
  FROM (
        SELECT a.id,
               jsonb_agg(COALESCE(to_jsonb(m.new_design_id), value) ORDER BY ordinality) AS next_design_ids
          FROM gatcha_upgrade_attempts a
          CROSS JOIN LATERAL (
              SELECT CASE
                  WHEN jsonb_typeof(consumed_card_design_ids) = 'array' THEN consumed_card_design_ids
                  WHEN jsonb_typeof(consumed_card_design_ids) = 'string'
                       AND left(consumed_card_design_ids #>> '{}', 1) = '['
                      THEN (consumed_card_design_ids #>> '{}')::jsonb
                  ELSE jsonb_build_array(consumed_card_design_ids #>> '{}')
              END AS design_ids
          ) normalized
          CROSS JOIN LATERAL jsonb_array_elements(normalized.design_ids) WITH ORDINALITY AS ids(value, ordinality)
          LEFT JOIN tmp_official_s01_design_id_map m ON m.old_design_id = trim(both '"' FROM ids.value::text)
         GROUP BY a.id
  ) mapped
 WHERE a.id = mapped.id
   AND a.consumed_card_design_ids IS DISTINCT FROM mapped.next_design_ids;

UPDATE gatcha_nft_asset_job_events e
   SET snapshot = jsonb_set(e.snapshot, '{designId}', to_jsonb(m.new_design_id), false)
  FROM tmp_official_s01_design_id_map m
 WHERE e.snapshot->>'designId' = m.old_design_id;

UPDATE gatcha_nft_asset_job_events e
   SET snapshot = jsonb_set(e.snapshot, '{cardCode}', to_jsonb(m.new_design_id), false)
  FROM tmp_official_s01_design_id_map m
 WHERE e.snapshot->>'cardCode' = m.old_design_id;

DROP TABLE tmp_official_s01_design_id_map;
