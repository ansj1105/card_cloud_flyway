-- Rollback for V18__20260728_Add_divine_card_rarity.sql.
-- Run only before any DIV designs/cards are created.

WITH previous_labels(code, label, color, sort_order) AS (
    VALUES
        ('COM', '일반', '회색/실버', 1),
        ('ADV', '고급', '파랑', 3),
        ('RAR', '희귀', '보라', 4),
        ('HER', '영웅', '핑크/레드', 5),
        ('LEG', '전설', '금색', 6),
        ('MYT', '신화', '오로라/플래티넘', 7)
)
UPDATE gatcha_rarities r
   SET label = p.label,
       color = p.color,
       sort_order = p.sort_order,
       updated_at = now()
  FROM previous_labels p
 WHERE r.code = p.code;

WITH previous_labels(code, label) AS (
    VALUES
        ('COM', '일반'),
        ('ADV', '고급'),
        ('RAR', '희귀'),
        ('HER', '영웅'),
        ('LEG', '전설'),
        ('MYT', '신화')
)
UPDATE gatcha_cards c
   SET rarity_label = p.label,
       updated_at = now()
  FROM previous_labels p
 WHERE c.rarity_code = p.code;

DELETE FROM gatcha_rarities r
WHERE r.code = 'DIV'
  AND NOT EXISTS (
      SELECT 1
      FROM gatcha_designs d
      WHERE d.rarity_id = r.id
  )
  AND NOT EXISTS (
      SELECT 1
      FROM gatcha_cards c
      WHERE c.rarity_code = r.code
  );
