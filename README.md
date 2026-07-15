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
```

핵심 원칙:

- 확률(`gatcha_rarities.weight`)·발행량(`gatcha_designs.edition_size`)은 **가변 운영 데이터** — 변경은 DB 트리거가 감사 테이블(`gatcha_rate_audit`, `gatcha_supply_audit`)에 자동 기록
- 재고/시리얼은 `UPDATE ... SET issued_count = issued_count + 1 WHERE issued_count < edition_size RETURNING` 원자 할당 (락 없음)
- 이중발급은 `UNIQUE(design_id, serial_no)`가 최후 방어
- 뽑기마다 `rate_snapshot`(당시 확률표) 저장 — 확률 변경 이후에도 과거 뽑기 증빙 가능
- 발행량은 발급수 미만으로 감축 불가 (트리거 가드)

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
