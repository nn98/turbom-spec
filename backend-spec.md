# 넥스트스텝 백엔드 상세 명세 v2

기존 `backend-spec.md`를 대체하는 상세판. 핵심 변화: 데이터 소스의 **시간 특성이 다른 두 계열**을 아키텍처 레벨에서 분리한다.

- **개폐업 정보** = 정제되어 DB에 이미 적재된 데이터. 백엔드는 **조회**만 한다(정제·최신화는 이 백엔드 책임 밖, 별도 배치/수동).
- **상권 정보** = 요청 시점에 외부 API(소상공인 상가정보)를 **실시간 호출**해 가져온다.

이 둘은 절대 같은 레이어에서 뭉치지 않는다. 조회 식별자는 **PNU**(지번주소 검색 → PNU 해석 → 두 소스 조합).

전제(실데이터 검증 완료, `인허가-데이터-필드명세-v4.md`):
- 인허가 데이터셋(19컬럼, 대분류/소분류 분리 반영)은 정제되어 DB에 적재됨. 이 백엔드는 조회만.
- **PNU 100% 채움**(유도 불필요), **폐업일자 실컬럼 존재**(근사 로직 폐기, closedAtEstimated 항상 false).
- **업종명 공백** → 제거. 대분류/소분류 분리(category=대분류, subCategory=소분류), industryDetail(상가API)은 있으면 우선.
- **주소분리여부 신뢰 불가**(호수 있어도 false) → 대부분 자리=물건 1:1.
- 실규모 10만 건 중 마스킹 5만 제외 → 유효 5만. 한 법정동 10년치로 연대기 충분.

---

## 1. 아키텍처 개요

```
                    ┌─────────────────────────────────────────┐
                    │            Controller (web)             │
                    │  GET /api/sites/search                  │
                    │  GET /api/sites/{pnu}                   │
                    │  GET /api/units/{unitId}                │
                    └────────────────┬────────────────────────┘
                                     │
                    ┌────────────────▼────────────────────────┐
                    │       SiteQueryService (application)     │
                    │  - 두 소스를 조합해 응답 조립             │
                    │  - 부분 실패 격리(상권 실패해도 개폐업 정상)│
                    └───────┬───────────────────────┬──────────┘
                            │                       │
              ┌─────────────▼──────────┐  ┌─────────▼───────────────────┐
              │  개폐업 조회 (DB)       │  │  상권 조회 (외부 API 실시간) │
              │  TenancyQueryService   │  │  MarketInfoService          │
              │  → JPA Repository      │  │  → SanggaApiClient (HTTP)    │
              │  → H2(인메모리)         │  │  → 소상공인 상가정보 API     │
              │  [읽기 전용, 빠름]      │  │  [네트워크, 느림, 실패 가능] │
              └────────────────────────┘  └─────────────────────────────┘
                     신뢰 경계 A                   신뢰 경계 B
              (우리 DB, 트랜잭션 보장)      (외부 의존, 타임아웃·서킷브레이커)
```

두 경계의 성질이 다르다는 게 이 설계의 전부다:
- **경계 A(DB)**: 항상 성공한다고 가정 가능. 실패하면 그건 500(우리 문제).
- **경계 B(외부 API)**: 언제든 실패할 수 있음(쿼터·타임아웃·장애). 실패해도 A의 결과는 내려간다. B 실패는 500이 아니라 해당 필드 null.

## 2. 레이어 구조 (패키지)

```
com.nextstep
├── web
│   ├── SiteController                 // 3개 엔드포인트
│   ├── dto/                           // 요청·응답 DTO (API 계약과 1:1)
│   └── GlobalExceptionHandler         // 도메인 예외 → 계약 에러 JSON
├── application
│   ├── SiteQueryService               // 오케스트레이션: 개폐업 + 상권 조합
│   ├── TenancyQueryService            // 개폐업 DB 조회 전담
│   └── MarketInfoService              // 상권 API 실시간 호출 전담
├── domain
│   ├── site/       Site, Pnu(값객체)
│   ├── unit/       Unit, UnitLabel, LocationSource
│   ├── tenancy/    Tenancy, TenancyPeriod, BusinessStatus, SurvivalMonths
│   ├── statistics/ UnitStatistics (도메인 계산 로직)
│   └── market/     MarketInfo, NearbyCategoryCount (외부 데이터의 도메인 표현)
└── infra
    ├── persistence/  JPA 엔티티·리포지토리 (개폐업 조회)
    └── sangga/       SanggaApiClient, 좌표변환, 응답 매핑 (상권 호출)
```

