DROP INDEX IF EXISTS ux_gatcha_draws_vip_daily_free;

ALTER TABLE gatcha_draws
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_benefit_date,
    DROP CONSTRAINT IF EXISTS ck_gatcha_draws_draw_type,
    DROP COLUMN IF EXISTS benefit_date,
    DROP COLUMN IF EXISTS draw_type;
