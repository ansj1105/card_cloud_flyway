WITH variant_ranks AS (
    SELECT
        design_id,
        variant_no,
        ROW_NUMBER() OVER (PARTITION BY design_id ORDER BY variant_no ASC) AS variant_rank,
        COUNT(*) OVER (PARTITION BY design_id) AS variant_count
    FROM gatcha_design_image_variants
)
UPDATE gatcha_cards cards
SET design_variant_no = variant_ranks.variant_no,
    updated_at = NOW()
FROM variant_ranks
WHERE cards.design_id = variant_ranks.design_id
  AND variant_ranks.variant_rank = MOD(cards.serial_no - 1, variant_ranks.variant_count) + 1
  AND cards.design_variant_no IS DISTINCT FROM variant_ranks.variant_no;

COMMENT ON COLUMN gatcha_cards.design_variant_no IS
    '유저가 뽑은 카드에 배정된 같은 카드 번호 내 이미지 케이스 번호.';