의존 방향: web → application → domain ← infra. domain은 Spring·JPA·HTTP 전부 비의존(순수 자바). MarketInfo는 외부에서 왔지만 domain에 그 개념(값객체)만 두고, 실제 호출은 infra.sangga가 담당.

## 3. 도메인 모델 (상세)

### 3.1 Site (자리)

```
Site
- pnu: Pnu                    // 값객체, 19자리 검증 내장
- jibunAddress: String
- roadAddress: String
- coordinate: Coordinate?     // 값객체(경도·위도), 없을 수 있음(nullable)
- units: List<Unit>           // 이 자리의 물건들(물리적 자리 있는 업종만)
- noStorefrontRegistrations: List<Tenancy>  // 2026-07-18 신규 — 아래 참고
```

- `Pnu` 값객체: 19자리 형식 검증, 앞 10자리(법정동코드) 추출 메서드. 인허가 데이터에 PNU가 직접 오므로 유도 불필요, 검증만.
- `Coordinate` 값객체: 좌표계 변환은 infra에서 끝내고 domain엔 WGS84(위경도)만.

#### 무점포업종 분리 (`NoStorefrontSubCategories`)

인허가 원본은 (category, subCategory)별로 "층/호 정보 없음" 비율이 실측 기준 뚜렷하게 이분됨 —
통신판매업·방문판매업·전화권유판매업·의료기기판매(임대)업 등 47개 (category, subCategory) 조합은
90% 이상이 상세주소 없음(업종 특성상 자가/사무실 주소로 신고 가능, 물리적 점포 개념이 약함).
정상 매장업종(일반음식점 20.4%, 휴게음식점 17.5% 등)은 이 비율이 낮고 순수 개별 데이터 누락임.

`NoStorefrontSubCategories.isNoStorefront(category, subCategory)`가 이 47개 목록을 정적으로 관리.
판정은 **레코드 단위가 아니라 같은 PNU 내 같은 businessName 단위** — 한 상호명이 무점포 후보
업종과 정상 매장업종(또는 실제 층/호 정보가 있는 레코드) 라이선스를 동시에 갖고 있으면(예:
"동물병원 더 하임"이 동물병원+동물미용업+동물위탁관리업을 동시 보유) 그 상호명의 레코드 전부를
매장으로 취급한다 — 부가 허가만 따로 떼서 이력을 쪼개지 않기 위함. 상호명 전체가 무점포 후보
업종이면서 층/호 정보도 전혀 없을 때만 `Site.noStorefrontRegistrations`로 분류, Unit 그룹핑(§7
물건 분리 규칙) 자체를 안 거침 — `TenancyQueryService.mergedTenancies()`(businessName + gap 90일
병합)만 적용.

이 목록은 90% 임계값을 기계적으로 적용한 결과이지 수작업 큐레이션이 아님. 표본이 작은 항목(n≤5건)은
통계적으로 약한 신호 — 향후 실사례로 오분류가 확인되면 개별 조정. 새 원본 파일 추가 시 이 임계값
기준으로 재계산해서 목록을 갱신할 것.

### 3.2 Unit (물건)

```
Unit
- unitId: UnitId              // {pnu}-U{seq}
- label: UnitLabel            // 호실단위주소 or "물건 A" or "단일 점포"
- locationSource: LocationSource   // LICENSE | SANGGA_API | OVERLAP_INFERRED
- tenancies: List<Tenancy>
- statistics: UnitStatistics  // 파생, 아래 계산 규칙
```

