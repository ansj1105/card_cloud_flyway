# 구현 진행 로그 (step-by-step)

설계·체크리스트: [DESIGN.md](DESIGN.md) — 본 문서는 각 단계의 실행 기록과 결정 사항.

## 2026-07-16 — DB 구축

1. 호스트 4대 RAM/디스크 실측 → foxya 운영 호스트 선정 (최대 RAM·디스크, fox_coin API와 동일 호스트).
2. `card-postgres` 컨테이너 기동: postgres:16-alpine, mem_limit 1g, shared_buffers 256MB,
   coin-shared 네트워크(`card-postgres:5432`) + 호스트 로컬 15433, 데이터 `/var/lib/card-postgres/data`.
   compose/자격증명: 운영 호스트 `/var/www/card_cloud/` (.env, .env.flyway — chmod 600).
3. flyway V1+V2 적용(flyway/flyway:10-alpine 컨테이너, --network coin-shared).
4. 스키마 실동작 검증(트랜잭션 내 테스트 후 롤백):
   - 등급 7종(가중치 합 1,000,000) / 디자인 70종 / 총발행 35,000 ✓
   - weight UPDATE → `gatcha_rate_audit` 트리거 자동 기록 ✓
   - edition_size UPDATE → `gatcha_supply_audit` 기록, 발급수 미만 감축은 예외 발생 ✓
   - `allocateSerial` 원자 할당: issued 3 → RETURNING 4 ✓

## 2026-07-16 — fox_coin 연동 (뽑기·합성·조회)

전제 확인: **프로덕션 coin_system_cloud에 card_gatcha 테이블 없음** (기능 미출시)
→ V146 데이터 이관 불필요, 첫 출시부터 card_cloud 사용.

구현(모두 fox_coin 저장소):

| 파일 | 내용 |
|------|------|
| `cardgatcha/CardCatalogRepository.java` (신규) | 시즌/등급(확률)/디자인·재고 조회 + `allocateSerial` 원자 할당 |
| `cardgatcha/CardGatchaChargeRepository.java` (신규) | 코인 DB 차감/환불 기록. 환불은 advisory lock + NOT EXISTS로 멱등 |
| `cardgatcha/CardGatchaRepository.java` (재작성) | gatcha_* 테이블 CRUD + 사가 CAS 상태전환 + stale 스캔 + 등급별 보유 조회 |
| `cardgatcha/CardGatchaService.java` (재작성) | 사가 오케스트레이션, DB 카탈로그(TTL 60s), 확률 롤(EXCLUDE_RENORMALIZE), 보정배치, rate_snapshot |
| `cardgatcha/CardGatchaHandler.java` | GET /cards(rarity/status/limit/page), GET /policy 추가 |
| `config/ConfigLoader.java` | CARD_DB_* env 오버라이드 |
| `resources/config.json` | 전 환경 `carddb` 섹션 (prod: card-postgres:5432/card_cloud) |
| `verticle/ApiVerticle.java` | cardPool 생성(미설정 시 가챠 라우트 503 스텁), 사가 reconciler 기동 |

### 사가 설계 (요청 경로)

```
[card] draws INSERT (PENDING, rate_snapshot)
→ [coin tx] deductBalance + wallet_transactions('CARD-GATCHA-{drawId}')   ← 잔고부족: draws=FAILED
→ [card] CAS PENDING→CHARGED
→ [card tx] allocateSerial×N + cards INSERT + CAS CHARGED→COMPLETED       ← 전부 성공 or 전부 롤백
   실패 시: CAS CHARGED→COMPENSATED(소유권 확보한 쪽만) → 멱등 환불
```

### 보정배치 (60s 주기, api replica 2대 동시 실행 안전)

- PENDING 5분↑: 코인 DB에 차감기록 없으면 FAILED, 있으면 CHARGED로 승격 후 발급 재시도
- CHARGED 5분↑: 카드 수 = draw_count면 COMPLETED 확정, 아니면 발급 재시도 → 실패 시 보상(환불)
- 15분↑ 잔류 건은 `CARD_GATCHA_SAGA_ALERT` 로그 (알람 패턴 등록 예정)
- 안전장치: 모든 상태전환이 CAS(UPDATE ... WHERE status=기대값), 환불은 tx_hash 기반 멱등 + advisory lock

### 결정 사항

- 소진 정책은 EXCLUDE_RENORMALIZE만 우선 구현(현행 동작 동일). SPILL_DOWN/FAIL_AND_REFUND는 시즌 컬럼만 예약.
- 전량 소진은 차감 **전** 사전 차단(SEASON_SOLD_OUT) — 환불 자체가 안 생기는 경로가 기본.
- 합성 결과 카드는 해당 등급 소진 시 실패(폴백 없음, 기존 정책 유지).
- 카드 응답의 `editionNo`는 호환성을 위해 상수 1 유지(스키마에서는 제거됨).
- 테스트 하니스(단일 DB 전제)는 2-DB 전환이 필요해 후속 단계로 분리 — 프로덕션 이미지 빌드는 `-x test`라 차단 없음.

