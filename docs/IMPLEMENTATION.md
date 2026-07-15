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

## 다음 단계

1. 서버 .env에 CARD_DB_* 추가 + docker-compose.prod.yml env 전달 + 롤링 배포(deploy.sh update)
2. 실배포 검증: /policy 확률 표시, 1/10연차, 잔고 차감/멱등키, 등급별 보유 조회, 사가 강제 실패 주입
3. coin_csms 관리자 API(카드 추가·발행량 증량·확률 변경·시즌 관리)
4. 백업·exporter·알람 등록, 테스트 하니스 2-DB 전환
