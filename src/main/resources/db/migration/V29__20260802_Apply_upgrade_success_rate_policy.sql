-- Align card upgrade success rates for active and test seasons.
-- Values are basis points: 5500 = 55.00%.

WITH desired(code, upgrade_success_bp) AS (
    VALUES
        ('COM', 5500),
        ('ADV', 4200),
        ('RAR', 3000),
        ('HER', 2000),
        ('LEG', 1000),
        ('MYT',  500),
        ('DIV',    0)
)
UPDATE gatcha_rarities r
   SET upgrade_success_bp = d.upgrade_success_bp,
       updated_at = NOW()
  FROM gatcha_seasons s,
       desired d
 WHERE r.season_id = s.id
   AND r.code = d.code
   AND s.code IN ('S01', 'TEST');
