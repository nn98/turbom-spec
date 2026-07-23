# 넥스트스텝 API 명세 v3

이전 `api-spec-v2.md`를 대체한다. **정정**: 실제 화면 스크린샷 검토 결과 상권정보 패널의 위치가 잘못 설계됐었다 — 건물 상세(②)가 아니라 **물건 상세(③)**, 그것도 선택된 이력(Tenancy) 옆에 붙는 "계약·주변상권 정보" 카드였다. v2에서 site 응답에 넣었던 `neighborhood`는 제거하고 unit 응답에 `marketInfo`로 옮긴다.

동시에 필드 성격을 명확히 나눈다. 화면 참고 이미지의 카드는 6개 필드 중 **1개만 실제 API로 만들 수 있고 나머지 5개는 데이터 소스가 없다**(이미지 자체에 "실 데이터 연동 전 예시값입니다" 캡션이 있음):

| 필드 | 소스 상태 |
|---|---|
| 주변 같은업종 개수 | **실제** — 상가API 반경조회 |
| 전용면적 / 보증금·월세 / 권리금 | **소스 없음** — 임대차 계약 정보, 확보한 API 어디에도 없음 |
| 일평균 유동인구 | **소스 없음** — 상가API엔 없는 필드 |
| 주변 공실률 | **소스 없음** — 상가API엔 없는 필드, 서울 열린데이터광장은 서울 한정이라 성남에 부적용 |

`isPlaceholder` 필드로 이 구분을 응답에 명시한다. Claude Code가 없는 소스를 만들려 시도하지 않도록 하는 게 목적.

## 공통 규약

- Base URL: 로컬 `http://localhost:8080`, 운영 AWS 도메인.
- JSON, `Content-Type: application/json; charset=UTF-8`. 인증 없음.
- 날짜 `YYYY-MM-DD`. 값 없으면 `null`.
- 모든 조회 응답에 `disclaimer` 상시 포함.

## 도메인 계층 · 데이터 소스 (재확인)

| 소스 | 만드는 것 | 반영 위치 |
|---|---|---|
| 인허가정보(localdata) | 자리·물건·히스토리(개폐업 이력) | `timeline[]`, `statistics` |
| 인허가정보 — 대분류 | 업종 대분류(예: 동물) | `timeline[].category` |
| 인허가정보 — 소분류 | 업종 소분류(예: 동물미용업) | `timeline[].subCategory` |
| 상권정보(상가 API, 반경조회) | 주변 같은업종 개수(유일한 실제 필드) | `timeline[].marketInfo.sameCategoryNearbyCount` |
| 상권정보(상가 API, 동 단위 매칭) | 히스토리 보강(층/호, 상가API 세부업종) | `units[].industryDetail` 등, `timeline[].industryDetail` 등 |
| (미확보) 임대차·유동인구·공실률 | 소스 없음 — 목업 상수 | `timeline[].marketInfo`의 나머지 필드, `isPlaceholder: true` |

계층: Site 1—N Unit 1—N Tenancy. 자리 키 `pnu`, 물건 키 `unitId`.

## 화면 매핑

| 화면 | 엔드포인트 | 신규 반영 |
|---|---|---|
| ① 랜딩·검색 | `GET /api/sites/search` | 없음 |
| ② 건물(자리) 상세·물건목록 | `GET /api/sites/{pnu}` | `units[]`에 보강 필드만 추가(neighborhood 없음 — **v2에서 제거**) |
| ③ 물건 상세·히스토리 | `GET /api/units/{unitId}` | `timeline[]`에 보강 필드 + **선택 이력별 `marketInfo`(신규)** |

---

## ① GET /api/sites/search

**Query**: `query` (string, 필수)

**매칭 방식** (2026-07-22부터): `query`를 공백 기준으로 토큰화해서 모든 토큰이
`jibunAddress` 또는 `roadAddress`에 순서·인접 여부와 무관하게 전부 나타나는 행만 후보로 삼는다
(AND 매칭). 숫자만으로 된 토큰은 앞뒤에 다른 숫자가 붙어있지 않은 경우에만 매칭한다(예:
`"534"` 검색 시 `"534-1"`은 매칭하지만 `"1534"`·`"5340"`은 제외 — 층/호수 등 무관한 숫자 오탐 방지).
`query`가 `pnu`와 정확히 일치하면 토큰 매칭과 무관하게 항상 통과한다(PNU는 주소 텍스트에
그대로 나타나지 않으므로 별도 처리).

이전에는 `query` 전체를 하나의 substring으로 `jibunAddress`/`roadAddress`에 `LIKE '%query%'`
매칭했어서, 토큰 순서가 바뀌거나 중간 토큰(구/동 등) 하나라도 빠지면 매칭이 실패했고, 숫자만
검색하면 지번이 아닌 층/호수 등 무관한 숫자에도 걸렸다.

