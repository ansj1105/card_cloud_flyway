ALTER TABLE gatcha_draws
    ADD COLUMN IF NOT EXISTS draw_type VARCHAR(32) NOT NULL DEFAULT 'PAID',
    ADD COLUMN IF NOT EXISTS benefit_date DATE;

ALTER TABLE gatcha_draws
    ADD CONSTRAINT ck_gatcha_draws_draw_type
        CHECK (draw_type IN ('PAID', 'VIP_DAILY_FREE')),
    ADD CONSTRAINT ck_gatcha_draws_benefit_date
        CHECK ((draw_type = 'PAID' AND benefit_date IS NULL)
            OR (draw_type = 'VIP_DAILY_FREE' AND benefit_date IS NOT NULL));

CREATE UNIQUE INDEX ux_gatcha_draws_vip_daily_free
    ON gatcha_draws (user_id, benefit_date)
    WHERE draw_type = 'VIP_DAILY_FREE'
      AND status IN ('PENDING', 'CHARGED', 'COMPLETED');

COMMENT ON COLUMN gatcha_draws.draw_type IS 'PAID or VIP_DAILY_FREE';
COMMENT ON COLUMN gatcha_draws.benefit_date IS 'VIP daily benefit date in Asia/Seoul';
