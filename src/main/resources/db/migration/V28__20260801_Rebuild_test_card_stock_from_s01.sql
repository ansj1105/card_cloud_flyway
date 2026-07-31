-- Rebuild TEST season stock from the production S01 catalog.
--
-- TEST is used only for users.is_test=1 in fox_coin CardGatchaService.
-- It must not consume S01 production issued_count, so every test design uses a
-- KORITEST* design_id while keeping the same rarity, design_no, stats, skills,
-- images, and edition_size policy as S01.

CREATE TEMP TABLE tmp_test_season_cards AS
SELECT c.id, c.draw_id
  FROM gatcha_cards c
 WHERE c.season_code = 'TEST'
    OR c.design_id LIKE 'KORITEST%';

CREATE TEMP TABLE tmp_test_designs AS
SELECT d.design_id
  FROM gatcha_designs d
  JOIN gatcha_rarities r ON r.id = d.rarity_id
  JOIN gatcha_seasons s ON s.id = r.season_id
 WHERE d.design_id LIKE 'KORITEST%'
    OR s.code = 'TEST';

DELETE FROM gatcha_upgrade_attempts a
 USING tmp_test_season_cards c
 WHERE a.result_card_id = c.id;

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_test_season_cards c
 WHERE e.card_id = c.id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_test_season_cards c
 WHERE j.card_id = c.id;

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_test_designs d
 WHERE e.snapshot->>'designId' = d.design_id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_test_designs d
 WHERE j.design_id = d.design_id;

DELETE FROM gatcha_cards c
 USING tmp_test_season_cards tc
 WHERE c.id = tc.id;

DELETE FROM gatcha_draws gd
 USING (
    SELECT DISTINCT draw_id
      FROM tmp_test_season_cards
     WHERE draw_id IS NOT NULL
 ) d
 WHERE gd.draw_id = d.draw_id;

DELETE FROM gatcha_design_skills ds
 USING tmp_test_designs d
 WHERE ds.design_id = d.design_id;

DELETE FROM gatcha_designs d
 USING tmp_test_designs td
 WHERE d.design_id = td.design_id;

INSERT INTO gatcha_seasons (code, status, draw_cost, currency_code, exhaustion_policy, name)
VALUES ('TEST', 'DRAFT', 0, 'KORI', 'EXCLUDE_RENORMALIZE', 'ARENA TEST')
ON CONFLICT (code) DO UPDATE
   SET status = 'DRAFT',
       draw_cost = 0,
       currency_code = 'KORI',
       exhaustion_policy = 'EXCLUDE_RENORMALIZE',
       name = 'ARENA TEST',
       updated_at = NOW();

WITH source_rarities AS (
    SELECT r.code, r.label, r.color, r.weight, r.upgrade_success_bp, r.sort_order
      FROM gatcha_rarities r
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'S01'
       AND r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV')
),
test_season AS (
    SELECT id FROM gatcha_seasons WHERE code = 'TEST'
)
INSERT INTO gatcha_rarities (season_id, code, label, color, weight, upgrade_success_bp, sort_order)
SELECT ts.id, sr.code, sr.label, sr.color, sr.weight, sr.upgrade_success_bp, sr.sort_order
  FROM source_rarities sr
 CROSS JOIN test_season ts
ON CONFLICT (season_id, code) DO UPDATE
   SET label = EXCLUDED.label,
       color = EXCLUDED.color,
       weight = EXCLUDED.weight,
       upgrade_success_bp = EXCLUDED.upgrade_success_bp,
       sort_order = EXCLUDED.sort_order,
       updated_at = NOW();

WITH source_designs AS (
    SELECT d.design_id AS source_design_id,
           'KORITEST' || substring(d.design_id FROM 5) AS test_design_id,
           r.code AS rarity_code,
           d.design_no,
           d.name,
           d.image_url,
           d.edition_size,
           d.play_cost,
           d.attack,
           d.defense,
           d.hp,
           d.move,
           d.range,
           d.species,
           d.faction,
           d.passive_text,
           d.job_class_id,
           d.nft_enabled,
           d.status
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'S01'
       AND d.status = 'ACTIVE'
       AND r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV')
),
test_rarities AS (
    SELECT r.id, r.code
      FROM gatcha_rarities r
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'TEST'
)
INSERT INTO gatcha_designs
    (rarity_id, design_id, design_no, name, image_url, edition_size, issued_count, status,
     play_cost, attack, defense, hp, move, range, species, faction, passive_text, job_class_id, nft_enabled)
SELECT tr.id, sd.test_design_id, sd.design_no, sd.name, sd.image_url, sd.edition_size, 0, sd.status,
       sd.play_cost, sd.attack, sd.defense, sd.hp, sd.move, sd.range,
       sd.species, sd.faction, sd.passive_text, sd.job_class_id, sd.nft_enabled
  FROM source_designs sd
  JOIN test_rarities tr ON tr.code = sd.rarity_code
ON CONFLICT (rarity_id, design_no) DO UPDATE
   SET design_id = EXCLUDED.design_id,
       name = EXCLUDED.name,
       image_url = EXCLUDED.image_url,
       edition_size = EXCLUDED.edition_size,
       issued_count = 0,
       status = EXCLUDED.status,
       play_cost = EXCLUDED.play_cost,
       attack = EXCLUDED.attack,
       defense = EXCLUDED.defense,
       hp = EXCLUDED.hp,
       move = EXCLUDED.move,
       range = EXCLUDED.range,
       species = EXCLUDED.species,
       faction = EXCLUDED.faction,
       passive_text = EXCLUDED.passive_text,
       job_class_id = EXCLUDED.job_class_id,
       nft_enabled = EXCLUDED.nft_enabled,
       updated_at = NOW();

WITH design_map AS (
    SELECT d.design_id AS source_design_id,
           td.design_id AS test_design_id
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
      JOIN gatcha_rarities tr ON tr.code = r.code
      JOIN gatcha_seasons ts ON ts.id = tr.season_id AND ts.code = 'TEST'
      JOIN gatcha_designs td ON td.rarity_id = tr.id AND td.design_no = d.design_no
     WHERE s.code = 'S01'
       AND d.status = 'ACTIVE'
       AND r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV')
)
INSERT INTO gatcha_design_skills (design_id, skill_id, slot)
SELECT dm.test_design_id, ds.skill_id, ds.slot
  FROM design_map dm
  JOIN gatcha_design_skills ds ON ds.design_id = dm.source_design_id
ON CONFLICT (design_id, skill_id) DO UPDATE
   SET slot = EXCLUDED.slot;

DO $$
DECLARE
    source_count INT;
    test_count INT;
BEGIN
    SELECT COUNT(*) INTO source_count
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'S01'
       AND d.status = 'ACTIVE'
       AND r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV');

    SELECT COUNT(*) INTO test_count
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'TEST'
       AND d.status = 'ACTIVE'
       AND r.code IN ('COM', 'ADV', 'RAR', 'HER', 'LEG', 'MYT', 'DIV');

    IF source_count <> test_count THEN
        RAISE EXCEPTION 'TEST stock rebuild mismatch: source %, test %', source_count, test_count;
    END IF;
END $$;

DELETE FROM gatcha_season_serial_counters
 WHERE season_code = 'TEST';

DROP TABLE tmp_test_designs;
DROP TABLE tmp_test_season_cards;
