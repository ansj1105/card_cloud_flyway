-- Rollback to the official-card seed edition sizes used before V26.
-- Run only if issued_count does not exceed the target value for each rarity.

WITH rarity_policy(rarity_code, edition_size) AS (
    VALUES
        ('COM', 2500),
        ('ADV', 1000),
        ('RAR', 400),
        ('HER', 150),
        ('LEG', 50),
        ('MYT', 15),
        ('DIV', 15)
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
