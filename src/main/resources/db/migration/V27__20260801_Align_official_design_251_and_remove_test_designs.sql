-- Align Season 1 official card #00251 with KORION_NFT_CASE_MASTER_FINAL_V3 / Official_Cards_288.
-- The Excel source marks #00251 as LEG KORIS0001LEG00251, but the previous seed stored it as MYT.
-- Also remove leftover KORITEST* seed designs/cards so admin number views do not show duplicate test rows.

CREATE TEMP TABLE tmp_test_designs AS
SELECT d.design_id
  FROM gatcha_designs d
 WHERE d.design_id LIKE 'KORITEST%';

CREATE TEMP TABLE tmp_test_cards AS
SELECT c.id
  FROM gatcha_cards c
  JOIN tmp_test_designs d ON d.design_id = c.design_id;

DELETE FROM gatcha_upgrade_attempts a
 USING tmp_test_cards c
 WHERE a.result_card_id = c.id;

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_test_cards c
 WHERE e.card_id = c.id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_test_cards c
 WHERE j.card_id = c.id;

DELETE FROM gatcha_nft_asset_job_events e
 USING tmp_test_designs d
 WHERE e.snapshot->>'designId' = d.design_id;

DELETE FROM gatcha_nft_asset_jobs j
 USING tmp_test_designs d
 WHERE j.design_id = d.design_id;

DELETE FROM gatcha_cards c
 USING tmp_test_designs d
 WHERE c.design_id = d.design_id;

DELETE FROM gatcha_design_skills ds
 USING tmp_test_designs d
 WHERE ds.design_id = d.design_id;

DELETE FROM gatcha_designs d
 USING tmp_test_designs stale
 WHERE d.design_id = stale.design_id;

DELETE FROM gatcha_skills sk
 WHERE sk.code LIKE 'KORITEST%'
   AND NOT EXISTS (
       SELECT 1
         FROM gatcha_design_skills ds
        WHERE ds.skill_id = sk.id
   );

DO $$
BEGIN
    ALTER TABLE gatcha_design_skills
        ALTER CONSTRAINT gatcha_design_skills_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
EXCEPTION WHEN undefined_object THEN
    NULL;
END $$;

SET CONSTRAINTS gatcha_design_skills_design_id_fkey DEFERRED;

UPDATE gatcha_designs d
   SET rarity_id = leg.id,
       design_id = 'KORIS0001LEG00251',
       edition_size = 50,
       name = 'Echo Whisker',
       species = 'Cat',
       faction = 'Korion',
       play_cost = 4,
       attack = 7,
       hp = 8,
       move = 6,
       range = 10,
       passive_text = 'Dominion Resonant Ear: Damage taken -1. After successfully applying a status effect, gain Shield 3.',
       updated_at = NOW()
  FROM gatcha_rarities leg
  JOIN gatcha_seasons s ON s.id = leg.season_id
 WHERE s.code = 'S01'
   AND leg.code = 'LEG'
   AND d.design_id = 'KORIS0001MYT00251';

UPDATE gatcha_design_skills
   SET design_id = 'KORIS0001LEG00251'
 WHERE design_id = 'KORIS0001MYT00251';

UPDATE gatcha_nft_asset_jobs
   SET design_id = 'KORIS0001LEG00251',
       updated_at = NOW()
 WHERE design_id = 'KORIS0001MYT00251';

UPDATE gatcha_nft_asset_job_events
   SET snapshot = jsonb_set(snapshot, '{designId}', to_jsonb('KORIS0001LEG00251'::text), false)
 WHERE snapshot->>'designId' = 'KORIS0001MYT00251';

DROP TABLE tmp_test_cards;
DROP TABLE tmp_test_designs;