- `LocationSource` 우선순위: **LICENSE 최상위** — 인허가의 `주소분리여부='Y'`가 있으면 관청이 이미 구분한 것이므로 가장 신뢰. 그다음 SANGGA_API(상가 API 층/호 매칭), 최후 OVERLAP_INFERRED(영업기간 겹침 추정).
- **주의**: 실 19컬럼 데이터셋 실측 결과 `주소분리여부`는 **전부 false**로 확인됨(`인허가-데이터-필드명세-v4.md` §3 — 지번주소 문자열에 "201호"·"2층"이 있어도 값이 false, 신뢰 불가). 즉 LICENSE 분기는 우선순위상 최상위지만 실데이터에서는 사실상 발동하지 않는다 — 구현 시 이 분기가 "죽은 코드"처럼 보여도 정상이며, 실제 물건분리는 대부분 SANGGA_API 또는 OVERLAP_INFERRED로 떨어진다는 걸 전제하고 작업할 것. (이전 판(v2 데이터셋, 36컬럼)엔 `호실분리여부`+`호실단위지번주소`라는 별도 필드가 있었으나 현재 19컬럼 데이터셋엔 존재하지 않음 — 용어 혼용 금지)

### 3.3 Tenancy (이력)

```
Tenancy
- businessName: String
- category: String            // 대분류 (예: 동물), NOT NULL, 타임라인 표시
- subCategory: String         // 소분류 (예: 동물미용업), NOT NULL, 상세 표시
- period: TenancyPeriod       // 값객체: licensedAt, closedAt?
- status: String              // 원본 영업상태명 원문 5버킷: 영업/정상(표시는 "영업"), 폐업, 휴업,
                               // 취소/말소/만료/정지/중지, 제외/삭제/전출
- survivalMonths: Integer?    // period와 status로부터 계산, null 가능(아래 참고)

TenancyPeriod (값객체)
- licensedAt: LocalDate
- closedAt: LocalDate?        // 폐업일자 컬럼 실값 사용. null이 항상 "영업중"을 뜻하지는 않음
                               // (아래 survivalMonths 참고)
- survivalMonths(): licensedAt ~ (closedAt이 있으면 closedAt, 없으면 today), 월 내림
```

- `Tenancy.survivalMonths()`는 `status가 영업/정상이 아닌데 closedAt이 null`이면 **null**을 반환한다
  (`TenancyPeriod.survivalMonths()`를 그대로 안 씀). 원본에 폐업일자 컬럼이 비어있어도
  `status=영업/정상`이 아니면 "이미 종료됐지만 날짜를 모른다"는 뜻이라, `licensedAt~today`로
  계산하면 아직도 영업 중인 것처럼 보이는 왜곡이 생기기 때문(2026-07-17 실사례:
  취소/말소/만료/정지/중지 상태에 closedAt 없는 레코드가 survivalMonths=110개월로 표시된 버그).
  실측 기준 전체 레코드의 2.3%가 이 케이스(취소/말소류 1,821 + 제외/삭제/전출 263 + 휴업 117 +
  폐업인데 날짜없음 20). `UnitStatistics.closedCount`는 이런 레코드도 "폐업 이력"으로는 카운트하되
  평균/최장/최단 생존월 계산에서는 제외한다.
- `closedAtEstimated`는 이제 **불필요**(폐업일자 실값이 온다는 전제). 단, 구형/신형 데이터가 섞일 가능성에 대비해 필드는 유지하되 신형은 항상 false. (survivalMonths가 null인 것과는 별개 개념 — closedAtEstimated는 "날짜를 추정했는지", survivalMonths=null은 "계산 자체를 안 했는지".)

### 3.4 UnitStatistics (도메인 계산)

```
UnitStatistics (Unit의 tenancies로부터 계산)
- totalTenancyCount: 전체 이력 수
- closedCount: 폐업 이력 수
- averageSurvivalMonths: 폐업 이력만 평균 (없으면 null)
- longestSurvivalMonths / shortestSurvivalMonths: 폐업 이력 중 (없으면 null)
```

