ALTER TABLE gatcha_draws
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_draw_type,
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_benefit_date;

ALTER TABLE gatcha_draws
    ADD CONSTRAINT ck_gatcha_draws_draw_type
        CHECK (draw_type IN ('PAID', 'VIP_DAILY_FREE', 'VIP_MONTHLY_FREE')),
    ADD CONSTRAINT ck_gatcha_draws_benefit_date
        CHECK ((draw_type = 'PAID' AND benefit_date IS NULL)
            OR (draw_type IN ('VIP_DAILY_FREE', 'VIP_MONTHLY_FREE') AND benefit_date IS NOT NULL));

CREATE UNIQUE INDEX ux_gatcha_draws_vip_monthly_free
    ON gatcha_draws (user_id, benefit_date)
    WHERE draw_type = 'VIP_MONTHLY_FREE'
      AND status IN ('PENDING', 'CHARGED', 'COMPLETED');

COMMENT ON COLUMN gatcha_draws.draw_type IS 'PAID, VIP_DAILY_FREE, or VIP_MONTHLY_FREE';
