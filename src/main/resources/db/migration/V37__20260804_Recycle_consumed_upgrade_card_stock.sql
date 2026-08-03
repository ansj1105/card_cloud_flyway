-- 합성에 사용된 카드는 감사 이력으로 남기되, 동일 디자인/시리얼 재고는 다시 발급할 수 있다.
-- 현재 유효한 카드만 유니크하게 유지하며 CONSUMED 이력은 중복 시리얼을 허용한다.

ALTER TABLE gatcha_cards
    DROP CONSTRAINT IF EXISTS gatcha_cards_design_id_serial_no_key;

DROP INDEX IF EXISTS ux_gatcha_cards_case_id;

CREATE UNIQUE INDEX ux_gatcha_cards_active_design_serial
    ON gatcha_cards (design_id, serial_no)
    WHERE status IN ('OWNED', 'LOCKED', 'BURNED');

CREATE UNIQUE INDEX ux_gatcha_cards_active_case_id
    ON gatcha_cards (case_id)
    WHERE status IN ('OWNED', 'LOCKED', 'BURNED');

COMMENT ON INDEX ux_gatcha_cards_active_design_serial IS
    '합성 소모(CONSUMED) 이력을 보존하면서 현재 점유 중인 디자인/시리얼의 중복 발급을 차단한다.';

COMMENT ON INDEX ux_gatcha_cards_active_case_id IS
    '합성 소모(CONSUMED) 이력을 보존하면서 현재 점유 중인 카드 케이스의 중복 발급을 차단한다.';