계산은 domain 내부 순수 로직. 적재 시 배치로 미리 계산해 저장할지(읽기 최적화), 조회 시 계산할지는 성능 판단 — 해커톤 규모에선 **조회 시 계산으로 충분**(자리당 이력 수십 건 이하).

### 3.5 MarketInfo (상권, 외부 데이터의 도메인 표현)

```
MarketInfo
- sameCategoryNearbyCount: Int?   // 상가 API 반경조회 결과 (유일한 실값)
- placeholderFields: 목업 6필드    // 전용면적·보증금·월세·권리금·유동인구·공실률
- isPlaceholder: true (항상)
- asOf: LocalDate
```

- `sameCategoryNearbyCount`만 외부 API 실값, 실패 시 null. 나머지는 소스 없어 목업(별도 조사로 확정됨, `의사결정-기록.md` 6장).
- domain엔 값객체로만 존재. 실제 API 호출·매핑은 infra.sangga.

## 4. 두 파이프라인의 명확한 분리 ★

### 4.1 개폐업 조회 파이프라인 (DB, 읽기 전용)

```
지번주소/PNU 입력
  → PnuResolver: 검색어를 PNU로 해석 (지번 토큰 AND 검색 or PNU 직접, 2026-07-22부터 — `api-spec.md` ① 매칭 방식 참조)
  → TenancyQueryService.findBySite(pnu)
    → SiteRepository.findByPnu (JPA)
    → UnitRepository.findBySitePnu
    → TenancyRepository.findByUnitIds
  → domain 조립 (Site → Units → Tenancies → Statistics 계산)
  → 반환
```

- 전부 우리 DB. 트랜잭션 `@Transactional(readOnly = true)`.
- 외부 의존 없음 → 이 경로는 상권 API 상태와 무관하게 항상 동작.
- **정제·최신화는 이 파이프라인 밖**: 인허가 데이터는 별도 배치(또는 수동 적재)로 이미 DB에 있다고 가정. 이 백엔드는 그걸 읽기만 함. 최신화 주기·방식은 이 명세의 책임이 아님(사용자 확정).

**Unit 그룹핑 — 충돌 감지/재분리 (2026-07-22 추가)**: `TenancyQueryService.unitGroups()`는
1차로 파싱된 층/호(또는 LOW 신뢰도 원문 상세주소 텍스트)로 그룹핑한다(기존 동작). 대형
상가·전통시장(가락시장, AK플라자 지하1층, 롯데백화점 지층, 백현동 541 지하1층 등)에서는 이
키가 층 정보만 있거나 아예 없어서 서로 다른 수백 개 사업자가 한 Unit으로 잘못 합쳐지는 문제가
실측으로 확인됨(가락시장: 동시영업 690개가 1개 Unit). 구체적 호실번호가 없는 그룹(`FLOOR::`
분기 또는 `__unknown__`)에 한해, 같은 그룹 안에서 서로 다른 상호(`business_name`)가 겹치는
기간에 영업 중이었던 적이 있으면(`OccupancySpan.overlaps()`, `domain.unit`) 물리적으로
불가능한 뭉침으로 판단해 재분리한다: 2차(지번/도로명 원문 텍스트) → 그래도 겹치면 3차
(상호명, 최후 수단). **구체적 호실번호(`UNIT::` 분기)가 있는 그룹은 이 검사 대상에서 제외** —
실제 문제 사례 전부 호실번호 없는 경우였고, 있는데 겹치는 경우는 폐업신고 누락일 가능성이
훨씬 높음. 배포 후 실측: 가락시장(PNU `1171010700006000000`) unitCount 1 → 1488, 창곡동
559-4/더존메디컬타워(PNU `4113110800105590004`) 4개로 정상 분리 확인.

