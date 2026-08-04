-- 합성 투입 카드/디자인 목록은 JSON 문자열이 아니라 JSON 배열로 저장한다.
-- 기존 생산자가 이중 인코딩한 배열 문자열은 원래 배열로 복구한다.

UPDATE gatcha_upgrade_attempts
SET consumed_card_ids = CASE
        WHEN jsonb_typeof(consumed_card_ids) = 'string'
             AND left(consumed_card_ids #>> '{}', 1) = '['
            THEN (consumed_card_ids #>> '{}')::jsonb
        WHEN jsonb_typeof(consumed_card_ids) = 'array'
            THEN consumed_card_ids
        ELSE jsonb_build_array(consumed_card_ids #>> '{}')
    END,
    consumed_card_design_ids = CASE
        WHEN jsonb_typeof(consumed_card_design_ids) = 'string'
             AND left(consumed_card_design_ids #>> '{}', 1) = '['
            THEN (consumed_card_design_ids #>> '{}')::jsonb
        WHEN jsonb_typeof(consumed_card_design_ids) = 'array'
            THEN consumed_card_design_ids
        ELSE jsonb_build_array(consumed_card_design_ids #>> '{}')
    END
WHERE jsonb_typeof(consumed_card_ids) <> 'array'
   OR jsonb_typeof(consumed_card_design_ids) <> 'array';

ALTER TABLE gatcha_upgrade_attempts
    ADD CONSTRAINT ck_gatcha_upgrade_attempts_consumed_card_ids_array
        CHECK (jsonb_typeof(consumed_card_ids) = 'array'),
    ADD CONSTRAINT ck_gatcha_upgrade_attempts_consumed_design_ids_array
        CHECK (jsonb_typeof(consumed_card_design_ids) = 'array');