**200**
```json
{
  "candidates": [
    {
      "pnu": "4113310300104050001",
      "jibunAddress": "경기도 성남시 수정구 금토동 405-1",
      "roadAddress": "경기도 성남시 수정구 대왕판교로 815",
      "latitude": 37.4012,
      "longitude": 127.1045,
      "unitCount": 3,
      "closedCount": 8,
      "currentSubCategory": "일반음식점",
      "units": [
        { "unitId": "4113310300104050001-U1", "parsedFloor": "1", "parsedUnitNo": "101", "parseConfidence": "HIGH" },
        { "unitId": "4113310300104050001-U2", "parsedFloor": "2", "parsedUnitNo": "201", "parseConfidence": "HIGH" }
      ]
    }
  ]
}
```
빈 결과: `{ "candidates": [] }` (200). query 누락: 400 `INVALID_QUERY`.

`units`가 0개인 자리(무점포업종만 있는 PNU, `noStorefrontRegistrations[]` 참고)는 후보에서 제외한다 —
**2026-07-18부터**. 실사례: 금토동 390-11/436-3/517-7(고압가스업·통신판매업만 있음)이 지도 마커만
뜨고 실제 가게 정보가 없는 버그로 발견됨.

`currentSubCategory`(string\|null, **2026-07-20 뒤늦게 문서화 — 코드엔 이미 있던 필드**): 현재
영업 중인 Unit 중 아무 곳이나 하나의 소분류. 전체 공실이면 null.

`candidates[].units[]`(array, **2026-07-22 신규**): `units[]`(§②)의 축약판 — `unitId`/`parsedFloor`/
`parsedUnitNo`/`parseConfidence` 4필드만. 검색 결과 단계에서 건물별로 묶고 그 안에서 층/호로
재분리하려는 프론트 워크플로우를 위해, 자리마다 상세 API(`GET /api/sites/{pnu}`)를 추가 호출하지
않아도 되게 검색 응답에 바로 실어준다. `parseConfidence`가 `"HIGH"`일 때만
`parsedFloor`/`parsedUnitNo`를 신뢰할 것(§②와 동일 규칙).

---

## ② GET /api/sites/{pnu} — 건물 상세 (neighborhood 제거)

**200**
```json
{
  "site": {
    "pnu": "4113310300104050001",
    "jibunAddress": "경기도 성남시 수정구 금토동 405-1",
    "roadAddress": "경기도 성남시 수정구 대왕판교로 815",
    "latitude": 37.4012,
    "longitude": 127.1045
  },
  "units": [
    {
      "unitId": "4113310300104050001-U1",
      "label": "1층 101호",
      "currentBusinessName": "치킨나라",
      "currentStatus": "영업",
      "totalTenancyCount": 5,
      "closedCount": 4,
      "averageSurvivalMonths": 27,
      "industryDetail": "후라이드/양념치킨",
      "locationSource": "sangga_api",
      "parsedFloor": "1",
      "parsedUnitNo": "101",
      "parseConfidence": "HIGH"
    }
  ],
  "noStorefrontRegistrations": [
    {
      "businessName": "에스트(est)",
      "category": "생활",
      "subCategory": "통신판매업",
      "licensedAt": "2019-06-04",
      "closedAt": null,
      "status": "영업"
    }
  ],
  "disclaimer": {
    "dataAsOf": "2026-07-04",
    "note": "인허가 신고 기준 데이터로 실제 영업 현황과 차이가 있을 수 있습니다."
  }
}
```

### `units[]` 필드

| 필드 | 타입 | 설명 |
|---|---|---|
| unitId | string | 물건 키 |
| label | string | 상세주소 있으면 그 값, 없으면 `물건 A`, 단일이면 `단일 점포` |
| currentBusinessName | string\|null | 현재 영업 가게명(공실이면 null) |
| currentStatus | `영업`\|`공실` | |
| totalTenancyCount | number | 거쳐간 가게 수 |
| closedCount | number | 폐업 수 |
| averageSurvivalMonths | number\|null | 폐업 이력만 평균 |
| industryDetail | string\|null | 세부 업종(상가API indsSclsNm). 공실·보강실패 시 null |
| locationSource | `"license"`\|`"sangga_api"`\|`"overlap_inferred"` | label 출처 |
| parsedFloor | string\|null | **2026-07-20 뒤늦게 문서화** — 원본 상세주소에서 파싱된 층. 없으면 null |
| parsedUnitNo | string\|null | **2026-07-20 뒤늦게 문서화** — 파싱된 호실 번호. 없으면 null |
| parseConfidence | `"HIGH"`\|`"LOW"` | **2026-07-20 뒤늦게 문서화** — `HIGH`일 때만 `parsedFloor`/`parsedUnitNo`/`label`의 파싱 결과를 신뢰할 것 |

