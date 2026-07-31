-- 등급별 카드 재고 정책:
-- COM 2500, ADV 1000, RAR 400, HER 150, LEG 50, MYT 15, DIV 5.
-- 이미 유저에게 발급된 수량보다 낮아지지 않도록 issued_count를 하한으로 둔다.

WITH rarity_policy(rarity_code, edition_size) AS (
    VALUES
        ('COM', 2500),
        ('ADV', 1000),
        ('RAR', 400),
        ('HER', 150),
        ('LEG', 50),
        ('MYT', 15),
        ('DIV', 5)
)
UPDATE gatcha_designs d
   SET edition_size = GREATEST(d.issued_count, p.edition_size),
       updated_at = NOW()
  FROM gatcha_rarities r
  JOIN gatcha_seasons s ON s.id = r.season_id
  JOIN rarity_policy p ON p.rarity_code = r.code
 WHERE d.rarity_id = r.id
   AND s.code = 'S01'
   AND d.edition_size IS DISTINCT FROM GREATEST(d.issued_count, p.edition_size);
