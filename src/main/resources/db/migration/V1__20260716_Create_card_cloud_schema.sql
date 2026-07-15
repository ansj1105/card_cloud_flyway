-- card_cloud: 카드 가챠 전용 DB (coin_system_cloud와 분리).
-- 유저/지갑은 코인 DB 소유이므로 user_id는 FK 없이 BIGINT로만 보관한다.
-- 확률(weight)·발행량(edition_size)은 운영 중 변경 가능한 데이터이며,
-- 변경은 트리거가 감사 테이블에 무조건 기록한다(수동 SQL 변경 포함).

-- ============================================================
-- 시즌: 비용/소진정책의 버전 단위
-- ============================================================
CREATE TABLE gatcha_seasons (
    id                SMALLSERIAL PRIMARY KEY,
    code              VARCHAR(20)    NOT NULL UNIQUE,
    status            VARCHAR(10)    NOT NULL DEFAULT 'DRAFT'
                      CHECK (status IN ('DRAFT', 'ACTIVE', 'CLOSED')),
    draw_cost         NUMERIC(36,18) NOT NULL CHECK (draw_cost >= 0),
    currency_code     VARCHAR(10)    NOT NULL DEFAULT 'KORI',
    exhaustion_policy VARCHAR(30)    NOT NULL DEFAULT 'EXCLUDE_RENORMALIZE'
                      CHECK (exhaustion_policy IN ('EXCLUDE_RENORMALIZE', 'SPILL_DOWN', 'FAIL_AND_REFUND')),
    created_at        TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ    NOT NULL DEFAULT now()
);

-- ============================================================
-- 등급: /card-gatcha/rates 의 원천. weight는 1,000,000 기준 가중치이며
-- 운영 중 변경 가능(고정 설정값 아님) — 변경 이력은 gatcha_rate_audit.
-- ============================================================
CREATE TABLE gatcha_rarities (
    id                 SMALLSERIAL PRIMARY KEY,
    season_id          SMALLINT    NOT NULL REFERENCES gatcha_seasons(id),
    code               VARCHAR(10) NOT NULL,
    label              VARCHAR(20) NOT NULL,
    color              VARCHAR(30),
    weight             INT         NOT NULL CHECK (weight >= 0),
    upgrade_success_bp INT         NOT NULL DEFAULT 0
                       CHECK (upgrade_success_bp BETWEEN 0 AND 10000),
    sort_order         SMALLINT    NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (season_id, code)
);

