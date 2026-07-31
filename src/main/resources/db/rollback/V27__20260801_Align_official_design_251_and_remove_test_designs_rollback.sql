-- Roll back the #00251 rarity/id correction only.
-- KORITEST* rows removed by the forward migration are intentionally not restored;
-- recover them from a pre-migration backup if test seed history is required.

DO $$
BEGIN
    ALTER TABLE gatcha_design_skills
        ALTER CONSTRAINT gatcha_design_skills_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;
EXCEPTION WHEN undefined_object THEN
    NULL;
END $$;

SET CONSTRAINTS gatcha_design_skills_design_id_fkey DEFERRED;

UPDATE gatcha_designs d
   SET rarity_id = myt.id,
       design_id = 'KORIS0001MYT00251',
       edition_size = 15,
       updated_at = NOW()
  FROM gatcha_rarities myt
  JOIN gatcha_seasons s ON s.id = myt.season_id
 WHERE s.code = 'S01'
   AND myt.code = 'MYT'
   AND d.design_id = 'KORIS0001LEG00251';

UPDATE gatcha_design_skills
   SET design_id = 'KORIS0001MYT00251'
 WHERE design_id = 'KORIS0001LEG00251';

UPDATE gatcha_nft_asset_jobs
   SET design_id = 'KORIS0001MYT00251',
       updated_at = NOW()
 WHERE design_id = 'KORIS0001LEG00251';

UPDATE gatcha_nft_asset_job_events
   SET snapshot = jsonb_set(snapshot, '{designId}', to_jsonb('KORIS0001MYT00251'::text), false)
 WHERE snapshot->>'designId' = 'KORIS0001LEG00251';
