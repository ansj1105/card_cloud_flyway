-- 배열 정규화 데이터는 유효한 JSONB이므로 그대로 유지하고,
-- 긴급 롤백 시 신규 쓰기를 막는 타입 제약만 제거한다.

ALTER TABLE gatcha_upgrade_attempts
    DROP CONSTRAINT IF EXISTS ck_gatcha_upgrade_attempts_consumed_card_ids_array,
    DROP CONSTRAINT IF EXISTS ck_gatcha_upgrade_attempts_consumed_design_ids_array;
