-- Align active card rarity labels/codes with:
-- COM/Common, ADV/Advanced, RAR/Rare, HER/Heroic, LEG/Legendary,
-- MYT/Mythic, DIV/Divine.
-- MID remains in place as legacy data because issued cards and designs may
-- already reference it, but application code no longer exposes it as an
-- allowed upload/design/rate code.

WITH desired(code, label, color, sort_order) AS (
    VALUES
        ('COM', 'Common', 'silver', 1),
        ('ADV', 'Advanced', 'blue', 2),
        ('RAR', 'Rare', 'purple', 3),
        ('HER', 'Heroic', 'red', 4),
        ('LEG', 'Legendary', 'gold', 5),
        ('MYT', 'Mythic', 'platinum', 6),
        ('DIV', 'Divine', 'divine', 7)
)
UPDATE gatcha_rarities r
   SET label = d.label,
       color = d.color,
       sort_order = d.sort_order,
       updated_at = now()
  FROM desired d
 WHERE r.code = d.code;

INSERT INTO gatcha_rarities (season_id, code, label, color, weight, upgrade_success_bp, sort_order)
SELECT s.id, 'DIV', 'Divine', 'divine', 0, 0, 7
FROM gatcha_seasons s
WHERE NOT EXISTS (
    SELECT 1
    FROM gatcha_rarities r
    WHERE r.season_id = s.id
      AND r.code = 'DIV'
);

WITH desired(code, label) AS (
    VALUES
        ('COM', 'Common'),
        ('ADV', 'Advanced'),
        ('RAR', 'Rare'),
        ('HER', 'Heroic'),
        ('LEG', 'Legendary'),
        ('MYT', 'Mythic'),
        ('DIV', 'Divine')
)
UPDATE gatcha_cards c
   SET rarity_label = d.label,
       updated_at = now()
  FROM desired d
 WHERE c.rarity_code = d.code;