### `noStorefrontRegistrations[]` 필드 — **2026-07-18 신규**

물리적 자리(Unit) 개념이 없는 업종의 인허가 이력. `units[]`와 배타적 — 한 레코드가 둘 다에 나타나지 않음.
통신판매업·방문판매업 등 자가/사무실 주소로 신고 가능한 업종(원본 데이터에 층/호 정보가 구조적으로
없는 업종, 판별 기준은 `backend-spec.md` §3.1 무점포업종 분리 참고)이 여기 담긴다. `unitId`/`marketInfo`/
통계 없음 — 물리적 자리가 아니므로.

| 필드 | 타입 | 설명 |
|---|---|---|
| businessName | string | |
| category | string | 대분류 |
| subCategory | string | 소분류 |
| licensedAt | string(date) | |
| closedAt | string(date)\|null | |
| status | string | 원본 영업상태명 원문(5버킷) |

- pnu 없음: 404 `SITE_NOT_FOUND`
- units 정렬: 폐업 많은 순.

---

## ③ GET /api/units/{unitId} — 물건 상세·히스토리 (marketInfo 신규)

**200**
```json
{
  "unit": {
    "unitId": "4113310300104050001-U1",
    "label": "1층 101호",
    "jibunAddress": "경기도 성남시 수정구 금토동 405-1",
    "roadAddress": "경기도 성남시 수정구 대왕판교로 815",
    "parsedFloor": "1",
    "parsedUnitNo": "101",
    "parseConfidence": "HIGH"
  },
  "statistics": {
    "totalTenancyCount": 5,
    "closedCount": 4,
    "averageSurvivalMonths": 27,
    "longestSurvivalMonths": 44,
    "shortestSurvivalMonths": 11
  },
  "timeline": [
    {
      "tenancyId": "t-1001",
      "businessName": "고기굽는집",
      "category": "음식",
      "subCategory": "일반음식점",
      "industryDetail": null,
      "licensedAt": "2013-05-02",
      "closedAt": "2017-01-10",
      "status": "폐업",
      "survivalMonths": 44,
      "closedAtEstimated": false,
      "enrichmentSource": "license_only",
      "marketInfo": {
        "isPlaceholder": true,
        "leaseAreaSqm": 42.6,
        "depositKrw": 50000000,
        "monthlyRentKrw": 2800000,
        "keyMoneyKrw": 0,
        "dailyFloatingPopulation": 21400,
        "sameCategoryNearbyCount": 14,
        "vacancyRatePercent": 6.2,
        "asOf": "2026-07-04",
        "totalStoreCount": 132,
        "categoryBreakdown": [
          { "code": "I2", "name": "음식", "count": 41, "ratio": 0.31 },
          { "code": "G2", "name": "소매", "count": 28, "ratio": 0.21 }
        ]
      }
    },
    {
      "tenancyId": "t-1005",
      "businessName": "치킨나라",
      "category": "음식",
      "subCategory": "일반음식점",
      "industryDetail": "후라이드/양념치킨",
      "licensedAt": "2023-01-15",
      "closedAt": null,
      "status": "영업",
      "survivalMonths": 41,
      "closedAtEstimated": false,
      "enrichmentSource": "sangga_api",
      "marketInfo": {
        "isPlaceholder": true,
        "leaseAreaSqm": 42.6,
        "depositKrw": 50000000,
        "monthlyRentKrw": 2800000,
        "keyMoneyKrw": 0,
        "dailyFloatingPopulation": 21400,
        "sameCategoryNearbyCount": 11,
        "vacancyRatePercent": 6.2,
        "asOf": "2026-07-04",
        "totalStoreCount": 132,
        "categoryBreakdown": [
          { "code": "I2", "name": "음식", "count": 41, "ratio": 0.31 },
          { "code": "G2", "name": "소매", "count": 28, "ratio": 0.21 }
        ]
      }
    }
  ],
  "disclaimer": {
    "dataAsOf": "2026-07-04",
    "note": "인허가 신고 기준 데이터로 실제 영업 현황과 차이가 있을 수 있습니다."
  }
}
```

`unit.parsedFloor`/`parsedUnitNo`/`parseConfidence`(**2026-07-20 뒤늦게 문서화**): §②의 `units[]`와
동일한 필드·의미(`parseConfidence`가 `HIGH`일 때만 신뢰).

### `timeline[]` 필드 (신규 부분)