## 2026-07-16 — 프로덕션 롤링 배포 (무중단)

1. compose에 CARD_DB_* env 전달 추가(app/app2), prod config는 `CARD_DB_HOST` env로만 활성화되게 게이트.
2. 운영 .env에 CARD_DB_* 주입(비밀번호는 card_cloud .env에서 파일 간 복사, 채팅 비노출).
3. 이미지 빌드로 컴파일 검증(1건 수정: issueCards enrich 타입) 후 app → nginx reload → app2 → reload 순 롤링 교체.
   deploy.sh는 서버 git 자격증명 부재로 git pull 단계에서 실패 → 스크립트의 update() 단계를 수동 동일 수행.
   (서버 .git/info/exclude에 배포 산출물 패턴 추가로 dirty-guard 정리)
4. 검증: 양 replica healthy, /api/v1/card-gatcha/policy 401(라우트 활성, 503 스텁 아님),
   card_cloud에 api 커넥션 확립, saga reconciler 기동 로그, 실 5xx 0건.
5. 운영 편입: foxya-db-backup.sh에 card_cloud 추가(실행 검증 — 로컬 백업 정상. 단, S3 오프사이트는
   2026-07-10부터 IAM PutObject 거부로 기존부터 실패 중 — 별도 이슈),
   alarm FOXYA_CRITICAL_LOG_PATTERNS에 CARD_GATCHA_SAGA_ALERT 등록 + 알람 재기동.

## 2026-07-16 — V3: 게임 속성 확장

- 요구: 패시브 스킬, 사용 코스트(하스스톤류), 공격력/방어력/체력, 직업군, 고유카드번호, 등급/넘버링/이름/시즌.
- V3 마이그레이션 적용: `gatcha_job_classes`, `gatcha_skills`(+params JSONB), `gatcha_design_skills`(M:N),
  `gatcha_designs`에 play_cost/attack/defense/hp/job_class_id. 매핑표는 DESIGN.md §4.1.
- fox_coin 카드 조회/뽑기 응답에 전투 속성 노출(디자인 조인) 후 롤링 재배포 완료.
- 스탯·스킬 값 입력은 관리자 API(다음 단계)로.

## 2026-07-16 — coin_csms 관리자 API (커밋 b34ae0a, 배포 완료)

`/api/v2/admin/card-gatcha/*` (ADMIN/SUPER_ADMIN, csms JWT):

| 엔드포인트 | 기능 |
|-----------|------|
| GET /overview?seasonCode= | 시즌·등급(확률/재고)·디자인·직업군·스킬 일괄 조회 (콘솔 화면용) |
| POST /designs | **카드 추가** — rarity/name/editionSize/스탯/직업군/이미지, design_no·design_id 자동 채번 |
| PATCH /designs/{id}/edition-size | **발행량 증량** — 발급수 미만 감축은 트리거 차단→400 안내 |
| PUT /seasons/{code}/weights | **확률 변경** — 전체 등급 세트 필수 + 합계 1,000,000(100%) 강제 |
| PATCH /designs/{id}/attributes | 코스트/공/방/체/직업군/이미지/이름/상태 수정 |
| PUT /designs/{id}/skills | 스킬 세트 교체(배열 순서=슬롯) |
| POST /seasons, PATCH /seasons/{code}/status | 시즌 생성(DRAFT)/상태 전환 |
| POST /job-classes, POST /skills | 직업군/스킬 사전 등록 |

- 이중 감사: card_cloud 트리거(rate/supply audit) + 코인DB admin_activity_logs(행위자·IP). 감사 기록 실패 시 실패 응답.
- CARD_DB_HOST env 게이트 — 미설정이면 카드 관리 API만 비활성.
- csms-api 단일 컨테이너 재생성으로 배포(관리자 콘솔만 ~20초 순단, 유저 API 무관). 라우트 401(활성)·env·DNS 확인.
- 참고(기존 이슈): csms 파일 로그(logs/csms.log)는 3월부터 권한 문제로 미기록(stdout 수집은 정상) — uid 일치 확인에도 재현, 후속 조사 필요.

## 2026-07-16 — V4(카드 목업 반영) + 상세보기 + 합성확률 관리 + e2e 검증 완료

