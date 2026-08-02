DELETE FROM gatcha_designs d
USING gatcha_rarities r, gatcha_seasons s
WHERE d.rarity_id = r.id
  AND r.season_id = s.id
  AND s.code = 'TEST'
  AND r.code = 'COM'
  AND d.design_no = 11
  AND NOT EXISTS (
      SELECT 1
        FROM gatcha_cards c
       WHERE c.design_id = d.design_id
  );

UPDATE gatcha_designs d
   SET status = 'RETIRED',
       nft_enabled = FALSE,
       updated_at = NOW()
  FROM gatcha_rarities r,
       gatcha_seasons s
 WHERE d.rarity_id = r.id
   AND r.season_id = s.id
   AND s.code = 'TEST'
   AND r.code = 'COM'
   AND d.design_no = 11;
