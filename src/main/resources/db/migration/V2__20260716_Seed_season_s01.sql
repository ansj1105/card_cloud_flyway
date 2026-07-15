-- S01 시즌 시드: fox_coin CardGatchaService 하드코딩 값 이관.
-- weight는 1,000,000 기준(합 = 1,000,000 = 100%). 이후 변경은 관리자 API/SQL로
-- 자유(가변 설정값) — 트리거가 gatcha_rate_audit에 이력을 남긴다.

INSERT INTO gatcha_seasons (code, status, draw_cost, currency_code, exhaustion_policy)
VALUES ('S01', 'ACTIVE', 1, 'KORI', 'EXCLUDE_RENORMALIZE');

INSERT INTO gatcha_rarities (season_id, code, label, color, weight, upgrade_success_bp, sort_order)
SELECT s.id, r.code, r.label, r.color, r.weight, r.bp, r.sort
FROM gatcha_seasons s,
     (VALUES
        ('COM', '일반', '회색/실버',       720000, 6500, 1),
        ('MID', '중급', '초록',            200000, 3500, 2),
        ('ADV', '고급', '파랑',             60000, 1800, 3),
        ('RAR', '희귀', '보라',             15000,  700, 4),
        ('HER', '영웅', '핑크/레드',         4500,  200, 5),
        ('LEG', '전설', '금색',               490,   50, 6),
        ('MYT', '신화', '오로라/플래티넘',      10,    0, 7)
     ) AS r(code, label, color, weight, bp, sort)
WHERE s.code = 'S01';

-- 디자인 70종 (등급별 10종 × 에디션 500장 = 총 35,000장)
INSERT INTO gatcha_designs (rarity_id, design_id, design_no, name, edition_size)
SELECT ra.id,
       'KOR-S01-' || ra.code || '-' || lpad(d.design_no::text, 4, '0'),
       d.design_no,
       d.name,
       500
FROM gatcha_rarities ra
JOIN gatcha_seasons s ON s.id = ra.season_id AND s.code = 'S01'
JOIN (VALUES
    ('COM', 1, 'Signal Kitten'),   ('COM', 2, 'Metro Pass'),      ('COM', 3, 'Node Marble'),
    ('COM', 4, 'Daily Circuit'),   ('COM', 5, 'Silver Token'),    ('COM', 6, 'Base Capsule'),
    ('COM', 7, 'Proof Tile'),      ('COM', 8, 'Core Note'),       ('COM', 9, 'Soft Ledger'),
    ('COM', 10, 'Quiet Relay'),
    ('MID', 1, 'Green Relay'),     ('MID', 2, 'Mint Terminal'),   ('MID', 3, 'Forest Link'),
    ('MID', 4, 'Safe Route'),      ('MID', 5, 'Emerald Node'),    ('MID', 6, 'Token Bloom'),
    ('MID', 7, 'Sync Garden'),     ('MID', 8, 'Mint Beacon'),     ('MID', 9, 'Verdant Pass'),
    ('MID', 10, 'Peer Leaf'),
    ('ADV', 1, 'Blue Vault'),      ('ADV', 2, 'Orbit Ledger'),    ('ADV', 3, 'Aster Gate'),
    ('ADV', 4, 'Prime Beacon'),    ('ADV', 5, 'Azure Proof'),     ('ADV', 6, 'NFC Vector'),
    ('ADV', 7, 'Offline Key'),     ('ADV', 8, 'Sky Archive'),     ('ADV', 9, 'Beacon Vault'),
    ('ADV', 10, 'Blue Circuit'),
    ('RAR', 1, 'Violet Sentinel'), ('RAR', 2, 'Royal Node'),      ('RAR', 3, 'Night Archive'),
    ('RAR', 4, 'Lumen Key'),       ('RAR', 5, 'Purple Cipher'),   ('RAR', 6, 'Rare Relay'),
    ('RAR', 7, 'Moon Proof'),      ('RAR', 8, 'Velvet Signal'),   ('RAR', 9, 'Violet Pass'),
    ('RAR', 10, 'Shadow Vault'),
    ('HER', 1, 'Crimson Oracle'),  ('HER', 2, 'Heroic Pulse'),    ('HER', 3, 'Scarlet Proof'),
    ('HER', 4, 'Nova Crown'),      ('HER', 5, 'Hero Beacon'),     ('HER', 6, 'Red Meridian'),
    ('HER', 7, 'Crimson Root'),    ('HER', 8, 'Pulse Archive'),   ('HER', 9, 'Flare Node'),
    ('HER', 10, 'Crown Proof'),
    ('LEG', 1, 'Golden Meridian'), ('LEG', 2, 'Legend Bridge'),   ('LEG', 3, 'Solar Genesis'),
    ('LEG', 4, 'Crown Ledger'),    ('LEG', 5, 'Gold Relay'),      ('LEG', 6, 'Aurum Proof'),
    ('LEG', 7, 'Legend Vault'),    ('LEG', 8, 'Sun Archive'),     ('LEG', 9, 'Golden Root'),
    ('LEG', 10, 'Royal Circuit'),
    ('MYT', 1, 'Aurora Origin'),   ('MYT', 2, 'Mythic Root'),     ('MYT', 3, 'Platinum Star'),
    ('MYT', 4, 'Genesis Halo'),    ('MYT', 5, 'Mythic Ledger'),   ('MYT', 6, 'Aurora Proof'),
    ('MYT', 7, 'Halo Vault'),      ('MYT', 8, 'Origin Signal'),   ('MYT', 9, 'Platinum Node'),
    ('MYT', 10, 'Genesis Key')
) AS d(rarity_code, design_no, name) ON d.rarity_code = ra.code;