카드 목업 점검 → V4 마이그레이션: MOV(move)/RNG(range) 스탯, 종족(species)·소속(faction),
스킬 코스트/사거리(gatcha_skills.cost/skill_range), 시즌 표시명(gatcha_seasons.name, S01=ARENA).
fox_coin: `GET /cards/{id}` 상세보기(스탯·스킬 배열·에디션·시즌명), 목록/상세에 V4 필드 노출.
csms: `PATCH /seasons/{code}/rarities/{rarity}` — **합성 성공률(upgradeSuccessBp) 운영 변경**, 디자인/스킬 V4 필드.

수정된 버그: `:param IS NULL` 42P08(명시 캐스트), insertDesign V4 파라미터 바인딩 누락, jsonb 파라미터는 JsonObject로 바인딩.

### e2e 검증 결과 (2026-07-16, 실계정 — 관리자 콘솔 + 유저 플로우)

| 시나리오 | 결과 |
|----------|------|
| 관리자 로그인 → overview (시즌/등급/디자인 70/스킬) | ✅ |
| **뽑기 확률 변경** (COM 72→71.9%) → 유저 /policy에 실반영 | ✅ (합계≠100% 거절도 확인) |
| **합성 성공률 변경** (COM 65→70%) → 실제 합성 판정에 70% 사용 | ✅ |
| 카드 추가 (목업 스탯 전체: cost2/atk5/hp5/mov2/rng1/Cat/Korion/SUPPORT) | ✅ design_no 자동채번 |
| 발행량 증량 2→4 (+감축 차단 트리거) | ✅ supply_audit 기록 |
| 직업군/스킬 등록 + 디자인 스킬 세트(슬롯 순서) | ✅ |
| 1연차: 1 KORI 차감, COMPLETED, 카드 발급 | ✅ |
| 멱등키 재요청: 동일 drawId, 추가 차감 없음 | ✅ |
| 10연차: 10 KORI, 10장 (COM5/MID4/ADV1) | ✅ |
| 등급별 보유 조회 + 카드 상세보기(스탯/에디션/시즌) | ✅ |
| 합성: COM 3장(서로 다른 디자인) → CONSUMED + MID 카드 발급 | ✅ |
| 사가 정합: draws 전부 COMPLETED, PENDING/CHARGED 잔류 0, 지갑 차감 2건·환불 0 | ✅ |
| 감사: rate_audit 4건(변경+원복), supply_audit, admin_activity_logs(CARD_*) | ✅ |
| 원상복구: 확률/성공률 원복, 테스트 카드 RETIRED | ✅ |

개선 메모: 뽑기 직후 응답의 cards에는 스탯 미포함(INSERT RETURNING 경로) — 목록/상세/멱등재조회엔 포함됨. 필요 시 발급 트랜잭션 말미에 조인 재조회로 통일.

## 2026-07-16 — 라우팅 페이지별 미개발 API 점검 + 프론트 실연동 (배포 완료)

점검 결과: 프론트 전 페이지가 더미/localStorage 기반이었고, 합성은 **클라이언트 랜덤 시뮬레이션**(서버 미호출)이었음.
백엔드 갭 2건 보완: GET /policy에 upgradePolicy(합성 확률표) 포함, 뽑기 직후 응답에도 스탯 포함(조인 재조회로 통일).

프론트 연동(fox_coin_frontend 5dc09ca2, deploy-docker.sh로 배포·라이브 확인):
- `cardGatchaApi` 신설(policy/open/upgrade/cards/detail — auth·디바이스 헤더 포함 apiClient 경유)
- 더미 기본값 false로 전환(명시적 VITE_CARD_GATCHA_USE_DUMMY_DATA=true 또는 전역 더미 모드에서만 더미)
- 보유 카드 = 서버 단일 진실(GET /cards), 뽑기 = POST /open(멱등키), 합성 = POST /upgrade(서버 판정)
- 확률표/합성표 = useGatchaPolicy 훅(서버 가변 확률, 로딩 전 정적 폴백), 랜딩 잔고 = 실 KORI 지갑
- 상세보기 = cardId 쿼리 기반 렌더(서버 카드), 합성 결과 화면 실모드 지원
- 스모크: 라이브에서 policy upgradePolicy steps 6종·확률 정상 응답 확인

## 다음 단계

1. 관리자 콘솔 카드 관리 화면(미개발) — csms API 계약은 확정
2. 카드 상세 화면에 스킬/스탯 표기 확장(GET /cards/{id}의 skills 활용)
3. 테스트 하니스 2-DB 전환(card_cloud 테스트 DB), postgres-exporter card-postgres 등록
4. (별도 이슈) DB 백업 S3 오프사이트 IAM 권한 복구 — AWS 콘솔 조치 대기

## 2026-07-17 — 관리자 콘솔 카드 관리 화면 (배포 완료)

