-- Align card draw rates to the seven official rarity policy and remove legacy MID.
-- Values are weight basis over 1,000,000 and upgrade basis points over 10,000:
-- COM 75.00%, ADV 17.00%, RAR 5.00%, HER 2.00%, LEG 0.70%, MYT 0.25%, DIV 0.05%.
-- Upgrade: COM 55%, ADV 42%, RAR 30%, HER 20%, LEG 10%, MYT 5%.

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

DELETE FROM gatcha_rate_audit audit
 USING gatcha_rarities r
 JOIN gatcha_seasons s ON s.id = r.season_id
 WHERE audit.rarity_id = r.id
   AND s.code IN ('S01', 'TEST')
   AND r.code = 'MID';

DELETE FROM gatcha_rarities r
 USING gatcha_seasons s
 WHERE r.season_id = s.id
   AND s.code IN ('S01', 'TEST')
   AND r.code = 'MID';
