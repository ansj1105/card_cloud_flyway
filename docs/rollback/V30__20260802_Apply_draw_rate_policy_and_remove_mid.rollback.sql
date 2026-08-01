-- Roll back V30 draw rate policy to the previous legacy seed weights.
-- This restores MID for S01/TEST only if it is missing.

WITH previous(code, label, weight, upgrade_success_bp, sort_order) AS (
    VALUES
        ('COM', 'Common',    720000, 6500, 1),
        ('ADV', 'Advanced',   60000, 3500, 2),
        ('MID', '중급',      200000, 3500, 2),
        ('RAR', 'Rare',       15000, 1800, 3),
        ('HER', 'Heroic',      4500,  700, 4),
        ('LEG', 'Legendary',    490,  200, 5),
        ('MYT', 'Mythic',        10,   50, 6),
        ('DIV', 'Divine',         0,    0, 7)
)
INSERT INTO gatcha_rarities (season_id, code, label, color, weight, upgrade_success_bp, sort_order)
SELECT s.id,
       p.code,
       p.label,
       COALESCE(template.color, 'silver'),
       p.weight,
       p.upgrade_success_bp,
       p.sort_order
  FROM gatcha_seasons s
 CROSS JOIN previous p
  LEFT JOIN gatcha_rarities template
    ON template.season_id = s.id
   AND template.code = CASE WHEN p.code = 'MID' THEN 'ADV' ELSE p.code END
 WHERE s.code IN ('S01', 'TEST')
   AND NOT EXISTS (
       SELECT 1
         FROM gatcha_rarities existing
        WHERE existing.season_id = s.id
          AND existing.code = p.code
   );

WITH previous(code, label, weight, upgrade_success_bp, sort_order) AS (
    VALUES
        ('COM', 'Common',    720000, 6500, 1),
        ('ADV', 'Advanced',   60000, 3500, 2),
        ('MID', '중급',      200000, 3500, 2),
        ('RAR', 'Rare',       15000, 1800, 3),
        ('HER', 'Heroic',      4500,  700, 4),
        ('LEG', 'Legendary',    490,  200, 5),
        ('MYT', 'Mythic',        10,   50, 6),
        ('DIV', 'Divine',         0,    0, 7)
)
UPDATE gatcha_rarities r
   SET label = p.label,
       weight = p.weight,
       upgrade_success_bp = p.upgrade_success_bp,
       sort_order = p.sort_order,
       updated_at = NOW()
  FROM gatcha_seasons s,
       previous p
 WHERE r.season_id = s.id
   AND r.code = p.code
   AND s.code IN ('S01', 'TEST');
