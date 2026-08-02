-- Every card draw uses the same fixed 1,000,000 weight range. Stock and prior
-- outcomes must not renormalize the published rarity probabilities.
WITH desired(code, weight) AS (
    VALUES
        ('COM', 750000),
        ('ADV', 170000),
        ('RAR',  50000),
        ('HER',  20000),
        ('LEG',   7000),
        ('MYT',   2500),
        ('DIV',    500)
)
UPDATE gatcha_rarities r
   SET weight = desired.weight,
       updated_at = NOW()
  FROM gatcha_seasons s,
       desired
 WHERE r.season_id = s.id
   AND r.code = desired.code
   AND s.code IN ('S01', 'TEST');

UPDATE gatcha_seasons
   SET exhaustion_policy = 'FAIL_AND_REFUND',
       updated_at = NOW()
 WHERE code IN ('S01', 'TEST');

DO $$
DECLARE
    invalid_season TEXT;
BEGIN
    SELECT s.code
      INTO invalid_season
      FROM gatcha_seasons s
      JOIN gatcha_rarities r ON r.season_id = s.id
     WHERE s.code IN ('S01', 'TEST')
     GROUP BY s.code
    HAVING SUM(r.weight) <> 1000000
     LIMIT 1;

    IF invalid_season IS NOT NULL THEN
        RAISE EXCEPTION 'draw weights for season % do not total 1000000', invalid_season;
    END IF;
END $$;
