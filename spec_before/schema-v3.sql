-- 넥스트스텝 v3 DDL (H2/PostgreSQL 호환 기준)
-- v2 대비 변경: neighborhood_snapshot(site-level) 폐기 → tenancy_market_info(이력 단위) +
-- site_radius_store_cache로 대체. marketInfo 위치가 건물상세(②)에서 물건상세(③)로 이전됨.
-- v1(schema.sql) 대비 변경: Unit 계층 신설(Site 1—N Unit 1—N Tenancy),
-- 상권 보강 필드(industry_detail, location_source, enrichment_source) 추가,
-- neighborhood_snapshot을 api-spec-v2.md 필드에 맞춰 재설계.

CREATE TABLE site (
    pnu             VARCHAR(19) PRIMARY KEY,     -- 법정동10 + 산여부1 + 본번4 + 부번4
    road_address    VARCHAR(200),
    jibun_address   VARCHAR(200) NOT NULL,
    longitude       DECIMAL(10,7),               -- nullable: 원본 좌표 미채움 대비
    latitude        DECIMAL(10,7),
    geocoded        BOOLEAN NOT NULL DEFAULT FALSE -- TRUE = 지오코딩 폴백으로 채움
);

-- 물건(Unit): D-1 확정 규칙으로 분리된 개별 점포 단위.
CREATE TABLE unit (
    unit_id         VARCHAR(40) PRIMARY KEY,     -- {pnu}-U{seq}
    site_pnu        VARCHAR(19) NOT NULL REFERENCES site(pnu),
    label           VARCHAR(50) NOT NULL,        -- 상세주소 있으면 그 값 / 물건 A / 단일 점포
    location_source VARCHAR(20) NOT NULL DEFAULT 'overlap_inferred'
                    -- license | sangga_api | overlap_inferred
);

CREATE INDEX idx_unit_site ON unit(site_pnu);

CREATE TABLE tenancy_record (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    unit_id             VARCHAR(40) NOT NULL REFERENCES unit(unit_id),
    business_name       VARCHAR(200) NOT NULL,
    category            VARCHAR(100),             -- 인허가 원본 업종명
    industry_detail     VARCHAR(100) NULL,         -- 상가API 세부업종(indsSclsNm). 폐업 이력은 원천적으로 NULL
    enrichment_source   VARCHAR(20) NOT NULL DEFAULT 'license_only', -- sangga_api | license_only
    licensed_at         DATE NOT NULL,
    closed_at           DATE NULL,                -- NULL = 영업중
    status              VARCHAR(10) NOT NULL,      -- 영업 | 폐업 | 휴업
    closed_at_estimated BOOLEAN NOT NULL DEFAULT FALSE, -- P-2: 원본 폐업일자 빈값 → 대체값 사용 플래그
    survival_months     INT NULL,                  -- 배치 계산 파생값 (영업중이면 NULL, 조회 시 실시간 계산)
    source_updated_at   TIMESTAMP,                  -- 원본 데이터갱신일자(updatedt)
    CONSTRAINT chk_date_order CHECK (closed_at IS NULL OR closed_at >= licensed_at) -- P-3 방어
);

CREATE INDEX idx_tenancy_unit ON tenancy_record(unit_id);
CREATE INDEX idx_tenancy_status ON tenancy_record(status);

-- 적재 이상치 로그 (P-3, P-4 제외 건 기록 — 발표용 "데이터 정직성" 근거)
CREATE TABLE ingestion_exclusion_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    raw_mgtno       VARCHAR(50),
    reason_code     VARCHAR(30) NOT NULL,   -- P3_DATE_ORDER | P4_PARSE_FAIL | P4_NO_COORD
    raw_snippet     VARCHAR(500),
    logged_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 물건별 통계는 배치 집계 후 별도 테이블에 적재(조회 시 재계산 방지)
CREATE TABLE unit_statistics (
    unit_id                   VARCHAR(40) PRIMARY KEY REFERENCES unit(unit_id),
    total_tenancy_count       INT NOT NULL,
    closed_count              INT NOT NULL,
    average_survival_months   DECIMAL(6,1),
    longest_survival_months   INT,
    shortest_survival_months  INT,
    calculated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- v3 정정: neighborhood_snapshot(site-level)은 폐기. 실제 화면은 물건 상세(③)의
-- 이력별 "계약·주변상권 정보" 카드였음이 스크린샷으로 확인됨. 아래 두 테이블로 대체.

-- sameCategoryNearbyCount 산출용 원자료 캐시(자리 단위, 반경조회 결과 리스트를 통째로
-- 저장해두고 물건별로 업종만 다르게 필터링 — 반경조회를 물건마다 반복 호출하지 않기 위함).
CREATE TABLE site_radius_store_cache (
    site_pnu            VARCHAR(19) NOT NULL REFERENCES site(pnu),
    industry_scls_name  VARCHAR(100) NOT NULL,  -- 상가API indsSclsNm
    fetched_at          DATE NOT NULL
);

CREATE INDEX idx_radius_cache_site ON site_radius_store_cache(site_pnu);

-- marketInfo — Tenancy(이력) 1건당 1행. sameCategoryNearbyCount만 실값 시도,
-- 나머지 5필드는 상수/목업. is_placeholder는 현재 항상 TRUE.
CREATE TABLE tenancy_market_info (
    tenancy_id                  BIGINT PRIMARY KEY REFERENCES tenancy_record(id),
    is_placeholder               BOOLEAN NOT NULL DEFAULT TRUE,
    lease_area_sqm                DECIMAL(6,1),   -- 목업
    deposit_krw                   BIGINT,          -- 목업
    monthly_rent_krw              BIGINT,          -- 목업
    key_money_krw                 BIGINT,          -- 목업
    daily_floating_population     INT,             -- 목업
    same_category_nearby_count    INT,             -- 실값(반경조회), 실패 시 NULL
    vacancy_rate_percent          DECIMAL(4,1),    -- 목업
    as_of                         DATE NOT NULL
);