**알려진 한계**: 이 재분리는 "겹치는 기간에 다른 상호명" 신호만 본다. 그래서 같은 물리적 공간을
공유하는 게 실제로 맞는 관련 인허가 페어링(집단급식소/위탁급식영업, §11 참조)도 주소 텍스트가
완전히 같으면 3차 키에서 상호명별로 갈라진다(실사례: 창곡동 559-4 11층, "더조은병원"(집단급식소)과
"(주)아워홈 더조은병원성남점"(위탁급식영업)이 겹치는 기간으로 잡혀 별도 Unit 2개로 분리됨).
이번 수정은 BusinessType 재설계(§11, 아직 미구현)와 통합하지 않은 독립적인 그룹핑 버그 수정이라
의도된 스코프 밖 — 관련인허가를 다시 연결하는 건 §11의 `RelatedLicenseLinker` 구현 시 처리.

### 4.2 상권 조회 파이프라인 (외부 API, 실시간)

```
PNU + 좌표 + 대상 업종(인허가 소분류)
  → MarketInfoService.fetch(pnu, lon, lat, subCategory)
    → IndustryCategoryMapper.toSanggaCategoryCode(subCategory)  // 인허가 소분류 → 상가 대분류(indsLclsCd) 매핑, 매핑 없으면 Optional.empty()
    → SanggaApiClient.countInRadiusByCategory(lon, lat, radius=300, indsLclsCd)
      [HTTP 호출, storeListInRadius(#10) — storeZoneInRadius(#2)와 혼동 금지]
    → 서버가 indsLclsCd로 이미 필터링한 응답의 totalCount를 그대로 사용
    → MarketInfo 값객체 조립 (실값 1 + 목업 6)
  → 반환 (매핑 없거나 실패 시 sameCategoryNearbyCount=null인 MarketInfo)
```

- **정정(2026-07-20, 클래스/메서드명 및 필터 단위 수정)**: 클래스명은 `SanggaApiClient`(g 두 개,
  이전 표기 `SangaApiClient`는 오타), 메서드는 `countInRadiusByCategory`. 클라이언트에서 응답
  items를 받아 하나씩 비교하는 방식이 아니라, 요청 시점에 **서버 측 필터링**을 걸고 그 결과의
  `totalCount`를 그대로 쓰는 것까지는 원래 서술이 맞다. 다만 필터 파라미터는 `indsSclsCd`(소분류)가
  아니라 **`indsLclsCd`(대분류)**다 — 인허가 소분류(행안부 체계)와 상가API 소분류(소상공인
  시장진흥공단 체계)는 서로 다른 분류라 공식 매핑표가 없고, 그래서 `IndustryCategoryMapper`가
  인허가 소분류 136개를 상가 대분류 10개(G2/I1/I2/L1/M1/N1/P1/Q1/R1/S2)로 손수 매핑해 그
  대분류로만 필터링한다(`상권조회-API-명세.md` §2.2 참조). `numOfRows=1`로 최소 페이로드만
  요청하는 것도 그대로 맞음.
