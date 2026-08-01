DROP INDEX IF EXISTS idx_gatcha_cards_design_variant;

ALTER TABLE gatcha_cards
    DROP COLUMN IF EXISTS design_variant_no;

DROP TABLE IF EXISTS gatcha_design_image_variants;
