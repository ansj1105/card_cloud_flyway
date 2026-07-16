-- V6: 유저별 카드 가챠 화면 설정 (정렬 등) — 기기·브라우저를 바꿔도 유지되도록 서버 저장.
-- card_sort: NUMBER(카드 넘버순) | SEASON(시즌순) | ACQUIRED(획득일자순) | RARITY(등급순)

CREATE TABLE gatcha_user_prefs (
    user_id    BIGINT      PRIMARY KEY,
    card_sort  VARCHAR(20) NOT NULL DEFAULT 'ACQUIRED'
               CHECK (card_sort IN ('NUMBER', 'SEASON', 'ACQUIRED', 'RARITY')),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