- 오퍼레이션 이름 함정: "반경내 상권조회"(`storeZoneInRadius`, #2)는 상권 폴리곤 경계 데이터를 주는 **다른 오퍼레이션**. 우리가 쓰는 건 "반경내 상가업소조회"(`storeListInRadius`, #10).
- radius 상한 2000m(공식 문서 명시). 우리 고정값 300m는 여유 있음.
- 외부 HTTP. 타임아웃(예: 3초), 재시도(2회), 실패 시 예외 삼키고 null 반환.
- **캐싱**: 같은 PNU+업종에 대한 반경조회 결과는 짧게 캐시(예: 인메모리 TTL 10분). 요청마다 외부 API를 때리면 쿼터(개발계정 일 1,000건) 소진.
- 이 파이프라인의 실패는 **절대 개폐업 조회를 막지 않는다**.

### 4.3 두 파이프라인의 조합 (SiteQueryService)

```
SiteQueryService.getSiteDetail(pnu):
  tenancyResult = tenancyQueryService.findBySite(pnu)   // 경계 A, 실패=500
  if (tenancyResult 없음) throw SiteNotFound

  // 경계 B는 try-catch로 격리
  marketInfo = try { marketInfoService.fetch(...) }
               catch (Exception) { MarketInfo.unavailable() }

  return 조립(tenancyResult, marketInfo)
```

이 try-catch 격리가 부분 실패 설계의 실제 구현 지점. 개폐업(A)은 트랜잭션으로 보장, 상권(B)은 실패해도 A 결과에 null 필드만 얹혀서 나감.

## 5. 엔드포인트별 두 소스 사용 (계약 `api-spec.md` 준수)

| 엔드포인트 | 개폐업(DB) | 상권(API) |
|---|---|---|
| `GET /api/sites/search` | 지번 토큰 AND 검색으로 PNU 후보(2026-07-22부터) | 사용 안 함 |
| `GET /api/sites/{pnu}` | Site+Units+각 Unit 통계 | 사용 안 함(물건 목록만) |
| `GET /api/units/{unitId}` | Unit+Tenancies+통계 | **각 이력에 marketInfo 실시간 조립** |

- 상권 API 실시간 호출이 실제로 일어나는 건 `GET /api/units/{unitId}` 한 곳뿐. 여기서만 경계 B가 관여.
- search·sites는 순수 DB 조회라 빠르고 항상 성공.

## 6. 인허가 데이터 → 도메인 매핑 (실 CSV 19컬럼, `인허가-데이터-필드명세-v4.md`)

| 도메인 | 소스 컬럼 |
|---|---|
| Site.pnu | PNU (100% 채움, 직접 사용) |
| Site.jibunAddress / roadAddress | 지번주소 / 도로명주소 |
| Site.coordinate | 원본좌표X/Y → WGS84 변환(infra). 결측 0%(10건 표본 실측, `인허가-데이터-필드명세-v4.md` §7) → VWorld·상가API 등 외부 지오코딩 폴백 불필요. 단 표본 검증이라 전량 적재 시 변환 실패 개별 건은 여전히 발생 가능 — `COORD_CONVERT_FAIL` 로그 후 지도 마커만 제외(§9 마스킹 규칙과 동일 처리, 목록엔 노출) |
| Site.addressCorrected | 주소보정성공여부 (마스킹 품질) |
| Unit | 대부분 자리=물건 1:1 (주소분리여부 신뢰불가). label 기본 "단일 점포" |
| Tenancy.businessName | 사업장명 |
| Tenancy.category | 대분류 (NOT NULL, 타임라인 표시) |
| Tenancy.subCategory | 소분류 (NOT NULL, 상세 표시) |
| Tenancy.licensedAt | 인허가일자 |
| Tenancy.closedAt | 폐업일자 (실값, 공백=영업중) |
| Tenancy.status | 영업상태 → {영업,폐업,휴업} |

**마스킹 처리**: 주소보정성공여부·마스킹 흔적으로 저품질 레코드 제외(ingestion_exclusion_log). "10만→유효 5만"의 실체이자 발표의 데이터 정직성 근거.

## 7. 스택·배포

- Java 21(정정, 2026-07-20 — 실제로는 이미 21로 운영 중이었으나 스펙이 17로 미반영 상태였음), Spring Boot 3.3.4, Spring Web, Spring Data JPA
- DB: **MySQL 8**(2026-07-20부터, `turbom-server` 커밋 `d1bff4b`). 배포 서버에 직접 설치한 단일
  인스턴스, 전용 DB `turbom` + 전용 계정 `turbom_app@localhost`(외부 네트워크 미노출). 앱은
  `spring.sql.init.mode: never`로 **기동 시 시드 재적재를 하지 않는다**.
  - **왜 H2 인메모리(아래 이전판 설명)에서 바꿨나**: `spring.sql.init.data-locations`가 기동마다
    시드 SQL 1,589개 파일(570MB, 약 158만 행)을 처음부터 재파싱해 적재하는 구조라, 데이터가
    158만 행 규모로 커지면서 배포마다 ~90초 부팅 + jar 354MB가 실질적 병목이 됨.
  - 시드는 이제 JVM 밖에서 한 번만 처리한다 — `scripts/mysql/mysql-schema.sql`(스키마) +
    `scripts/mysql/load-new-chunks.sh`(아직 `seed_files_applied` 추적 테이블에 없는 신규 청크만
    idempotent 적재), 배포 파이프라인(`.github/workflows/ci-cd.yml`)의 deploy job에서 재시작 전에
    실행.
  - **실측 결과**: 부팅 90초 → **9초**(신규 jar를 MySQL로 기동해 HikariPool 연결 확인 로그로 검증),
    jar 354MB → 239MB(`data/**`를 메인 Maven 리소스에서 제외, `h2`는 test scope로 격하 — 남은
    239MB 중 191MB는 Playwright 브라우저 바이너리 번들이라 이 변경과 무관, 별개 이슈).
  - **테스트 영향 없음**: `src/test/resources/application.yml`에 기존 H2 인메모리 설정(`mode: always`
    + `data-locations`)을 그대로 복제 — Maven이 테스트 클래스패스에서 이 설정을 메인보다 우선시켜
    `mvn test`는 지금도 H2로 79개 테스트 전부 통과(`PersistenceSmokeTest`의 정확한 행수 검증 포함).
  - **용량 계획 기준 변경**: 아래 이전판의 "AWS 인스턴스 RAM(JVM 힙) 기준" 문장은 더 이상 유효하지
    않음 — 이제 MySQL 데이터 디렉터리(디스크)가 영속 저장소이고, RAM은 JVM 힙 + MySQL 버퍼풀의
    통상적인 기준으로 계획한다.
  - 상세 결정 경위: `의사결정-기록.md` §10.
  - **(이전판, 참고용 — 2026-07-20 이전 실제 운영 구성)**: DB: H2 인메모리(별도 DB 서버 없음).
    로컬·AWS 운영 동일 구성 — `spring.sql.init.data-locations`가 기동 시마다
    `src/main/resources/data/licensed-business-records-*.sql`을 전부 재적재. 서버 프로세스가
    재시작되면 DB 내용도 그 시점의 SQL 시드 파일 기준으로 다시 만들어짐(영속 디스크 스토리지
    없음 — PostgreSQL/Railway 전제였던 이전 버전과 가장 큰 차이였음).
- HTTP 클라이언트: Spring RestClient 또는 WebClient(상가 API 호출용)
- 캐시: Spring Cache(@Cacheable) + Caffeine(인메모리 TTL)
- 배포: AWS (Spring Boot 서버 프로세스 직접 실행 + MySQL 8을 같은 인스턴스에 직접 설치, 별도 관리형 DB 서비스 없음)
- 서킷브레이커(선택): Resilience4j — 상가 API 연속 실패 시 일정 시간 호출 스킵하고 바로 null. 해커톤 스코프엔 과할 수 있어 단순 try-catch+타임아웃으로 시작, 여유되면 추가.

## 8. 조회 식별자 = PNU (일관성)

- 사용자 진입: 지번주소 텍스트 검색 → `search`가 PNU 후보 반환
- 이후 모든 조회는 PNU(또는 PNU 파생 unitId) 기준
- 상권 API 호출도 PNU로 Site를 찾아 그 좌표로 반경조회 트리거
- 즉 PNU가 개폐업(DB)과 상권(API) 두 소스를 잇는 유일한 조인 키

## 9. schema.sql 반영 사항 (폐업일자·호실분리 반영)

- `tenancy_record.closed_at` = 폐업일자 실값(nullable, null=영업중). `closed_at_estimated`는 신형에선 항상 false(구형 호환 위해 컬럼은 유지)
- `unit.location_source` 기본값·우선순위에 LICENSE 최상위 반영
- `site` 테이블에 원본 필드 보존용 컬럼 선택적 추가(주소보정여부, 후보수 등 — 매칭 신뢰도 판단용, MVP엔 생략 가능)
- **MarketInfo는 테이블 없음**: 실시간 API 호출 결과라 DB에 영속화하지 않음(캐시만). schema.sql에서 marketInfo 관련 테이블 제거 — 이게 이전 버전과의 핵심 차이(이전엔 캐시 테이블을 뒀지만, "상권=실시간 호출" 원칙을 명확히 하려면 DB 영속화 자체를 안 하는 게 설계 의도에 맞음. 인메모리 캐시로 충분).

## 10. 착수 순서 (Claude Code)

1. 프로젝트 스캐폰딩 + 계약 기반 컨트롤러 스텁(고정 목 응답).
2. domain 순수 모델(Site/Unit/Tenancy/값객체/UnitStatistics) + 단위 테스트.
3. infra.persistence: JPA 엔티티·리포지토리, 개폐업 조회 파이프라인(4.1).
4. TenancyQueryService + SiteQueryService(상권 없이 개폐업만) → search·sites 엔드포인트 완성.
5. infra.sangga: SanggaApiClient(HTTP), 좌표변환, MarketInfoService(4.2).
6. SiteQueryService에 상권 조합(4.3, try-catch 격리) → units 엔드포인트 완성.
7. 캐시·타임아웃·AWS 배포.

**개폐업만으로 4번까지 가면 이미 핵심 서비스가 동작한다** — 상권(5~6)은 그 위에 얹는 부가층. 이 순서가 부분 실패 설계와 일치(상권 없어도 서비스 성립).

## 11. 실험적 파이프라인(개발용, 비공개) — 경매정보 수집

이 섹션은 위 1~10장의 공개 서비스 계약과 무관하다. `api-spec.md`에 노출된 3개 엔드포인트 중 어디에도
연결되지 않고, 어떤 `@RestController`에도 배선되지 않은 **내부 검증 전용 스파이크**다.

- **목적**: 법원경매(courtauction.go.kr) 이력을 자리(PNU) 단위로 곁들이는 기능의 실현 가능성 검증.
  스키마·수집 코드는 존재하나 프로덕션 노출은 courtauction.go.kr 이용약관 제15조(법원행정처 동의
  없는 가공/영리목적 이용 금지)로 보류 중 — 상세: `의사결정-기록.md` 8장,
  `server/docs/superpowers/plans/2026-07-19-auction-data-collection-spike.md`.
- **패키지**: `domain.auction`(`AuctionCase`/`AuctionScheduleEntry`/`AuctionCaseRef`, 프레임워크
  비의존), `infra.auction`(`AuctionListParser`/`AuctionDetailParser` — 정규식 기반 텍스트 파서,
  `CourtAuctionCollector` — Playwright 헤드리스 브라우저 오케스트레이션), `infra.persistence`
  (`AuctionCaseEntity`/`AuctionScheduleEntryEntity`/`AuctionCaseRepository`), `application.auction`
  (`AuctionCollectionService`).
- **자동 실행 금지**: `AuctionCollectionService`는 Spring 스테레오타입 애노테이션이 전혀 없는 순수
  클래스 — 개발자가 테스트나 REPL에서 직접 `new`해서 호출해야만 실행된다. `@Scheduled` 없음,
  `CommandLineRunner`/`ApplicationRunner` 미구현.
- **실사이트 접근 테스트는 CI에서 절대 실행되지 않음**: `PlaywrightSmokeCheck`·
  `CourtAuctionCollectorManualCheck`는 의도적으로 `Test`/`Tests`/`TestCase` 접미사를 피해 Maven
  Surefire 기본 인클루드 패턴에서 제외된다 — `mvn test -Dtest=클래스명`으로만 수동 실행.
- **현재 상태(2026-07-19 갱신)**: 목록/상세 파서는 실측 캡처 텍스트로 TDD 완료. 수집기는 라이브
  사이트에서 실제로 검증 완료 — 성남시 수정구 상업용 매물 5건을 실제로 수집(주소·감정가 등 실값
  확인). 이전 기록("검색 결과 0건")은 이 세션에서 원인 4가지를 모두 찾아 수정하며 해소됨 — 상세
  경위는 `CHANGELOG.md` 18차 참고. `PlaywrightSmokeCheck`/`CourtAuctionCollectorManualCheck`로
  수동 재현 가능.
- **`schema.sql`에 `auction_case`/`auction_schedule_entry` 테이블 존재**하지만 자동 적재 경로가
  없어 프로덕션 H2에서도 항상 빈 테이블.
