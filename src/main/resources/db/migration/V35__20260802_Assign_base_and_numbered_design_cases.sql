WITH variant_ranks AS (
    SELECT
        design_id,
        variant_no,
        ROW_NUMBER() OVER (PARTITION BY design_id ORDER BY variant_no ASC) AS variant_rank,
        COUNT(*) OVER (PARTITION BY design_id) AS variant_count
    FROM gatcha_design_image_variants
), assignments AS (
    SELECT
        c.id,
        c.design_id,
        MOD(c.serial_no - 1, variant_ranks.variant_count + 1) AS case_index
    FROM gatcha_cards c
    JOIN (
        SELECT DISTINCT design_id, variant_count
        FROM variant_ranks
    ) variant_ranks ON variant_ranks.design_id = c.design_id
), resolved AS (
    SELECT
        assignments.id,
        variant_ranks.variant_no
    FROM assignments
    LEFT JOIN variant_ranks
      ON variant_ranks.design_id = assignments.design_id
     AND variant_ranks.variant_rank = assignments.case_index
)
UPDATE gatcha_cards cards
SET design_variant_no = resolved.variant_no,
    updated_at = NOW()
FROM resolved
WHERE cards.id = resolved.id
  AND cards.design_variant_no IS DISTINCT FROM resolved.variant_no;

COMMENT ON COLUMN gatcha_cards.design_variant_no IS
    '같은 카드 번호의 추가 이미지 케이스 번호. NULL은 기본 이미지, 1 이상은 파일명의 -N 케이스.';
