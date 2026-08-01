-- Data correction migration. Rollback intentionally does not restore stale card
-- names or previous probability policy.
DELETE FROM gatcha_design_image_variants v
USING gatcha_designs d
JOIN gatcha_rarities r ON r.id = d.rarity_id
JOIN gatcha_seasons s ON s.id = r.season_id
WHERE v.design_id = d.design_id
  AND s.code = 'TEST';