| 필드 | 타입 | 설명 |
|---|---|---|
| tenancyId | string | **[신규]** "가게 자세히 보기" 드롭다운이 선택할 키 |
| category | string | 인허가 대분류(예: 음식, 동물). 항상 존재 |
| subCategory | string | 인허가 소분류(예: 일반음식점, 동물미용업). 항상 존재 |
| industryDetail | string\|null | 상가API 세부업종. **있으면 이걸 우선 표시, 없으면 subCategory로 폴백**. 폐업 이력은 원천적으로 null |
| survivalMonths | number\|null | **2026-07-17부터 null 가능.** `status`가 "영업"이 아닌데 `closedAt`이 null이면(원본에 종료일자가 없는 취소/말소/휴업 등) 계산 불가로 null — licensedAt~오늘로 계산하면 아직 영업 중인 것처럼 보이는 왜곡이 생기기 때문. 프론트는 null이면 "기간 미상" 등으로 표시할 것 |
| enrichmentSource | `"sangga_api"`\|`"license_only"` | 보강 성공 여부 |
| **marketInfo** | object | **[신규]** 아래 표 |

세 업종 필드 구분: `category`(대분류, 필수) → `subCategory`(소분류, 필수) → `industryDetail`(상가API 세부, 영업중만·있으면 우선). 화면에선 category를 타임라인 기본 표시, 물건 상세 클릭 시 subCategory 노출, industryDetail 있으면 그걸 우선.

### `marketInfo` 객체 — 필드별 소스 구분이 핵심

| 필드 | 타입 | 소스 | 비고 |
|---|---|---|---|
| isPlaceholder | boolean | — | `true`면 이 객체 전체가 예시값. 현재는 항상 `true`(임대차·유동인구·공실률 소스 미확보) |
| leaseAreaSqm | number\|null | **없음(목업)** | 전용면적 |
| depositKrw | number\|null | **없음(목업)** | 보증금 |
| monthlyRentKrw | number\|null | **없음(목업)** | 월세 |
| keyMoneyKrw | number\|null | **없음(목업)** | 권리금(0=무) |
| dailyFloatingPopulation | number\|null | **없음(목업)** | 일평균 유동인구 |
| sameCategoryNearbyCount | number | **실제 — 상가API 반경조회** | 자리 좌표 기준 반경 내 동일 업종 점포 수. `isPlaceholder`와 무관하게 항상 실값 시도, 실패 시에만 null |
| vacancyRatePercent | number\|null | **없음(목업)** | 주변 공실률 |
| asOf | string(date) | — | 기준일 |
| totalStoreCount | number\|null | **실제 — 상가API 반경조회, 2026-07-20 뒤늦게 문서화** | 같은 반경(300m) 내 업종 필터 없는 전체 점포 수. 실패 시 null |
| categoryBreakdown | array | **실제, 2026-07-20 뒤늦게 문서화** | 반경 내 상가API 대분류별 개수·비중. 각 항목 `{code, name, count, ratio}`(`ratio`=0~1). 실패 시 빈 배열 |

`sameCategoryNearbyCount`는 선택된 이력이 어느 것이든 **현재 시점 기준 동일 값**이 나간다 — 상가API가 현재 스냅샷만 주기 때문에 과거 이력을 조회해도 "그 시절 주변 상황"은 알 수 없다. 이 값이 과거를 재현한 게 아니라 "지금 기준"이라는 걸 화면에 명시해야 한다(marketInfo.asOf가 그 역할). `totalStoreCount`/`categoryBreakdown`도 같은 반경조회 호출에서 나오는 실값이라 동일하게 "지금 기준"이다.

- unitId 없음: 404 `UNIT_NOT_FOUND`
- `timeline`은 `licensedAt` 오름차순.
- `marketInfo`는 매 이력 항목마다 내려가지만(드롭다운에서 어느 걸 선택해도 즉시 표시 가능하도록), 값 자체는 6개 목업 필드 한정으로 전 항목 동일. `sameCategoryNearbyCount`만 선택 물건의 업종에 따라 달라질 수 있음(물건마다 대표 업종이 다르면).

---

## 공통 에러

```json
{ "error": "SITE_NOT_FOUND", "message": "해당 자리를 찾을 수 없습니다." }
```

| code | HTTP | 상황 |
|---|---|---|
| INVALID_QUERY | 400 | query 누락/공백 |
| SITE_NOT_FOUND | 404 | pnu 없음 |
| UNIT_NOT_FOUND | 404 | unitId 없음 |
| INTERNAL_ERROR | 500 | 서버 오류 |

`sameCategoryNearbyCount` 산출 실패(상가API 오류)는 별도 에러 코드 없이 해당 필드만 `null`로 응답한다 — 전체 요청은 계속 200.

