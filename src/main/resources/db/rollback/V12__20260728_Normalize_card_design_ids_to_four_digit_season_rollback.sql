DO $$
BEGIN
    CREATE TEMP TABLE tmp_gatcha_design_three_digit_season_map ON COMMIT DROP AS
    SELECT
        d.design_id AS old_design_id,
        regexp_replace(d.design_id, '^KORIS0([0-9]{3})([A-Z]{3}[0-9]{4})$', 'KORIS\1\2') AS new_design_id
    FROM gatcha_designs d
    WHERE d.design_id ~ '^KORIS0[0-9]{3}[A-Z]{3}[0-9]{4}$';

    ALTER TABLE gatcha_cards
        ALTER CONSTRAINT gatcha_cards_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;

    ALTER TABLE gatcha_design_skills
        ALTER CONSTRAINT gatcha_design_skills_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;

    SET CONSTRAINTS gatcha_cards_design_id_fkey, gatcha_design_skills_design_id_fkey DEFERRED;

    UPDATE gatcha_designs d
       SET design_id = m.new_design_id
      FROM tmp_gatcha_design_three_digit_season_map m
     WHERE d.design_id = m.old_design_id;

    UPDATE gatcha_cards c
       SET design_id = m.new_design_id,
           card_code = m.new_design_id,
           case_id = 'CASE-' || m.new_design_id || '-' || lpad(c.serial_no::text, 6, '0')
      FROM tmp_gatcha_design_three_digit_season_map m
     WHERE c.design_id = m.old_design_id;

    UPDATE gatcha_design_skills ds
       SET design_id = m.new_design_id
      FROM tmp_gatcha_design_three_digit_season_map m
     WHERE ds.design_id = m.old_design_id;

    UPDATE gatcha_upgrade_attempts a
       SET consumed_card_design_ids = mapped.next_design_ids
      FROM (
          SELECT
              normalized.id,
              jsonb_agg(COALESCE(to_jsonb(m.new_design_id), value) ORDER BY ordinality) AS next_design_ids
          FROM (
              SELECT
                  id,
                  CASE
                      WHEN jsonb_typeof(consumed_card_design_ids) = 'array' THEN consumed_card_design_ids
                      WHEN jsonb_typeof(consumed_card_design_ids) = 'string'
                           AND left(consumed_card_design_ids #>> '{}', 1) = '['
                          THEN (consumed_card_design_ids #>> '{}')::jsonb
                      ELSE jsonb_build_array(consumed_card_design_ids #>> '{}')
                  END AS design_ids
              FROM gatcha_upgrade_attempts
          ) normalized
          CROSS JOIN LATERAL jsonb_array_elements(normalized.design_ids) WITH ORDINALITY AS ids(value, ordinality)
          LEFT JOIN tmp_gatcha_design_three_digit_season_map m ON m.old_design_id = trim(both '"' FROM ids.value::text)
          GROUP BY normalized.id
      ) mapped
     WHERE a.id = mapped.id
       AND a.consumed_card_design_ids IS DISTINCT FROM mapped.next_design_ids;
END $$;
