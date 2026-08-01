-- Reassert the current 7-rarity policy and make draw candidates match the
-- current blank-card image catalog.

WITH desired(code, label, weight, upgrade_success_bp, sort_order) AS (
    VALUES
        ('COM', 'Common',     750000, 5500, 1),
        ('ADV', 'Advanced',   170000, 4200, 2),
        ('RAR', 'Rare',        50000, 3000, 3),
        ('HER', 'Heroic',      20000, 2000, 4),
        ('LEG', 'Legendary',    7000, 1000, 5),
        ('MYT', 'Mythic',       2500,  500, 6),
        ('DIV', 'Special',       500,    0, 7)
)
UPDATE gatcha_rarities r
   SET label = d.label,
       weight = d.weight,
       upgrade_success_bp = d.upgrade_success_bp,
       sort_order = d.sort_order,
       updated_at = NOW()
  FROM gatcha_seasons s,
       desired d
 WHERE r.season_id = s.id
   AND r.code = d.code
   AND s.code IN ('S01', 'TEST');

CREATE TEMP TABLE current_blank_card_designs (
    rarity_code TEXT NOT NULL,
    design_no INT NOT NULL,
    file_name TEXT NOT NULL
) ON COMMIT DROP;

INSERT INTO current_blank_card_designs (rarity_code, design_no, file_name) VALUES
    ('COM', 1, 'KOR-S01-COM-00001-1_NO-SERIAL_1-of-1.webp'),
    ('COM', 11, 'KOR-S01-COM-00011_NO-SERIAL_1-of-1.webp'),
    ('COM', 16, 'KOR-S01-COM-00016_NO-SERIAL_1-of-1.webp'),
    ('COM', 21, 'KOR-S01-COM-00021_NO-SERIAL_1-of-1.webp'),
    ('COM', 26, 'KOR-S01-COM-00026_NO-SERIAL_1-of-1.webp'),
    ('COM', 31, 'KOR-S01-COM-00031_NO-SERIAL_1-of-1.webp'),
    ('COM', 36, 'KOR-S01-COM-00036_NO-SERIAL_1-of-1.webp'),
    ('COM', 41, 'KOR-S01-COM-00041_NO-SERIAL_1-of-1.webp'),
    ('COM', 46, 'KOR-S01-COM-00046_NO-SERIAL_1-of-1.webp'),
    ('COM', 51, 'KOR-S01-COM-00051_NO-SERIAL_1-of-1.webp'),
    ('COM', 56, 'KOR-S01-COM-00056_NO-SERIAL_1-of-1.webp'),
    ('ADV', 61, 'KOR-S01-ADV-00061_NO-SERIAL_1-of-1.webp'),
    ('RAR', 121, 'KOR-S01-RAR-00121_NO-SERIAL_1-of-1.webp'),
    ('HER', 169, 'KOR-S01-HER-00169_NO-SERIAL_1-of-1.webp'),
    ('LEG', 217, 'KOR-S01-LEG-00217_NO-SERIAL_1-of-1.webp'),
    ('MYT', 253, 'KOR-S01-MYT-00253_NO-SERIAL_1-of-1.webp'),
    ('DIV', 277, 'KOR-S01-DIV-00277_NO-SERIAL_1-of-1.webp');

WITH target AS (
    SELECT d.id, b.file_name
      FROM gatcha_designs d
      JOIN gatcha_rarities r ON r.id = d.rarity_id
      JOIN gatcha_seasons s ON s.id = r.season_id
      LEFT JOIN current_blank_card_designs b
        ON b.rarity_code = r.code
       AND b.design_no = d.design_no
     WHERE s.code IN ('S01', 'TEST')
)
UPDATE gatcha_designs d
   SET image_url = CASE
           WHEN target.file_name IS NULL THEN NULL
           ELSE '/assets/card-gatcha/blank/' || target.file_name
       END,
       thumbnail_image_url = CASE
           WHEN target.file_name IS NULL THEN NULL
           ELSE '/assets/card-gatcha/blank/' || target.file_name
       END,
       nft_enabled = target.file_name IS NOT NULL,
       status = CASE WHEN target.file_name IS NULL THEN 'RETIRED' ELSE 'ACTIVE' END,
       updated_at = NOW()
  FROM target
 WHERE d.id = target.id;

