ALTER TABLE gatcha_designs
    ADD COLUMN IF NOT EXISTS thumbnail_image_url VARCHAR(255);

COMMENT ON COLUMN gatcha_designs.thumbnail_image_url IS '카드 뽑기/목록 등 작은 슬롯에서 사용하는 축소 이미지 URL. image_url은 상세/확대/원본용.';
