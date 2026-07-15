# 카드 가챠(Card Cloud) 별도 DB · 아키텍처 설계 v2

작성: 2026-07-16 (v2 — 호스트 선정·API 방향 확정, 관리자/확률가변/등급별 보유 요구 반영)
마이그레이션 리포: https://github.com/ansj1105/card_cloud_flyway.git

---

## 0. v2 변경 요약 (v1 대비)

| 항목 | 결정 |
|------|------|
| DB 위치 | **foxya 운영 호스트에 전용 postgres 컨테이너 `card-postgres`** — coin_system_cloud와 인스턴스 자체 분리 |
| 마이그레이션 | **card_cloud_flyway** 리포(V1 스키마 + V2 시즌시드), coin_system_flyway와 동일 gradle 컨벤션, lineage 완전 분리 |
| API 방향 | **fox_coin 내 cardgatcha 모듈 유지 + PgPool 2개** (판단 근거 §3.2) |
| 확률 | **가변 설정값** — DB 데이터 + 변경 감사 트리거 + 뽑기별 확률 스냅샷 |
| 관리자 | 카드(디자인) 추가, 발행량(edition_size) 증가, 확률 변경 — 전부 무배포 운영 작업 |
| 보유 조회 | 유저별 카드 **등급별 구분 보유** — rarity 비정규화 + `(user_id, rarity_code, status)` 인덱스 |

## 1. 호스트 선정

운영 호스트 4대의 RAM/디스크 실측 비교 결과 **foxya 운영 호스트**(가용 RAM·디스크 최대, fox_coin API와 동일 호스트)로 선정.
호스트별 실측 수치·IP 등 인프라 상세는 내부 운영 문서 참조(공개 리포에는 기재하지 않음).

- 같은 호스트 = 크로스호스트 DB 접속 문제(레이턴시/커넥션풀) 원천 회피.
- `card-postgres`는 **기존 코인 DB(foxya-postgres)와 별개 컨테이너/별개 데이터 디렉토리** — "cloud system에서 DB 분리" 요구 충족. 메모리 상한 1G, shared_buffers 256MB로 격리.
- 접근: 도커 네트워크 내부 `card-postgres:5432`, 호스트 로컬 `127.0.0.1:15433` (외부 비공개).

## 2. 요구사항 (확정)

1. `/card-gatcha/rates` 확률로 등급 결정 → 등급 내 카드 종류 랜덤 드랍.
2. 카드(디자인)별 총 발행량 고정 발행, 이중발급 불가. 등급/전체 소진 시 정책 동작.
3. **뽑기 확률은 고정 설정값이 아님** — 운영 중 변경 가능해야 하고, 언제 어떤 확률이었는지 증빙 가능해야 함.
4. **관리자 기능**: 카드 추가(신규 디자인 등록), 해당 카드의 발행량 추가(증량).
5. **유저별 카드를 등급별로 구분해 보유·조회** (마이카드 화면).
6. 합성(업그레이드): 동일 등급 3장(서로 다른 디자인) → 상위 등급 확률 합성, 기존 정책 유지.
7. DB는 coin_system_cloud(coin_system_flyway)와 완전 분리.

## 3. 아키텍처

### 3.1 구성도

```
[App/Web] ─ /api/card-gatcha/* ─> foxya-nginx ─> foxya-api(+api-2)   [fox_coin]
                                                    │            │
                                       PgPool #1    │            │  PgPool #2 (신규)
                                                    ▼            ▼
                                        coin_system_cloud     card_cloud
                                        (foxya-postgres)      (card-postgres, 신규 컨테이너)
                                        users/지갑/차감        시즌/확률/디자인/재고/뽑기/카드/합성
                                            └── 둘 다 동일 호스트, 도커 네트워크 내부 통신 ──┘
```

### 3.2 API 방향 판단: fox_coin 모듈 (MSA 아님) — 근거

