-- 넥스트스텝 v0.2 — 도메인 모델 DDL (H2/MySQL 호환 기준)

CREATE TABLE site (
    pnu             VARCHAR(19) PRIMARY KEY,     -- 법정동10 + 산여부1 + 본번4 + 부번4
    road_address    VARCHAR(200),
    jibun_address   VARCHAR(200) NOT NULL,
    longitude       DECIMAL(10,7),               -- nullable: 원본 좌표 미채움 대비
    latitude        DECIMAL(10,7),
    geocoded        BOOLEAN NOT NULL DEFAULT FALSE -- TRUE = 지오코딩 폴백으로 채움
);

-- unit: 자리(site) 안에서 분리된 개별 점포. D-U1 물건 분리 규칙(10-backend-spec.md 3.1)의
-- 산출물로, 확정 당시 이 파일에 반영이 누락되어 있었음 — unitId가 저장될 곳이 없으면
-- /api/units/{unitId} 계약 자체가 성립하지 않아 추가함.
CREATE TABLE unit (
    unit_id     VARCHAR(30) PRIMARY KEY,        -- {pnu}-U{seq}
    site_pnu    VARCHAR(19) NOT NULL REFERENCES site(pnu),
    label       VARCHAR(100) NOT NULL           -- 상세주소 원문 또는 "물건 A"/"단일 점포"
);

CREATE INDEX idx_unit_site ON unit(site_pnu);

CREATE TABLE tenancy_record (
    id                  BIGINT AUTO_INCREMENT PRIMARY KEY,
    unit_id             VARCHAR(30) NOT NULL REFERENCES unit(unit_id),
    business_name       VARCHAR(200) NOT NULL,
    category_code       VARCHAR(20),
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

-- 물건별 통계는 site_statistics와 동일하게 배치 집계 후 저장(조회 시 재계산 방지)
CREATE TABLE unit_statistics (
    unit_id                  VARCHAR(30) PRIMARY KEY REFERENCES unit(unit_id),
    total_tenancy_count      INT NOT NULL,
    closed_count             INT NOT NULL,
    average_survival_months  DECIMAL(6,1),
    longest_survival_months  INT,
    shortest_survival_months INT,
    calculated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 적재 이상치 로그 (P-3, P-4 제외 건 기록 — 발표용 "데이터 정직성" 근거)
CREATE TABLE ingestion_exclusion_log (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    raw_mgtno       VARCHAR(50),
    reason_code     VARCHAR(30) NOT NULL,   -- P3_DATE_ORDER | P4_PARSE_FAIL | P4_NO_COORD
    raw_snippet     VARCHAR(500),
    logged_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 자리별 통계는 배치 집계 후 별도 테이블에 적재(조회 시 재계산 방지)
CREATE TABLE site_statistics (
    site_pnu                VARCHAR(19) PRIMARY KEY REFERENCES site(pnu),
    closure_count            INT NOT NULL,
    average_survival_months  DECIMAL(6,1),
    longest_survival_months  INT,
    shortest_survival_months INT,
    calculated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 반경 동종 밀도 스냅샷(소진공 API 결과 캐시, 조회 시마다 외부 API 재호출 방지)
CREATE TABLE neighborhood_snapshot (
    site_pnu                    VARCHAR(19) PRIMARY KEY REFERENCES site(pnu),
    same_category_count_300m    INT,
    open_count_last_3y          INT,
    close_count_last_3y         INT,
    snapshot_at                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