CREATE TABLE gatcha_rate_audit (
    id          BIGSERIAL   PRIMARY KEY,
    rarity_id   SMALLINT    NOT NULL REFERENCES gatcha_rarities(id),
    old_weight  INT         NOT NULL,
    new_weight  INT         NOT NULL,
    changed_by  VARCHAR(80) NOT NULL,   -- DB 세션 유저(관리자 API는 app 유저로 접속 + 상세는 앱 감사로그)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION trg_gatcha_rate_audit() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.weight IS DISTINCT FROM OLD.weight THEN
        INSERT INTO gatcha_rate_audit (rarity_id, old_weight, new_weight, changed_by)
        VALUES (OLD.id, OLD.weight, NEW.weight, session_user);
    END IF;
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER gatcha_rarities_rate_audit
    BEFORE UPDATE ON gatcha_rarities
    FOR EACH ROW EXECUTE FUNCTION trg_gatcha_rate_audit();

-- ============================================================
-- 디자인(카드 종류) + 재고 카운터 일체형.
-- 관리자 "카드 추가" = INSERT, "갯수 추가" = edition_size 증가(감소는 발급량 밑으로 불가).
-- issued_count가 시리얼 발급기: UPDATE ... WHERE issued_count < edition_size RETURNING.
-- ============================================================
CREATE TABLE gatcha_designs (
    id           BIGSERIAL   PRIMARY KEY,
    rarity_id    SMALLINT    NOT NULL REFERENCES gatcha_rarities(id),
    design_id    VARCHAR(40) NOT NULL UNIQUE,
    design_no    INT         NOT NULL,
    name         VARCHAR(80) NOT NULL,
    image_url    VARCHAR(255),
    edition_size INT         NOT NULL CHECK (edition_size > 0),
    issued_count INT         NOT NULL DEFAULT 0,
    status       VARCHAR(10) NOT NULL DEFAULT 'ACTIVE'
                 CHECK (status IN ('ACTIVE', 'PAUSED', 'RETIRED')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (issued_count >= 0 AND issued_count <= edition_size),
    UNIQUE (rarity_id, design_no)
);

CREATE TABLE gatcha_supply_audit (
    id               BIGSERIAL   PRIMARY KEY,
    design_id        VARCHAR(40) NOT NULL,
    old_edition_size INT         NOT NULL,
    new_edition_size INT         NOT NULL,
    changed_by       VARCHAR(80) NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION trg_gatcha_supply_audit() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.edition_size IS DISTINCT FROM OLD.edition_size THEN
        IF NEW.edition_size < OLD.issued_count THEN
            RAISE EXCEPTION 'edition_size(%) cannot be reduced below issued_count(%)',
                NEW.edition_size, OLD.issued_count;
        END IF;
        INSERT INTO gatcha_supply_audit (design_id, old_edition_size, new_edition_size, changed_by)
        VALUES (OLD.design_id, OLD.edition_size, NEW.edition_size, session_user);
    END IF;
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER gatcha_designs_supply_audit
    BEFORE UPDATE ON gatcha_designs
    FOR EACH ROW EXECUTE FUNCTION trg_gatcha_supply_audit();

-- ============================================================
-- 뽑기 원장 (크로스 DB 사가 상태 포함).
-- rate_snapshot: 뽑기 시점의 등급별 weight 스냅샷(JSONB) — 확률이 가변이므로
-- 각 뽑기가 어떤 확률표로 수행됐는지 증빙으로 남긴다.
-- ============================================================
CREATE TABLE gatcha_draws (
    draw_id         UUID           PRIMARY KEY,
    user_id         BIGINT         NOT NULL,
    season_id       SMALLINT       NOT NULL REFERENCES gatcha_seasons(id),
    draw_count      INT            NOT NULL CHECK (draw_count IN (1, 10)),
    cost_amount     NUMERIC(36,18) NOT NULL,
    currency_code   VARCHAR(10)    NOT NULL,
    status          VARCHAR(20)    NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN ('PENDING', 'CHARGED', 'COMPLETED', 'FAILED', 'COMPENSATED')),
    charge_tx_ref   VARCHAR(64),
    idempotency_key VARCHAR(128),
    rate_snapshot   JSONB          NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uk_gatcha_draws_user_idem
    ON gatcha_draws (user_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_gatcha_draws_user_created
    ON gatcha_draws (user_id, created_at DESC);

-- 사가 보정 배치: 미수렴 건 스캔용
CREATE INDEX idx_gatcha_draws_saga_pending
    ON gatcha_draws (status, created_at)
    WHERE status IN ('PENDING', 'CHARGED');

-- ============================================================
-- 발급된 카드(개별 실물). rarity_code/label은 등급별 보유 조회를 위해 비정규화.
-- UNIQUE(design_id, serial_no)가 이중발급의 최후 방어선.
-- ============================================================
CREATE TABLE gatcha_cards (
    id           BIGSERIAL   PRIMARY KEY,
    draw_id      UUID        REFERENCES gatcha_draws(draw_id),
    upgrade_id   UUID,
    user_id      BIGINT      NOT NULL,
    season_code  VARCHAR(20) NOT NULL,
    rarity_code  VARCHAR(10) NOT NULL,
    rarity_label VARCHAR(20) NOT NULL,
    design_id    VARCHAR(40) NOT NULL REFERENCES gatcha_designs(design_id),
    card_name    VARCHAR(80) NOT NULL,
    serial_no    INT         NOT NULL,
    card_code    VARCHAR(60) NOT NULL UNIQUE,
    source       VARCHAR(20) NOT NULL DEFAULT 'OPEN'
                 CHECK (source IN ('OPEN', 'UPGRADE', 'ADMIN')),
    status       VARCHAR(20) NOT NULL DEFAULT 'OWNED'
                 CHECK (status IN ('OWNED', 'CONSUMED', 'LOCKED', 'BURNED')),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (design_id, serial_no)
);

-- 유저별 카드를 등급별로 구분해 보유/조회하는 핵심 인덱스
CREATE INDEX idx_gatcha_cards_user_rarity
    ON gatcha_cards (user_id, rarity_code, status, created_at DESC);

CREATE INDEX idx_gatcha_cards_draw ON gatcha_cards (draw_id);
CREATE INDEX idx_gatcha_cards_upgrade ON gatcha_cards (upgrade_id);

-- ============================================================
-- 합성(업그레이드) — 기존 coin_system_cloud V146 구조 이관(users FK 제거)
-- ============================================================
CREATE TABLE gatcha_upgrades (
    id                  BIGSERIAL   PRIMARY KEY,
    upgrade_id          UUID        NOT NULL UNIQUE,
    user_id             BIGINT      NOT NULL,
    source_rarity_code  VARCHAR(10) NOT NULL,
    source_rarity_label VARCHAR(20) NOT NULL,
    target_rarity_code  VARCHAR(10) NOT NULL,
    target_rarity_label VARCHAR(20) NOT NULL,
    selected_card_count INT         NOT NULL CHECK (selected_card_count IN (3, 6, 9)),
    attempt_count       INT         NOT NULL CHECK (attempt_count IN (1, 2, 3)),
    success_count       INT         NOT NULL DEFAULT 0,
    failure_count       INT         NOT NULL DEFAULT 0,
    status              VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_gatcha_upgrades_user_created
    ON gatcha_upgrades (user_id, created_at DESC);

CREATE TABLE gatcha_upgrade_attempts (
    id                       BIGSERIAL   PRIMARY KEY,
    upgrade_id               UUID        NOT NULL REFERENCES gatcha_upgrades(upgrade_id) ON DELETE CASCADE,
    user_id                  BIGINT      NOT NULL,
    attempt_no               INT         NOT NULL,
    consumed_card_ids        JSONB       NOT NULL,
    consumed_card_design_ids JSONB       NOT NULL,
    success                  BOOLEAN     NOT NULL,
    result_rarity_code       VARCHAR(10) NOT NULL,
    result_rarity_label      VARCHAR(20) NOT NULL,
    result_card_id           BIGINT      NOT NULL REFERENCES gatcha_cards(id) ON DELETE RESTRICT,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (upgrade_id, attempt_no)
);

CREATE INDEX idx_gatcha_upgrade_attempts_upgrade
    ON gatcha_upgrade_attempts (upgrade_id, attempt_no);