1. 검증된 뽑기/합성 로직 1,225줄이 이미 fox_coin `cardgatcha` 모듈에 있음 — MSA로 가면 JWT 인증·지갑 차감·멱등 처리까지 전부 재구축.
2. 지갑 차감이 인프로세스(코인DB 풀 직접 사용) → 별도 서비스면 내부 API 호출 + 인증 신뢰쌍 + 장애 전파 경로가 하나 더 생김 (오프페에서 겪은 서비스간 JWT/서킷 문제 재생산).
3. 호스트 자원(2 vCPU) 상 신규 JVM 프로세스 추가 부담 > 이득.
4. **분리는 DB 계층에서 이미 확보** — 나중에 트래픽/조직이 커지면 `cardgatcha` 모듈 + card_cloud DB를 그대로 들어내 MSA로 승격 가능(코드·데이터 경계가 이미 그어져 있음).

### 3.3 크로스 DB 결제 사가 (선차감-후발급)

```
1. [card_cloud] idempotency_key 조회 → 기존 건 반환 (멱등)
2. [card_cloud tx] draws(PENDING, rate_snapshot 포함) 기록
3. [coin_system tx] KORI 차감 + wallet_transactions(ref=draw_id) → draws=CHARGED
   └ 실패(잔고부족) → draws=FAILED 종결
4. [card_cloud tx] 카드 발급(원자 재고할당 §5) + draws=COMPLETED
   └ 실패 → [coin_system] 환불 기록 → draws=COMPENSATED
5. 보정 배치(1분 주기): PENDING/CHARGED 5분 초과 →
   코인DB에서 draw_id 차감 확인 → 있으면 발급 재수행, 없으면 FAILED. 알람 발송.
```

- 어느 시점에 죽어도: "돈만 나감"은 배치가 발급/환불로 자동 수렴, "카드 공짜 발급"은 구조적으로 불가(차감 확인 후에만 발급).

## 4. DB 스키마 (card_cloud, Flyway V1/V2 — 리포에 작성 완료)

핵심 테이블 (전체 DDL은 `card_cloud_flyway/src/main/resources/db/migration/V1__...sql`):

| 테이블 | 역할 | 포인트 |
|--------|------|--------|
| `gatcha_seasons` | 시즌(비용·소진정책) | draw_cost, exhaustion_policy |
| `gatcha_rarities` | 등급 + **확률(weight)** | 1,000,000 기준. **운영 중 UPDATE 가능** |
| `gatcha_rate_audit` | 확률 변경 이력 | **트리거 자동기록** (수동 SQL 변경도 포착) |
| `gatcha_designs` | 카드 종류 + 재고 카운터 | `edition_size`(발행량), `issued_count`(발급수) 일체형 |
| `gatcha_supply_audit` | 발행량 변경 이력 | 트리거 자동기록 + **발급수 미만 감축 금지 가드** |
| `gatcha_draws` | 뽑기 원장(사가 상태) | `rate_snapshot JSONB` — 뽑기 시점 확률표 증빙 |
| `gatcha_cards` | 발급 카드 실물 | `UNIQUE(design_id, serial_no)` 이중발급 차단, rarity 비정규화 + `(user_id, rarity_code, status)` 인덱스로 **등급별 보유 조회** |
| `gatcha_upgrades` / `gatcha_upgrade_attempts` | 합성 원장 | 기존 V146 구조 이관 |

- user_id는 FK 없는 BIGINT (코인DB users 소유 — DB 분리의 대가, JWT userId로 앱 레이어 보장).
- V2 시드: S01 시즌 = 등급 7종(COM 72% ~ MYT 0.001%) × 디자인 10종 × 에디션 500장 = 35,000장.

## 5. 뽑기 알고리즘

```
1) 등급 롤: 잔여>0 등급만 대상으로 weight 비례 랜덤 (SecureRandom)
   — weight는 매 뽑기마다 DB에서 읽음(TTL 캐시 ≤60s): 확률 변경 즉시 반영
2) 디자인 롤: 등급 내 잔여수량 가중 랜덤
3) 시리얼 원자 할당(경합 무락 해결):
   UPDATE gatcha_designs SET issued_count = issued_count + 1
    WHERE design_id = :d AND issued_count < edition_size
    RETURNING issued_count;      -- 반환값 = serial_no
   0 row(그 사이 소진) → 2)로 재롤(해당 디자인 제외), 등급 소진 → 1) 재롤
4) gatcha_cards INSERT — UNIQUE(design_id, serial_no) 최후 방어
* 10연차 = 3)~4) 같은 트랜잭션 10회, 전부 성공 or 전부 롤백
```

