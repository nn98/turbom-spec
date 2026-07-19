-- 넥스트스텝 v5 DDL (PostgreSQL / H2 호환)
-- 실제 데이터셋(gyeonggi_seongnam_licensed_10y_address_units, 19컬럼) 확정 반영.
-- v4 대비: 가정이 아니라 실제 CSV 컬럼으로 매핑 확정.
--   - PNU 100% 채움 확인 → 직접 사용
--   - 폐업일자 실컬럼 확인 → closed_at 실값
--   - 업종명 전부 공백 확인 → 제거. 대분류/소분류 컬럼 분리(원본 행안부_대분류_소분류 구조)
--     category=대분류(타임라인 표시), sub_category=소분류(상세 표시), industryDetail=상가API 세부(우선)
--   - 주소분리여부 신뢰 불가(호수 있어도 false) 확인 → 대부분 자리=물건 1:1
--   - 주소보정성공여부로 마스킹/보정실패 레코드 품질 관리
-- 상권 정보는 DB 없음(실시간 API + 인메모리 캐시). v4 원칙 유지.

-- ============================================================
-- 개폐업 정보 (DB 영속화 — 정제 적재됨, 이 백엔드는 조회만)
-- ============================================================

CREATE TABLE site (
    pnu               VARCHAR(19) PRIMARY KEY,   -- CSV: PNU (100% 채움 확인)
    jibun_address     VARCHAR(200) NOT NULL,     -- CSV: 지번주소
    road_address      VARCHAR(200),              -- CSV: 도로명주소
    longitude         DECIMAL(10,7),             -- CSV: 원본좌표X → WGS84 변환 후 저장
    latitude          DECIMAL(10,7),             -- CSV: 원본좌표Y → WGS84 변환 후 저장
    original_x        DECIMAL(18,9),             -- 원본 투영좌표 보존(변환 검증용)
    original_y        DECIMAL(18,9),
    address_corrected BOOLEAN,                    -- CSV: 주소보정성공여부 (마스킹 품질 지표)
    local_gov_code    VARCHAR(10)                -- CSV: 개방자치단체코드
);

CREATE INDEX idx_site_jibun ON site(jibun_address);

-- 물건(Unit). 이 데이터셋은 주소분리여부가 대부분 false라 자리=물건 1:1이 기본.
-- 한 PNU에 여러 Tenancy가 시간순으로 쌓이는 게 정상(연대기의 핵심).
CREATE TABLE unit (
    unit_id         VARCHAR(40) PRIMARY KEY,     -- {pnu}-U{seq}, 미분리 시 {pnu}-U1
    site_pnu        VARCHAR(19) NOT NULL REFERENCES site(pnu),
    label           VARCHAR(80) NOT NULL,        -- 호수 분리 시 그 값, 기본 '단일 점포'
    location_source VARCHAR(20) NOT NULL DEFAULT 'license'
                    -- license | sangga_api | overlap_inferred
);

CREATE INDEX idx_unit_site ON unit(site_pnu);

-- 이력(Tenancy). 한 물건에 시간순으로 들어온 각 사업장 = 연대기의 각 칸.
CREATE TABLE tenancy_record (
    id              BIGINT PRIMARY KEY,          -- CSV: id (원본 유지)
    unit_id         VARCHAR(40) NOT NULL REFERENCES unit(unit_id),
    license_no      VARCHAR(50),                 -- CSV: 관리번호
    business_name   VARCHAR(200) NOT NULL,       -- CSV: 사업장명
    category        VARCHAR(50) NOT NULL,        -- CSV: 대분류 (예: 동물, 음식)
    sub_category    VARCHAR(50) NOT NULL,        -- CSV: 소분류 (예: 동물미용업, 일반음식점)
    licensed_at     DATE NOT NULL,               -- CSV: 인허가일자
    closed_at       DATE NULL,                   -- CSV: 폐업일자 (공백=영업중)
    status          VARCHAR(10) NOT NULL,        -- CSV: 영업상태 → {영업,폐업,휴업} 정규화
    status_detail   VARCHAR(30),                 -- CSV: 상세영업상태
    CONSTRAINT chk_date_order CHECK (closed_at IS NULL OR closed_at >= licensed_at)
);

CREATE INDEX idx_tenancy_unit ON tenancy_record(unit_id);
CREATE INDEX idx_tenancy_status ON tenancy_record(status);
CREATE INDEX idx_tenancy_licensed ON tenancy_record(licensed_at);

-- 적재 이상치 로그 (마스킹/보정실패/좌표변환실패 기록 — 데이터 정직성 근거).
-- 적재 자체는 이 백엔드 밖(배치)이나 로그 조회·리포트용으로 스키마에 둠.
CREATE TABLE ingestion_exclusion_log (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_id    BIGINT,                         -- 원본 tenancy id
    reason_code  VARCHAR(40) NOT NULL,
        -- ADDRESS_MASKED | ADDRESS_CORRECT_FAIL | PNU_INVALID | COORD_CONVERT_FAIL | DATE_ORDER
    raw_snippet  VARCHAR(500),
    logged_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 통계는 조회 시 계산(자리당 이력 수십 건 이하 예상). 성능 이슈 시에만 아래 활성화.
-- CREATE TABLE unit_statistics ( ... );

-- ============================================================
-- 상권 정보: DB 테이블 없음. 실시간 외부 API(소상공인 상가정보) + 인메모리 캐시(Caffeine TTL).
-- 개폐업(DB, 느린 데이터)과 상권(API, 실시간)의 시간 특성 분리 원칙(backend-spec.md 1장).
-- ============================================================
