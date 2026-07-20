-- 넥스트스텝 v6 DDL — 실제 구현과 일치하는 캐노니컬 스키마 (2026-07-20 정정)
--
-- v5(정규화 3테이블: site/unit/tenancy_record)는 스펙 작성 단계의 설계였고, 실제 구현은
-- 단일 플랫 테이블(licensed_business_record) + 조회 시점 도메인 조립(Site/Unit/Tenancy는
-- turbom-server의 애플리케이션 계층이 이 테이블에서 매번 계산)으로 갔다 — 주소분리여부를
-- 신뢰할 수 없어 DB 레벨로 물건을 미리 쪼개봐야 의미가 없었고(backend-spec.md §3.1),
-- CSV 원본을 그대로 적재하면 별도 ETL 없이 시딩이 끝나기 때문(YAGNI). 이 간극은 실제로
-- 언제 갈라졌는지 이력이 남아있지 않다(turbom-server 클론이 얕은 클론이라 커밋 이력 확인
-- 불가) — `의사결정-기록.md` §12 참고. 이 파일은 이제부터 실제 배포 스키마
-- (turbom-server의 src/main/resources/schema.sql, scripts/mysql/mysql-schema.sql)를 그대로 따른다.
--
-- Site/Unit/Tenancy는 DB 테이블이 아니라 도메인 계층 개념이다 — 상세: backend-spec.md §3.
-- 이 테이블 하나가 Tenancy 각 행(=인허가 1건)에 대응하고, Site는 pnu로, Unit은 조회 시점에
-- 상세주소 파싱 결과로 그룹핑된다.

DROP TABLE IF EXISTS auction_schedule_entry;
DROP TABLE IF EXISTS auction_case;
DROP TABLE IF EXISTS licensed_business_record;

CREATE TABLE licensed_business_record (
    id                     BIGINT PRIMARY KEY,          -- CSV: id(원본 유지)
    pnu                    VARCHAR(19) NOT NULL,         -- CSV: PNU(100% 채움, 유도 불필요) = Site 키
    category               VARCHAR(50) NOT NULL,         -- CSV: 대분류(예: 동물)
    sub_category           VARCHAR(50) NOT NULL,         -- CSV: 소분류(예: 동물미용업)
    license_no             VARCHAR(50) NOT NULL,         -- CSV: 관리번호
    business_name          VARCHAR(200) NOT NULL,        -- CSV: 사업장명
    business_type          VARCHAR(100),                 -- CSV: 업태명
    business_status        VARCHAR(20) NOT NULL,         -- CSV: 영업상태명(5버킷 원문)
    status_detail_code     VARCHAR(10),                  -- CSV: 상세영업상태코드
    status_detail          VARCHAR(30),                  -- CSV: 상세영업상태명
    licensed_at            DATE NOT NULL,                 -- CSV: 인허가일자
    closed_at              DATE,                          -- CSV: 폐업일자(공백=영업중)
    road_address           VARCHAR(300),                  -- CSV: 도로명주소
    jibun_address          VARCHAR(300) NOT NULL,         -- CSV: 지번주소
    address_separated      BOOLEAN NOT NULL,              -- CSV: 주소분리여부(실측상 거의 항상 false)
    address_corrected      BOOLEAN,                       -- CSV: 주소보정성공여부(마스킹 품질 지표)
    parsed_building_name   VARCHAR(200),                  -- 조회 시점 아님, 적재 시 AddressDetailParser로 파싱
    parsed_floor           VARCHAR(20),
    parsed_unit_no         VARCHAR(20),
    parse_confidence       VARCHAR(10),                   -- HIGH | LOW
    parse_method           VARCHAR(20),                   -- REGEX | UNPARSED | NONE
    local_gov_code         VARCHAR(10) NOT NULL,          -- CSV: 개방자치단체코드
    original_x             DECIMAL(18,9),                 -- CSV: 원본좌표X(EPSG:5174) — WGS84 변환은 조회 시점(infra)
    original_y             DECIMAL(18,9),                 -- CSV: 원본좌표Y(EPSG:5174)
    CONSTRAINT chk_license_date_order CHECK (closed_at IS NULL OR closed_at >= licensed_at)
);

CREATE INDEX idx_license_record_pnu ON licensed_business_record(pnu);
CREATE INDEX idx_license_record_jibun ON licensed_business_record(jibun_address);
CREATE INDEX idx_license_record_road ON licensed_business_record(road_address);
CREATE INDEX idx_license_record_status ON licensed_business_record(business_status);
CREATE INDEX idx_license_record_licensed ON licensed_business_record(licensed_at);

-- ============================================================
-- 아래 두 테이블은 공개 API 계약(api-spec.md)과 무관한 실험적/비공개 파이프라인이다.
-- 법원경매 데이터 수집 스파이크용 — 상세: backend-spec.md §11, 의사결정-기록.md §8.
-- 자동 적재 경로가 없어 프로덕션에서도 항상 빈 테이블일 수 있다.
-- ============================================================

CREATE TABLE auction_case (
    id                         BIGINT PRIMARY KEY AUTO_INCREMENT,
    case_number                VARCHAR(50) NOT NULL,
    item_number                INT NOT NULL,
    court                      VARCHAR(100),
    division_name              VARCHAR(100),
    property_type              VARCHAR(100),
    jibun_address              VARCHAR(300),
    appraisal_value_krw        DECIMAL(19,0),
    minimum_sale_price_krw     DECIMAL(19,0),
    bid_deposit_krw            DECIMAL(19,0),
    bidding_method             VARCHAR(50),
    sale_date                  VARCHAR(20),
    filed_date                 VARCHAR(20),
    auction_start_date         VARCHAR(20),
    claim_deadline             VARCHAR(20),
    claim_amount_krw           DECIMAL(19,0),
    appraisal_summary          VARCHAR(4000)
);

CREATE TABLE auction_schedule_entry (
    id                         BIGINT PRIMARY KEY AUTO_INCREMENT,
    auction_case_id            BIGINT NOT NULL REFERENCES auction_case(id),
    schedule_date               VARCHAR(20),
    schedule_time               VARCHAR(20),
    schedule_type                VARCHAR(100),
    location                    VARCHAR(300),
    minimum_price_krw           DECIMAL(19,0),
    result                      VARCHAR(100)
);

-- ============================================================
-- 상권 정보: DB 테이블 없음. 실시간 외부 API(소상공인 상가정보) + 인메모리 캐시(Caffeine TTL).
-- 개폐업(DB, 느린 데이터)과 상권(API, 실시간)의 시간 특성 분리 원칙(backend-spec.md 1장).
-- ============================================================
