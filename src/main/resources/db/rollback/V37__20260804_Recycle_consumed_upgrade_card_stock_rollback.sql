DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM gatcha_cards
        GROUP BY design_id, serial_no
        HAVING COUNT(*) > 1
    ) OR EXISTS (
        SELECT 1
        FROM gatcha_cards
        GROUP BY case_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'V37 rollback blocked: recycled card history contains duplicate serial or case identifiers.';
    END IF;
END;
$$;

DROP INDEX IF EXISTS ux_gatcha_cards_active_case_id;
DROP INDEX IF EXISTS ux_gatcha_cards_active_design_serial;

ALTER TABLE gatcha_cards
    ADD CONSTRAINT gatcha_cards_design_id_serial_no_key UNIQUE (design_id, serial_no);

CREATE UNIQUE INDEX ux_gatcha_cards_case_id
    ON gatcha_cards (case_id);
