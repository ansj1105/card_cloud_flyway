-- NFC 발행용 개별 카드 케이스 식별자.
-- card_code는 V8 이후 디자인 식별자와 동일하므로, 같은 디자인에서 여러 장 발급된
-- 실물/발행본을 구분하는 전역 UNIQUE 값은 case_id가 담당한다.

ALTER TABLE gatcha_cards
    ADD COLUMN IF NOT EXISTS case_id VARCHAR(96);

UPDATE gatcha_cards
   SET case_id = 'CASE-' || design_id || '-' || lpad(serial_no::text, 6, '0')
 WHERE case_id IS NULL
    OR btrim(case_id) = '';

CREATE OR REPLACE FUNCTION trg_gatcha_cards_assign_case_id() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.case_id IS NULL OR btrim(NEW.case_id) = '' THEN
        NEW.case_id := 'CASE-' || NEW.design_id || '-' || lpad(NEW.serial_no::text, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS gatcha_cards_assign_case_id ON gatcha_cards;
CREATE TRIGGER gatcha_cards_assign_case_id
    BEFORE INSERT ON gatcha_cards
    FOR EACH ROW EXECUTE FUNCTION trg_gatcha_cards_assign_case_id();

ALTER TABLE gatcha_cards
    ALTER COLUMN case_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_gatcha_cards_case_id
    ON gatcha_cards (case_id);

COMMENT ON COLUMN gatcha_cards.case_id IS 'NFC 발행용 개별 카드 케이스 식별자. 같은 디자인의 발행본을 전역 UNIQUE로 구분한다.';
