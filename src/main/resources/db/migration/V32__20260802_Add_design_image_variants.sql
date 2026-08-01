CREATE TABLE IF NOT EXISTS gatcha_design_image_variants (
    id BIGSERIAL PRIMARY KEY,
    design_id VARCHAR(40) NOT NULL REFERENCES gatcha_designs(design_id) ON DELETE CASCADE,
    variant_no INT NOT NULL CHECK (variant_no > 0),
    image_url VARCHAR(255) NOT NULL,
    thumbnail_image_url VARCHAR(255),
    label VARCHAR(80),
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (design_id, variant_no)
);

ALTER TABLE gatcha_cards
    ADD COLUMN IF NOT EXISTS design_variant_no INT CHECK (design_variant_no IS NULL OR design_variant_no > 0);

CREATE INDEX IF NOT EXISTS idx_gatcha_cards_design_variant
    ON gatcha_cards(design_id, design_variant_no);

COMMENT ON TABLE gatcha_design_image_variants IS '같은 카드 번호 안에서 사용하는 빈카드/아트 케이스 목록. 디자인 재고와 확률은 gatcha_designs가 소유한다.';
COMMENT ON COLUMN gatcha_cards.design_variant_no IS '유저가 뽑은 카드에 배정된 같은 카드 번호 내 이미지 케이스 번호.';

WITH variants(design_id, variant_no, asset_stem) AS (
    VALUES
        ('KORIS0001COM00001', 1, 'KOR-S01-COM-00001-1'),
        ('KORIS0001COM00001', 2, 'KOR-S01-COM-00001-2'),
        ('KORIS0001COM00001', 3, 'KOR-S01-COM-00001-3'),
        ('KORIS0001COM00001', 4, 'KOR-S01-COM-00001-4'),
        ('KORIS0001COM00001', 5, 'KOR-S01-COM-00001-5'),
        ('KORIS0001COM00001', 6, 'KOR-S01-COM-00001-6'),
        ('KORIS0001COM00001', 7, 'KOR-S01-COM-00001-7'),
        ('KORIS0001COM00001', 8, 'KOR-S01-COM-00001-8'),
        ('KORIS0001COM00001', 9, 'KOR-S01-COM-00001-9'),
        ('KORIS0001COM00001', 10, 'KOR-S01-COM-00001-10'),
        ('KORIS0001COM00001', 11, 'KOR-S01-COM-00001-11'),
        ('KORIS0001COM00001', 12, 'KOR-S01-COM-00001-12'),
        ('KORIS0001COM00001', 13, 'KOR-S01-COM-00001-13'),
        ('KORIS0001ADV00061', 1, 'KOR-S01-ADV-00061-1'),
        ('KORIS0001ADV00061', 2, 'KOR-S01-ADV-00061-2'),
        ('KORIS0001ADV00061', 3, 'KOR-S01-ADV-00061-3'),
        ('KORIS0001ADV00061', 4, 'KOR-S01-ADV-00061-4'),
        ('KORIS0001ADV00061', 5, 'KOR-S01-ADV-00061-5'),
        ('KORIS0001ADV00061', 7, 'KOR-S01-ADV-00061-7'),
        ('KORIS0001ADV00061', 8, 'KOR-S01-ADV-00061-8'),
        ('KORIS0001ADV00061', 9, 'KOR-S01-ADV-00061-9'),
        ('KORIS0001ADV00061', 10, 'KOR-S01-ADV-00061-10'),
        ('KORIS0001RAR00121', 1, 'KOR-S01-RAR-00121-1'),
        ('KORIS0001RAR00121', 2, 'KOR-S01-RAR-00121-2'),
        ('KORIS0001RAR00121', 3, 'KOR-S01-RAR-00121-3'),
        ('KORIS0001RAR00121', 4, 'KOR-S01-RAR-00121-4'),
        ('KORIS0001RAR00121', 5, 'KOR-S01-RAR-00121-5'),
        ('KORIS0001RAR00121', 6, 'KOR-S01-RAR-00121-6'),
        ('KORIS0001RAR00121', 7, 'KOR-S01-RAR-00121-7'),
        ('KORIS0001RAR00121', 8, 'KOR-S01-RAR-00121-8'),
        ('KORIS0001HER00169', 1, 'KOR-S01-HER-00169-1'),
        ('KORIS0001HER00169', 2, 'KOR-S01-HER-00169-2'),
        ('KORIS0001HER00169', 3, 'KOR-S01-HER-00169-3'),
        ('KORIS0001HER00169', 4, 'KOR-S01-HER-00169-4'),
        ('KORIS0001LEG00217', 1, 'KOR-S01-LEG-00217-1'),
        ('KORIS0001LEG00217', 2, 'KOR-S01-LEG-00217-2'),
        ('KORIS0001LEG00217', 4, 'KOR-S01-LEG-00217-4'),
        ('KORIS0001MYT00253', 1, 'KOR-S01-MYT-00253-1'),
        ('KORIS0001MYT00253', 2, 'KOR-S01-MYT-00253-2'),
        ('KORIS0001MYT00253', 3, 'KOR-S01-MYT-00253-3'),
        ('KORIS0001DIV00277', 1, 'KOR-S01-DIV-00277-1'),
        ('KORIS0001DIV00277', 3, 'KOR-S01-DIV-00277-3')
)
INSERT INTO gatcha_design_image_variants
    (design_id, variant_no, image_url, thumbnail_image_url, label, is_primary)
SELECT
    variants.design_id,
    variants.variant_no,
    '/assets/card-gatcha/blank/' || variants.asset_stem || '_NO-SERIAL_1-of-1.webp',
    '/assets/card-gatcha/blank/' || variants.asset_stem || '_NO-SERIAL_1-of-1.webp',
    'CASE ' || variants.variant_no,
    variants.variant_no = 1
FROM variants
JOIN gatcha_designs d ON d.design_id = variants.design_id
ON CONFLICT (design_id, variant_no) DO UPDATE
SET image_url = EXCLUDED.image_url,
    thumbnail_image_url = EXCLUDED.thumbnail_image_url,
    label = EXCLUDED.label,
    is_primary = EXCLUDED.is_primary,
    updated_at = NOW();

WITH variant_ranks AS (
    SELECT
        design_id,
        variant_no,
        ROW_NUMBER() OVER (PARTITION BY design_id ORDER BY variant_no ASC) AS variant_rank,
        COUNT(*) OVER (PARTITION BY design_id) AS variant_count
    FROM gatcha_design_image_variants
)
UPDATE gatcha_cards c
SET design_variant_no = variant_ranks.variant_no
FROM variant_ranks
WHERE c.design_id = variant_ranks.design_id
  AND c.design_variant_no IS NULL
  AND variant_ranks.variant_rank = ((c.serial_no - 1) % variant_ranks.variant_count) + 1;
