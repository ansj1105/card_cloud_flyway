-- Roll back V29 upgrade success rate policy to the previous frontend fallback values.
-- Values are basis points: 6500 = 65.00%.

WITH previous(code, upgrade_success_bp) AS (
    VALUES
        ('COM', 6500),
        ('ADV', 3500),
        ('RAR', 1800),
        ('HER',  700),
        ('LEG',  200),
        ('MYT',   50),
        ('DIV',    0)
)
UPDATE gatcha_rarities r
   SET upgrade_success_bp = p.upgrade_success_bp,
       updated_at = NOW()
  FROM gatcha_seasons s,
       previous p
 WHERE r.season_id = s.id
   AND r.code = p.code
   AND s.code IN ('S01', 'TEST');
