-- Align rarity color metadata with the PSD top-level card layer mapping:
-- COM = basic, ADV = green, RAR = blue, HER = red, LEG = yellow/gold,
-- MYT = purple, DIV = special.

WITH desired(code, color) AS (
    VALUES
        ('COM', 'silver'),
        ('ADV', 'green'),
        ('RAR', 'blue'),
        ('HER', 'red'),
        ('LEG', 'gold'),
        ('MYT', 'purple'),
        ('DIV', 'special')
)
UPDATE gatcha_rarities r
   SET color = d.color,
       updated_at = now()
  FROM desired d
 WHERE r.code = d.code;
