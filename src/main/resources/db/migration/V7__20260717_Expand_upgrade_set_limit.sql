-- V7: 합성 세트 한도 확장 — 기존 3세트(9장)에서 10세트(30장)까지.
-- UI는 세트 단위(서로 다른 디자인 3장)로 순차 선택한다.

ALTER TABLE gatcha_upgrades DROP CONSTRAINT IF EXISTS gatcha_upgrades_selected_card_count_check;
ALTER TABLE gatcha_upgrades ADD CONSTRAINT gatcha_upgrades_selected_card_count_check
    CHECK (selected_card_count % 3 = 0 AND selected_card_count BETWEEN 3 AND 30);

ALTER TABLE gatcha_upgrades DROP CONSTRAINT IF EXISTS gatcha_upgrades_attempt_count_check;
ALTER TABLE gatcha_upgrades ADD CONSTRAINT gatcha_upgrades_attempt_count_check
    CHECK (attempt_count BETWEEN 1 AND 10);
