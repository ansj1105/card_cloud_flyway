WITH source_design AS (
    SELECT d.*
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'S01'
       AND r.code = 'COM'
       AND d.design_no = 11
       AND d.status = 'ACTIVE'
       AND d.image_url IS NOT NULL
),
test_rarity AS (
    SELECT r.id
      FROM gatcha_rarities r
      JOIN gatcha_seasons s ON s.id = r.season_id
     WHERE s.code = 'TEST'
       AND r.code = 'COM'
)
INSERT INTO gatcha_designs
    (rarity_id, design_id, design_no, name, image_url, thumbnail_image_url,
     edition_size, issued_count, status, play_cost, attack, defense, hp, move,
     range, species, faction, passive_text, job_class_id, nft_enabled)
SELECT tr.id,
       'KORITEST' || substring(sd.design_id FROM 5),
       sd.design_no,
       sd.name,
       sd.image_url,
       sd.thumbnail_image_url,
       sd.edition_size,
       0,
       sd.status,
       sd.play_cost,
       sd.attack,
       sd.defense,
       sd.hp,
       sd.move,
       sd.range,
       sd.species,
       sd.faction,
       sd.passive_text,
       sd.job_class_id,
       sd.nft_enabled
  FROM source_design sd
 CROSS JOIN test_rarity tr
ON CONFLICT (rarity_id, design_no) DO UPDATE
   SET design_id = EXCLUDED.design_id,
       name = EXCLUDED.name,
       image_url = EXCLUDED.image_url,
       thumbnail_image_url = EXCLUDED.thumbnail_image_url,
       edition_size = EXCLUDED.edition_size,
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