## 6. 재고 소진 정책 (시즌 설정)

| 정책 | 동작 |
|------|------|
| **EXCLUDE_RENORMALIZE** (기본) | 소진 등급 제외 후 잔여 등급 가중치 재정규화. rates 화면에 "품절" 뱃지 + 실효확률 표기 |
| SPILL_DOWN | 소진 등급 당첨 시 하위 등급 대체 지급 |
| FAIL_AND_REFUND | 전 등급 소진 시 뽑기 차단(`SEASON_SOLD_OUT`), 경합 통과분은 사가 환불 |

- 등급 잔여 0 도달 → 텔레그램 알람. 단, **관리자가 발행량 증량하면 자동으로 다시 뽑기 대상에 포함**됨(카운터 기반이라 별도 상태 전환 불필요).

## 7. 관리자 기능 설계 (coin_csms 경유, `/api/v2/admin/card-gatcha/*`)

| 기능 | 동작 | 안전장치 |
|------|------|----------|
| 카드 추가 | `gatcha_designs` INSERT (등급·이름·발행량·이미지) | design_no 등급 내 유니크, DRAFT/ACTIVE 시즌 모두 허용 |
| 발행량 추가 | `edition_size` 증가 UPDATE | 트리거: 발급수 미만 감축 시 예외 + supply_audit 자동기록 |
| 확률 변경 | `gatcha_rarities.weight` UPDATE | rate_audit 자동기록, 합계 1,000,000 검증은 앱 레이어, 뽑기는 rate_snapshot으로 증빙 |
| 시즌 관리 | 시즌 생성/ACTIVE/CLOSED | CLOSED 시즌은 뽑기 차단, 보유 카드는 유지 |

- csms 관리자 지급 감사로그(c438f15)와 동일하게, 관리자 API 호출 자체도 앱 감사로그 남김(누가·언제·왜). DB 트리거 감사는 그 아래의 최후 방어선.

## 8. 구현 워크플랜 (markdown 기반 진행)

- [x] 설계 문서 (본 문서)
- [x] card_cloud_flyway 리포: gradle 스캐폴드 + V1 스키마 + V2 S01 시드
- [ ] foxya 호스트: card-postgres 컨테이너 구축(compose, mem 1G 상한, 127.0.0.1:15433) + role/db 생성
- [ ] flyway migrate 실행 → 스키마/시드 검증
- [ ] fox_coin: PgPool #2(card_cloud) 설정 + cardgatcha 리포지토리 신규 DB 전환
- [ ] fox_coin: 하드코딩 Rarity/CardTemplate enum → DB 조회(TTL 캐시) 교체
- [ ] fox_coin: 선차감-후발급 사가 + 보정 배치 + PENDING 알람
- [ ] fox_coin: 마이카드 등급별 조회 API (denorm 인덱스 활용)
- [ ] coin_csms: 관리자 API(카드 추가/발행량 증량/확률 변경/시즌)
- [ ] 기존 V146 데이터 이관 스크립트 + coin_system_cloud 테이블 정리(보존→제거)
- [ ] 백업(foxya-db-backup.sh에 card_cloud 추가) + postgres-exporter 등록 + Grafana/알람
- [ ] 부하·경합·소진·사가 크래시 검증 후 오픈

## 9. 운영 체크리스트

- [ ] `PENDING > 5분` draw 알람 (사가 미수렴)
- [ ] 등급 잔여 0 알람 / 증량 후 자동 재개 확인
- [ ] rates 화면: DB 확률 실시간 + 품절/실효확률 표기
- [ ] card-postgres 메모리 상한·백업·복제(추후) 점검
