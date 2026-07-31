-- Rollback for V28__20260801_Rebuild_test_card_stock_from_s01.sql.
-- Scope: TEST season only. Production S01 designs/cards are not touched.
--
-- Run only if TEST draw behavior must be disabled again.

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

DELETE FROM gatcha_rarities r
 USING gatcha_seasons s
 WHERE r.season_id = s.id
   AND s.code = 'TEST';

DELETE FROM gatcha_season_serial_counters
 WHERE season_code = 'TEST';

DELETE FROM gatcha_seasons
 WHERE code = 'TEST';

DROP TABLE tmp_test_designs;
DROP TABLE tmp_test_season_cards;
