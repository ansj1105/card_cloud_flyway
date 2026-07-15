-- 카드 게임 속성 확장 (하스스톤/포켓몬/유희왕류):
-- 사용 코스트, 공격력/방어력/체력, 직업군, 패시브 스킬.
-- 전부 디자인(카드 종류) 레벨 속성이다 — 같은 디자인의 개별 카드(시리얼)는 스탯을 공유하고,
-- 개별 카드의 고유번호는 기존 gatcha_cards.card_code(디자인ID+시리얼, UNIQUE)가 담당한다.
-- 값은 전부 운영 데이터: 관리자 API/SQL로 등록·수정 (기본값 0 = 미설정).

-- 직업군 (운영 중 추가 가능)
CREATE TABLE gatcha_job_classes (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,     -- WARRIOR / MAGE / RANGER ...
    name        VARCHAR(40) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 스킬 사전 (여러 카드가 같은 스킬을 공유할 수 있으므로 M:N)
CREATE TABLE gatcha_skills (
    id          BIGSERIAL   PRIMARY KEY,
    code        VARCHAR(40) NOT NULL UNIQUE,
    name        VARCHAR(80) NOT NULL,
    kind        VARCHAR(10) NOT NULL DEFAULT 'PASSIVE'
                CHECK (kind IN ('PASSIVE', 'ACTIVE', 'AURA', 'TRIGGER')),
    description TEXT,
    params      JSONB       NOT NULL DEFAULT '{}'::jsonb,  -- 수치 파라미터(피해량/지속턴 등)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE gatcha_design_skills (
    design_id  VARCHAR(40) NOT NULL REFERENCES gatcha_designs(design_id),
    skill_id   BIGINT      NOT NULL REFERENCES gatcha_skills(id),
    slot       SMALLINT    NOT NULL DEFAULT 1,   -- 표시 순서/슬롯
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (design_id, skill_id)
);

CREATE INDEX idx_gatcha_design_skills_skill ON gatcha_design_skills (skill_id);

-- 디자인 전투 속성
ALTER TABLE gatcha_designs
    ADD COLUMN job_class_id SMALLINT REFERENCES gatcha_job_classes(id),
    ADD COLUMN play_cost    SMALLINT NOT NULL DEFAULT 0 CHECK (play_cost >= 0),
    ADD COLUMN attack       INT      NOT NULL DEFAULT 0 CHECK (attack >= 0),
    ADD COLUMN defense      INT      NOT NULL DEFAULT 0 CHECK (defense >= 0),
    ADD COLUMN hp           INT      NOT NULL DEFAULT 0 CHECK (hp >= 0);

CREATE INDEX idx_gatcha_designs_job_class ON gatcha_designs (job_class_id);
