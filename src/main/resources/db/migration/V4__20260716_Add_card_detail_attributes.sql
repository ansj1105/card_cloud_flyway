-- 카드 목업(2026-07-16) 대비 누락 속성 보강:
-- MOV(이동력)/RNG(사거리), 종족(Cat)·소속(Korion), 스킬 코스트/사거리, 시즌 표시명.
-- 전부 운영 데이터(기본 0/NULL) — 관리자 API로 입력.

ALTER TABLE gatcha_designs
    ADD COLUMN move    SMALLINT    NOT NULL DEFAULT 0 CHECK (move >= 0),      -- MOV 이동력
    ADD COLUMN range   SMALLINT    NOT NULL DEFAULT 0 CHECK (range >= 0),     -- RNG 기본 사거리
    ADD COLUMN species VARCHAR(40),                                           -- 종족 (예: Cat)
    ADD COLUMN faction VARCHAR(40);                                           -- 소속/세계관 (예: Korion)

-- 스킬별 사용 코스트(보석)와 사거리 — 카드 목업의 "SKL Echo Pounce ◆1 RNG 1"
ALTER TABLE gatcha_skills
    ADD COLUMN cost        SMALLINT CHECK (cost IS NULL OR cost >= 0),
    ADD COLUMN skill_range SMALLINT CHECK (skill_range IS NULL OR skill_range >= 0);

-- 시즌 표시명 (카드 상단 타이틀/세트명 노출용)
ALTER TABLE gatcha_seasons
    ADD COLUMN name VARCHAR(40);

UPDATE gatcha_seasons SET name = 'ARENA' WHERE code = 'S01' AND name IS NULL;
