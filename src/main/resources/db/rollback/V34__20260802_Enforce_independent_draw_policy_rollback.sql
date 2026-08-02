UPDATE gatcha_seasons
   SET exhaustion_policy = 'EXCLUDE_RENORMALIZE',
       updated_at = NOW()
 WHERE code IN ('S01', 'TEST');
