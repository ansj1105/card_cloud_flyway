DROP INDEX IF EXISTS ux_gatcha_cards_case_id;

DROP TRIGGER IF EXISTS gatcha_cards_assign_case_id ON gatcha_cards;
DROP FUNCTION IF EXISTS trg_gatcha_cards_assign_case_id();

ALTER TABLE gatcha_cards
    DROP COLUMN IF EXISTS case_id;
