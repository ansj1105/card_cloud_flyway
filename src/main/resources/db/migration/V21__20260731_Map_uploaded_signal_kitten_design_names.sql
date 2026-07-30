-- Uploaded S01 NFT original batches for the Signal Kitten artwork were
-- auto-created with placeholder names. Keep the design names aligned with the
-- actual card artwork shown in the admin S3/NFT monitor.

UPDATE gatcha_designs
   SET name = 'Signal Kitten',
       updated_at = now()
 WHERE design_id IN (
       'KORIS0001ADV00061',
       'KORIS0001RAR00121',
       'KORIS0001HER00169',
       'KORIS0001LEG00217',
       'KORIS0001MYT00253',
       'KORIS0001DIV00277'
   )
   AND name LIKE '미매핑 원본%';