UPDATE gatcha_cards c
   SET card_name = d.name,
       rarity_label = r.label,
       updated_at = NOW()
  FROM gatcha_designs d
  JOIN gatcha_rarities r ON r.id = d.rarity_id
 WHERE c.design_id = d.design_id
   AND (
       c.card_name IS DISTINCT FROM d.name
       OR c.rarity_label IS DISTINCT FROM r.label
   );

WITH test_variants AS (
    SELECT
        td.design_id AS test_design_id,
        v.variant_no,
        v.image_url,
        v.thumbnail_image_url,
        v.label,
        v.is_primary
      FROM gatcha_design_image_variants v
      JOIN gatcha_designs sd ON sd.design_id = v.design_id
      JOIN gatcha_rarities sr ON sr.id = sd.rarity_id
      JOIN gatcha_seasons ss ON ss.id = sr.season_id AND ss.code = 'S01'
      JOIN gatcha_rarities tr ON tr.code = sr.code
      JOIN gatcha_seasons ts ON ts.id = tr.season_id AND ts.code = 'TEST'
      JOIN gatcha_designs td ON td.rarity_id = tr.id AND td.design_no = sd.design_no
)
INSERT INTO gatcha_design_image_variants
    (design_id, variant_no, image_url, thumbnail_image_url, label, is_primary)
SELECT
    test_design_id,
    variant_no,
    image_url,
    thumbnail_image_url,
    label,
    is_primary
FROM test_variants
ON CONFLICT (design_id, variant_no) DO UPDATE
SET image_url = EXCLUDED.image_url,
    thumbnail_image_url = EXCLUDED.thumbnail_image_url,
    label = EXCLUDED.label,
    is_primary = EXCLUDED.is_primary,
    updated_at = NOW();

CREATE TEMP TABLE current_blank_card_variants (
    rarity_code TEXT NOT NULL,
    design_no INT NOT NULL,
    variant_no INT NOT NULL
) ON COMMIT DROP;

INSERT INTO current_blank_card_variants (rarity_code, design_no, variant_no) VALUES
    ('COM', 1, 1), ('COM', 1, 2), ('COM', 1, 3), ('COM', 1, 4), ('COM', 1, 5),
    ('COM', 1, 6), ('COM', 1, 7), ('COM', 1, 8), ('COM', 1, 9), ('COM', 1, 10),
    ('COM', 1, 11), ('COM', 1, 12), ('COM', 1, 13),
    ('ADV', 61, 1), ('ADV', 61, 2), ('ADV', 61, 3), ('ADV', 61, 4), ('ADV', 61, 5),
    ('ADV', 61, 7), ('ADV', 61, 8), ('ADV', 61, 9), ('ADV', 61, 10),
    ('RAR', 121, 1), ('RAR', 121, 2), ('RAR', 121, 3), ('RAR', 121, 4),
    ('RAR', 121, 5), ('RAR', 121, 6), ('RAR', 121, 7), ('RAR', 121, 8),
    ('HER', 169, 1), ('HER', 169, 2), ('HER', 169, 3), ('HER', 169, 4),
    ('LEG', 217, 1), ('LEG', 217, 2), ('LEG', 217, 4),
    ('MYT', 253, 1), ('MYT', 253, 2), ('MYT', 253, 3),
    ('DIV', 277, 1), ('DIV', 277, 3);

DELETE FROM gatcha_design_image_variants v
USING gatcha_designs d
JOIN gatcha_rarities r ON r.id = d.rarity_id
JOIN gatcha_seasons s ON s.id = r.season_id
WHERE v.design_id = d.design_id
  AND s.code IN ('S01', 'TEST')
  AND NOT EXISTS (
      SELECT 1
        FROM current_blank_card_variants expected
       WHERE expected.rarity_code = r.code
         AND expected.design_no = d.design_no
         AND expected.variant_no = v.variant_no
  );

WITH variant_ranks AS (
    SELECT
        design_id,
        variant_no,
        ROW_NUMBER() OVER (PARTITION BY design_id ORDER BY variant_no ASC) AS variant_rank,
        COUNT(*) OVER (PARTITION BY design_id) AS variant_count
    FROM gatcha_design_image_variants
)
UPDATE gatcha_cards c
SET design_variant_no = variant_ranks.variant_no,
    updated_at = NOW()
FROM variant_ranks
WHERE c.design_id = variant_ranks.design_id
  AND c.design_variant_no IS NULL
  AND variant_ranks.variant_rank = ((c.serial_no - 1) % variant_ranks.variant_count) + 1;
