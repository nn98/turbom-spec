# 넥스트스텝 백엔드 명세 (Claude Code용)

이 문서 하나로 백엔드를 독립 구현한다. 상위 계약은 `00-api-contract-v1.md`이며 응답 형태는 그 문서가 최종 기준이다. 프론트와 무관하게 이 문서만으로 완결되게 작성했다.

## 0. 목표

성남 수정구 일대의 음식점 인허가 공공데이터를 적재·정제하여, 지번(자리)–물건–가게이력 계층으로 조회하는 REST API 3종을 제공한다. 해커톤 MVP.

## 1. 스택 · 배포

- Java 17, Spring Boot 3.x
- Spring Web, Spring Data JPA
- DB: 로컬 H2(파일 모드) → 운영 Railway PostgreSQL
- 빌드: Gradle
- 배포: Railway(`Dockerfile` 또는 Nixpacks). 필요 시 EC2 폴백
- 형상: 단일 모듈. 패키지 `com.nextstep`

## 2. 아키텍처 (레이어)

```
web        Controller, 요청/응답 DTO, 예외 핸들러
application Service (조회 유스케이스, 통계 조립)
domain     Site, Unit, Tenancy, 값 객체, 통계 계산 로직
infra      JPA 엔티티·리포지토리, 인허가 적재 파이프라인
```

의존 방향 web → application → domain ← infra. domain은 프레임워크 비의존.

## 3. 도메인 모델

### 3.1 식별자

- `pnu`(자리): 지번주소에서 유도. 법정동코드(10) + 산여부(1) + 본번(4) + 부번(4) = 19자리.
- `unitId`(물건): `{pnu}-U{seq}` 문자열. seq는 자리 내 물건 분리 순번(4.4 규칙으로 결정).

### 물건 분리 규칙 (D-U1 확정)

인허가 raw에 층/호 컬럼은 없지만, **같은 지번주소 접두사로 조회되는 레코드 전체를 한 자리로 모은 뒤 그 안에서 물건을 가른다.** 접근:

1. 그룹핑 키 = 지번주소에서 건물명 꼬리를 제거한 정규화 주소(= PNU). 이 접두사로 자리 내 전체 인허가 레코드를 수집.
2. 자리 내에서 **영업 기간이 겹치는(동시 존재) 서로 다른 상호는 별개 물건**으로 본다. 물리적으로 같은 칸이면 동시에 두 가게가 영업할 수 없다는 전제.
3. **영업 기간이 겹치지 않고 시간순으로 이어지는 레코드는 같은 물건에 순차 입점**한 것으로 본다(= 한 물건의 히스토리).
4. 겹침 판정은 구간 겹침(interval overlap): [licensedAt, closedAt|today] 이 다른 레코드 구간과 교차하면 별개 물건 후보.
5. 원본에 상세주소(지번 뒤 "○○호", "지하1층" 등 텍스트)가 존재하는 레코드는 그 문자열을 우선 물건 식별자로 사용하고, label에 그대로 노출. 없으면 4의 겹침 기반 분리 + `물건 A/B/C` 라벨.

> 요지: 층/호가 명시된 물건은 그 값으로 분리(사용자 지적대로 존재하는 건 다 명시됨), 명시 안 된 잔여는 시간 겹침으로 분리. "무조건 1자리=1물건" 단순화는 폐기.
>
> 리스크: 접두사가 같아도 실제로는 다른 물건인데 시간상 안 겹쳐 한 물건으로 합쳐질 수 있음(과합침) — MVP 허용 오차로 두고 한계 고지에 포함. 반대 방향(과분리)은 label로 사용자가 판단 가능.

### 3.2 엔티티

- Site(pnu PK, jibunAddress, roadAddress, latitude, longitude, geocoded)
- Unit(unitId PK, sitePnu FK, label)
- Tenancy(id PK, unitId FK, businessName, category, licensedAt, closedAt, status, closedAtEstimated, sourceUpdatedAt)

파생(저장 or 조회 계산):
- UnitStatistics(unitId PK, totalTenancyCount, closedCount, averageSurvivalMonths, longestSurvivalMonths, shortestSurvivalMonths)

DDL은 `schema.sql` 참조(별도 산출물, 이 계층 반영본).

## 4. 데이터 적재 파이프라인 (핵심, 사전 작업 가능)

입력: localdata 일반음식점/휴게음식점 인허가 파일(csv 또는 json). 성남 수정구로 필터.

### 4.1 단계

1. Load: 파일 파싱. 인코딩 EUC-KR 가능성 → UTF-8 변환.
2. Filter: 소재지지번주소가 성남시 수정구인 행만.
3. Parse: 지번주소 → (시/구/동/본번-부번) 정규식 추출 → 법정동코드 매핑 → PNU 생성.
4. Clean: 아래 정제 규칙.
5. Group: PNU 접두사로 자리 내 전체 레코드 수집 → Site 생성.
6. Split: 물건 분리 규칙(3.1)으로 자리 내 레코드를 Unit들로 가름 → 각 레코드를 해당 Unit의 Tenancy로.
7. Stat: Unit별 통계 배치 계산.
8. Persist: 저장. 제외 건은 로그 테이블.

