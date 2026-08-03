# Card Cloud Flyway Migration

카드 가챠(Card Gatcha) 전용 데이터베이스 `card_cloud`의 Flyway 마이그레이션 프로젝트입니다.
**coin_system_flyway(coin_system_cloud)와 완전히 분리된 lineage**를 가집니다.

- 설계 문서: [docs/DESIGN.md](docs/DESIGN.md) — 아키텍처·스키마·사가·운영 계획의 단일 기준 (markdown 기반 개발)
- 대상 DB: foxya 운영 호스트의 전용 컨테이너 `card-postgres` (기존 foxya-postgres와 별개)
- 접근: 도커 네트워크 내부 `card-postgres:5432`, 호스트 로컬 `127.0.0.1:15433` (외부 비공개)

## 마이그레이션

```
V1__20260716_Create_card_cloud_schema.sql   # 스키마 (시즌/등급·확률/디자인·재고/뽑기/카드/합성 + 감사 트리거)
V2__20260716_Seed_season_s01.sql            # S01 시드 (등급 7종 × 디자인 10종 × 에디션 500 = 35,000장)
V8__20260720_Normalize_card_serial_codes.sql # 카드 식별 정책: KORIS001COM0001 형식으로 design_id/card_code 정규화
V9__20260720_Add_design_passive_text.sql     # 카드 표면용 패시브 문구
V11__20260728_Add_gatcha_card_case_id.sql    # NFC 발행용 개별 카드 케이스 ID
V12__20260728_Normalize_card_design_ids_to_four_digit_season.sql # 시즌 4자리 카드 ID: KORIS0001COM0001
```

롤백 SQL은 `src/main/resources/db/rollback/`에 같은 버전명으로 둔다.

핵심 원칙:

- 확률(`gatcha_rarities.weight`)·발행량(`gatcha_designs.edition_size`)은 **가변 운영 데이터** — 변경은 DB 트리거가 감사 테이블(`gatcha_rate_audit`, `gatcha_supply_audit`)에 자동 기록
- `issued_count`는 신규 시리얼의 누적 고수위 값이며, 현재 재고는 `OWNED`/`LOCKED`/`BURNED` 카드의 점유 수로 계산
- 합성으로 `CONSUMED`된 비민팅 카드는 감사 이력을 보존하면서 동일 디자인/시리얼 재고로 즉시 반환
- 시리얼 할당은 디자인 행 잠금 후 반환 시리얼을 우선 재사용하고, 없으면 `issued_count` 다음 값을 배정
- 이중발급은 활성 카드에만 적용되는 부분 UNIQUE 인덱스 `(design_id, serial_no)`와 `case_id`가 최후 방어
- 뽑기마다 `rate_snapshot`(당시 확률표) 저장 — 확률 변경 이후에도 과거 뽑기 증빙 가능
- 발행량은 발급수 미만으로 감축 불가 (트리거 가드)
- 카드 식별자는 `<KORION prefix><season><rarity><design number>` 형식이다. 예: `KORIS0001COM0001`.
- `gatcha_cards.card_code`는 카드 디자인 식별자와 동일하게 저장한다. 개별 발급 번호는 `serial_no`가 소유하고, 이중발급 방어는 현재 점유 상태에 대한 부분 UNIQUE 인덱스 `(design_id, serial_no)`가 담당한다.
- NFC 발행용 개별 카드 식별자는 `gatcha_cards.case_id`가 담당한다. 기본 형식은 `CASE-<design_id>-<serial_no 6자리>`이며 현재 점유 상태에서 UNIQUE다.

## 실행

```bash
# 운영 서버에서 flyway 컨테이너로 실행 (권장)
sudo docker run --rm --network coin-shared \
  -v /var/www/card_cloud_flyway/src/main/resources/db/migration:/flyway/sql:ro \
  --env-file /var/www/card_cloud/.env.flyway \
  flyway/flyway:10-alpine migrate

# 또는 로컬에서 SSH 터널 후 gradle wrapper
ssh -L 15433:127.0.0.1:15433 <운영호스트> -N &
DB_PASSWORD=... ./gradlew flywayMigrate
```

`gradle.properties` 기본값: `127.0.0.1:15433 / card_cloud / card_cloud` (비밀번호는 env로만 주입)
