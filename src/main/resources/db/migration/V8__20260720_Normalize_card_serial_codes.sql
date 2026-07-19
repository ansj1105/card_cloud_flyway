-- 카드 식별 정책 정규화:
--   <KORION prefix><season><rarity><design number>
--   예: KORIS001COM0001
--
-- 기존 KOR-S01-COM-0001 형태의 design_id/card_code를 운영 정책에 맞춘다.
-- gatcha_cards.card_code는 개별 시리얼 문자열이 아니라 카드 디자인 식별자와
-- 동일하게 저장한다. 개별 발급 번호는 serial_no와 UNIQUE(design_id, serial_no)가
-- 소유한다.

DO $$
BEGIN
    CREATE TEMP TABLE tmp_gatcha_design_code_map ON COMMIT DROP AS
    SELECT
        d.design_id AS old_design_id,
        'KORI'
            || CASE
                WHEN s.code ~ '^S[0-9]+$' THEN 'S' || lpad(substring(s.code FROM 2), 3, '0')
                ELSE regexp_replace(upper(s.code), '[^A-Z0-9]', '', 'g')
               END
            || upper(r.code)
            || lpad(d.design_no::text, 4, '0') AS new_design_id
    FROM gatcha_designs d
    JOIN gatcha_rarities r ON r.id = d.rarity_id
    JOIN gatcha_seasons s ON s.id = r.season_id
    WHERE d.design_id IS DISTINCT FROM (
        'KORI'
            || CASE
                WHEN s.code ~ '^S[0-9]+$' THEN 'S' || lpad(substring(s.code FROM 2), 3, '0')
                ELSE regexp_replace(upper(s.code), '[^A-Z0-9]', '', 'g')
               END
            || upper(r.code)
            || lpad(d.design_no::text, 4, '0')
    );

    IF EXISTS (
        SELECT 1
        FROM tmp_gatcha_design_code_map
        GROUP BY new_design_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Card gatcha code normalization would create duplicate design_id values.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM gatcha_designs d
        JOIN tmp_gatcha_design_code_map m ON m.new_design_id = d.design_id
        WHERE d.design_id <> m.old_design_id
    ) THEN
        RAISE EXCEPTION 'Card gatcha code normalization conflicts with an existing design_id.';
    END IF;

    ALTER TABLE gatcha_cards
        ALTER CONSTRAINT gatcha_cards_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;

    ALTER TABLE gatcha_design_skills
        ALTER CONSTRAINT gatcha_design_skills_design_id_fkey DEFERRABLE INITIALLY IMMEDIATE;

    SET CONSTRAINTS gatcha_cards_design_id_fkey, gatcha_design_skills_design_id_fkey DEFERRED;

    ALTER TABLE gatcha_cards
        DROP CONSTRAINT IF EXISTS gatcha_cards_card_code_key;

    UPDATE gatcha_designs d
       SET design_id = m.new_design_id
      FROM tmp_gatcha_design_code_map m
     WHERE d.design_id = m.old_design_id;

    UPDATE gatcha_cards c
       SET design_id = m.new_design_id,
           card_code = m.new_design_id
      FROM tmp_gatcha_design_code_map m
     WHERE c.design_id = m.old_design_id;

    UPDATE gatcha_cards
       SET card_code = design_id
     WHERE card_code IS DISTINCT FROM design_id;

    UPDATE gatcha_design_skills ds
       SET design_id = m.new_design_id
      FROM tmp_gatcha_design_code_map m
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
          LEFT JOIN tmp_gatcha_design_code_map m ON m.old_design_id = trim(both '"' FROM ids.value::text)
          GROUP BY normalized.id
      ) mapped
     WHERE a.id = mapped.id
       AND a.consumed_card_design_ids IS DISTINCT FROM mapped.next_design_ids;
END $$;