### 4.2 정제 규칙

- P-1 영업상태명 → `{영업, 폐업, 휴업}` 정규화. 그 외 제외.
- P-2 폐업일자(dcbymd)는 **공백 패딩** 저장됨 → `trim()` 후 빈 문자열이면 null. status=폐업인데 null → 데이터갱신일자(updatedt)로 대체하고 `closedAtEstimated=true`.
- P-3 closedAt < licensedAt → 해당 이력 제외 + 로그.
- P-4 지번주소 파싱 실패 → 좌표로 폴백 매칭, 좌표도 없으면 제외 + 로그.
- P-5 지번주소 꼬리 건물명 제거 후 매칭. 동일 지번 재인허가는 별개 Tenancy로 유지.

### 4.3 지오코딩(좌표 보강)

- 제공자 = **VWorld 지오코더 API**(국토부 산하, 무료·키 발급). 인허가 데이터도 동일 국토부 계열이라 주소 체계 정합.
- 원본 좌표(x,y)가 채워져 있으면 좌표계 변환(EPSG:5174 또는 5179 → WGS84) 후 사용.
- 비어 있으면 지번주소로 VWorld 지오코딩 호출, `geocoded=true`. 지번(PARCEL) 우선, 실패 시 도로명(ROAD) 재시도.
- 둘 다 실패 → 지도 표시 불가 플래그. 목록에는 노출하되 마커 제외.
- 결과 캐시(같은 주소 재호출 금지, 쿼터 절약).
- **좌표 채움률은 실데이터 확인 전까지 미확정(R-A). 적재 스파이크에서 조기 검증.**

## 5. 통계 계산 규칙

- survivalMonths = 폐업: (closedAt − licensedAt) 월 내림. 영업중: (오늘 − licensedAt) 월 내림.
- averageSurvivalMonths = 해당 물건의 **폐업 이력만** 평균(영업중은 분모 제외), 반올림 정수. 폐업 0건이면 null.
- longest/shortest = 폐업 이력 중 최대/최소. 없으면 null.
- closedCount = status=폐업 이력 수. totalTenancyCount = 전체 이력 수.

## 6. 엔드포인트 (계약 준수)

| 메서드 | 경로 | 화면 | 반환 |
|---|---|---|---|
| GET | /api/sites/search?query= | 랜딩 | 자리 후보 목록 |
| GET | /api/sites/{pnu} | 지도·결과 | 자리 + 물건 목록 |
| GET | /api/units/{unitId} | 상세 | 물건 이력 + 통계 |

응답 스키마·에러 코드·예시는 `00-api-contract-v1.md` 그대로. 재기술 금지, 그 문서를 따른다.

### 구현 메모

- search: jibunAddress LIKE + 정렬(자리 내 물건 수 desc). 상한 20건.
- {pnu}: Site + Unit 목록 + 각 Unit 통계 조인. 없으면 404.
- {unitId}: Unit + Tenancy(licensedAt asc) + 통계. 없으면 404.
- disclaimer.dataAsOf = 적재 시점 상수(설정값). 모든 조회 응답에 주입.

## 7. 예외 처리

- `@RestControllerAdvice`로 도메인 예외 → 계약 에러 JSON 매핑.
- SiteNotFound/UnitNotFound → 404, InvalidQuery → 400, 그 외 → 500 INTERNAL_ERROR.

## 8. 시드 · 데모 안정성

- 적재 결과를 `data.sql` 또는 스냅샷으로 고정해 데모 중 외부 의존 제거.
- 데모용 대표 자리 3곳(판교 실주소) 선정 → 히스토리가 풍부한 물건 우선.
- 지오코딩 결과 캐시(재호출 방지).

## 9. 결정 완료

- **D-U1 물건 단위** (확정): 지번 접두사로 자리 내 전체 레코드 수집 → 상세주소 명시 물건은 그 값으로 분리, 미명시 잔여는 영업기간 겹침으로 분리. "1자리=1물건" 폐기. 규칙 상세 3.1.
- **D-GEO 지오코딩** (확정): VWorld 지오코더. 국토부 계열로 인허가 주소 체계와 정합, 무료.

## 10. 완료 기준(DoD)

- 3개 엔드포인트가 계약 예시와 동일 형태로 응답.
- 성남 수정구 실데이터 적재 완료, 대표 자리 3곳 히스토리 조회 정상.
- 모든 조회 응답에 disclaimer 포함.
- Railway 배포 후 프론트에서 CORS 통과 확인.
- 정제 제외 건수 로그 확인 가능(발표 근거).

## 11. 착수 순서 (Claude Code)

1. 프로젝트 스캐폰딩 + 계약 기반 컨트롤러 스텁(고정 목 응답)으로 계약부터 세움 → 프론트 병렬 진행 unblock.
2. 엔티티·리포지토리·스키마.
3. 적재 파이프라인(파서→정제→저장) + 소량 샘플로 검증.
4. 조회 서비스·통계 조립으로 목 응답 → 실응답 전환.
5. 지오코딩·좌표 변환.
6. Railway 배포·CORS·시드 고정.
