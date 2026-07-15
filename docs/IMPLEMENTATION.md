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

## 다음 단계

1. 실사용 검증: 관리자 콘솔에서 overview/카드추가/확률변경, 실계정으로 1/10연차·멱등키·등급별 보유·소진/사가 시나리오
2. 테스트 하니스 2-DB 전환(card_cloud 테스트 DB), postgres-exporter card-postgres 등록
3. 관리자 콘솔 프론트(fox_coin_frontend admin 페이지) 연동
4. (별도 이슈) DB 백업 S3 오프사이트 IAM 권한 복구 — 7/10부터 실패 중 / csms 파일 로그 권한
