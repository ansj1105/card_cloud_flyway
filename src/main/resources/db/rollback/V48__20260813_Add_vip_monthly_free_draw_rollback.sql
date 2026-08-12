DROP INDEX IF EXISTS ux_gatcha_draws_vip_monthly_free;

ALTER TABLE gatcha_draws
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_benefit_date,
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_draw_type;

ALTER TABLE gatcha_draws
    ADD CONSTRAINT ck_gatcha_draws_draw_type
        CHECK (draw_type IN ('PAID', 'VIP_DAILY_FREE')),
    ADD CONSTRAINT ck_gatcha_draws_benefit_date
        CHECK ((draw_type = 'PAID' AND benefit_date IS NULL)
            OR (draw_type = 'VIP_DAILY_FREE' AND benefit_date IS NOT NULL));

COMMENT ON COLUMN gatcha_draws.draw_type IS 'PAID or VIP_DAILY_FREE';