프론트(fox_coin_frontend 7a12a0a9, 라이브 번들 index-Cs_ttjlU.js):
- `adminCardGatchaApi` 신설 — /api/v2/admin/card-gatcha/* 전체 계약(overview·카드추가·발행량·속성/스킬·확률세트·합성률·시즌·직업군/스킬)
- **카드 / 발행량 관리** (`/admin/card-gatcha/designs`): 시즌·등급 필터, 재고 진행바(발급/발행),
  발행량 증량(발급수 미만 감축 클라+서버 이중 차단), 인라인 속성/스킬 편집, 자동 채번 카드 추가,
  직업군/스킬 등록 섹션
- **확률 / 시즌 관리** (`/admin/card-gatcha/rates`): weight 세트 편집(합계 1,000,000 실시간 검증, 미달 시 저장 비활성),
  등급별 합성 성공률(% 입력 ↔ bp 저장), 시즌 생성/상태 전환(확인 다이얼로그)
- 사이드바(KORION Wallet 콘솔)에 '카드 가챠 관리' 그룹 추가

백엔드 보완(coin_csms cb3bdbc, 025156d):
- 시즌 생성 시 최신 시즌(ACTIVE 우선)의 등급 세트 복사 — 등급 없는 시즌은 구성 불가였던 갭
- listSkills가 이중 인코딩된 jsonb params(문자열 "{}")에도 500 없이 정규화해 읽도록 수정

데이터 보정: V5 마이그레이션(gatcha_skills.params 문자열→객체) 작성·푸시 — **서버 flyway migrate 실행은 대기**
(읽기 정규화로 증상은 해소, 실행은 운영자 승인 후).

엣지(korion.io.kr) 경유 스모크: 로그인→overview 200(시즌1/등급7/디자인71/직업군1/스킬2),
edition-size 4→5→4 왕복 200, editionSize=0 가드 400 정상.

## 2026-07-17 — 가챠 대시보드(KPI) + 유저 카드 관리 (배포 완료)

백엔드(coin_csms 75611bb):
- `GET /api/v2/admin/card-gatcha/kpi` — 매출/뽑기(완료·진행중·실패)/발급·보유·소모/보유 유저/합성 성공률,
  등급별 현황(발급·보유·소모·공급·잔여), 14일 일별 추이, ACTIVE 재고 임박 TOP5
- `GET /users` — 카드 보유 유저(보유량순, 페이지네이션). q가 숫자면 유저ID, 문자면 코인DB
  login_id/nickname/name 부분일치 검색. 코인DB 프로필(loginId/nickname/name) 병합.
- `GET /users/:userId/cards` — 유저 카드 전체(최근 200) + 최근 뽑기 10건

프론트(fox_coin_frontend 11f097b9): 사이드바 '카드 가챠 관리' 하위탭 4종 완성 —
가챠 대시보드(KPI 타일 6종 + 추이 바 + 등급별 + 재고 임박) / 유저 카드 관리(검색·등급 칩·행 펼침) /
카드·발행량 / 뽑기·합성 확률·시즌. 전부 --admin-* 테마 변수 기반(다크/라이트 대응).

엣지 스모크(실데이터): kpi 200(매출 11 KORI·뽑기 2·보유 9/소모 3·합성 1/1·미수렴 0),
users 200(1명, 프로필 병합 확인), user cards 200(12장+뽑기 2건), loginId 부분검색 200.

## 2026-07-17 — 테스트 계정 무과금 뽑기 (TEST 시즌, 배포 완료)

- fox_coin d8842724: `users.is_test=1` 계정은 뽑기 시 **KORI 차감/환불 없음**(cost 0 사가,
  charge_tx_ref "TEST-{drawId}") + **TEST 시즌**(DRAFT — 상용 노출 없음) 재고에서 발급.
  발급은 상용과 동일 경로(원자 카운터·확률 롤)라 재고가 실제 감소 → 가중치/소진 테스트 가능.
  합성·/policy도 테스트 계정이면 TEST 카탈로그. 보정배치는 드로우의 season_id로 카탈로그
  해석(catalogForSeasonId), cost 0 건은 지갑 없이 종결·환불 스킵.
- TEST 시즌 시드(admin API): 등급 7종 자동 복사(S01 가중치/합성률), 카드 14종(등급별 2종×500장).
  확률/발행량 변경은 admin 콘솔 시즌 셀렉터에서 TEST 선택.
- 테스트 계정 3개 지정(is_test=1): jang2020111@gmail.com, jyk860111@gmail.com, ansj110544@gmail.com
- 검증: 상용 유저 policy S01·비용 1 KORI·재고 무변화 확인. 테스트 계정 실뽑기 검증은
  해당 계정 로그인 필요(운영자 확인 대기).
