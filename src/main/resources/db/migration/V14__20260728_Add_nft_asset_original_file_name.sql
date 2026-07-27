ALTER TABLE gatcha_nft_asset_jobs
    ADD COLUMN IF NOT EXISTS original_file_name VARCHAR(255);

COMMENT ON COLUMN gatcha_nft_asset_jobs.original_file_name IS '관리자가 업로드한 NFT 원본 이미지 파일명.';
