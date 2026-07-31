-- Remove Season 1 seed/test card data that is not present in Official_Cards_288.
-- Official Season 1 design ranges:
-- COM 1-60, ADV 61-120, RAR 121-168, HER 169-216, LEG 217-252, MYT 253-276, DIV 277-288.
--
-- This is intentionally idempotent so it can be run after a manual cleanup and later recorded by Flyway.
-- Rollback path: restore removed rows from backup or re-seed from a pre-cleanup dump.

CREATE TEMP TABLE tmp_official_s01_design_ranges (
    rarity_code VARCHAR(10) PRIMARY KEY,
    min_no INT NOT NULL,
    max_no INT NOT NULL
);

INSERT INTO tmp_official_s01_design_ranges (rarity_code, min_no, max_no)
VALUES
    ('COM', 1, 60),
    ('ADV', 61, 120),
    ('RAR', 121, 168),
    ('HER', 169, 216),
    ('LEG', 217, 252),
    ('MYT', 253, 276),
    ('DIV', 277, 288);

CREATE TEMP TABLE tmp_non_official_s01_designs AS
SELECT d.design_id, d.rarity_id
  FROM gatcha_designs d
  JOIN gatcha_rarities r ON r.id = d.rarity_id
  JOIN gatcha_seasons s ON s.id = r.season_id
  LEFT JOIN tmp_official_s01_design_ranges official
    ON official.rarity_code = r.code
   AND d.design_no BETWEEN official.min_no AND official.max_no
 WHERE s.code = 'S01'
   AND (
       r.code = 'MID'
       OR (r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV') AND official.rarity_code IS NULL)
   );

CREATE TEMP TABLE tmp_non_official_s01_cards AS
SELECT c.id
  FROM gatcha_cards c
  JOIN tmp_non_official_s01_designs d ON d.design_id = c.design_id;

DELETE FROM gatcha_upgrade_attempts a
 USING tmp_non_official_s01_cards c
 WHERE a.result_card_id = c.id;

DELETE FROM gatcha_upgrade_attempts
 WHERE result_rarity_code = 'MID';

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_non_official_s01_cards c
 WHERE e.card_id = c.id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_non_official_s01_cards c
 WHERE j.card_id = c.id;

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_non_official_s01_designs d
 WHERE e.snapshot->>'designId' = d.design_id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_non_official_s01_designs d
 WHERE j.design_id = d.design_id;

DELETE FROM gatcha_cards c
 USING tmp_non_official_s01_designs d
 WHERE c.design_id = d.design_id;

DELETE FROM gatcha_design_skills ds
 USING tmp_non_official_s01_designs d
 WHERE ds.design_id = d.design_id;

DELETE FROM gatcha_designs d
 USING tmp_non_official_s01_designs stale
 WHERE d.design_id = stale.design_id;

DELETE FROM gatcha_rate_audit audit
 USING gatcha_rarities r
 JOIN gatcha_seasons s ON s.id = r.season_id
 WHERE audit.rarity_id = r.id
   AND s.code = 'S01'
   AND r.code = 'MID';

DELETE FROM gatcha_rarities r
 USING gatcha_seasons s
 WHERE r.season_id = s.id
   AND s.code = 'S01'
   AND r.code = 'MID';

DELETE FROM gatcha_skills sk
 WHERE sk.code NOT LIKE 'S01\_%\_%' ESCAPE '\'
   AND NOT EXISTS (
       SELECT 1
         FROM gatcha_design_skills ds
        WHERE ds.skill_id = sk.id
   );

DROP TABLE tmp_non_official_s01_cards;
DROP TABLE tmp_non_official_s01_designs;
DROP TABLE tmp_official_s01_design_ranges;
