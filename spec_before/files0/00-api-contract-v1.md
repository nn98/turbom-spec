# 넥스트스텝 API 계약 v1.0

프론트·백엔드 공유 단일 진실원본(SSOT). 이 문서가 두 명세의 상위 계약이다. 프론트는 이 응답 형태로 목(mock)을 만들고, 백엔드는 이 형태로 응답을 보장한다. 필드 추가·변경은 이 문서를 먼저 고친 뒤 양쪽에 반영한다.

- Base URL(로컬): `http://localhost:8080`
- Base URL(운영): Railway 배포 도메인
- 응답 포맷: JSON, `Content-Type: application/json; charset=UTF-8`
- 인증: 없음(해커톤 MVP)
- CORS: 프론트 Vercel 도메인 + `localhost:3000` 허용
- 날짜: ISO `YYYY-MM-DD`. 값 없으면 `null`
- 금액/개월: 정수. 계산 불가 시 `null`

## 용어

- 자리(Site): 지번 단위 위치. 하나의 건물/필지에 대응. 키 = `pnu`
- 물건(Unit): 그 자리 안의 개별 점포. 같은 물건에 시간에 따라 여러 가게가 들어오고 나감
- 이력(Tenancy): 한 물건에 특정 가게가 영업한 한 구간(개업~폐업)

계층: Site 1 — N Unit 1 — N Tenancy

---

## 화면-엔드포인트 매핑

| 화면 | 사용 엔드포인트 |
|---|---|
| ① 랜딩 · 지번 조회 | `GET /api/sites/search` |
| ② 지도 · 조회 결과(건물 내 물건 선택) | `GET /api/sites/{pnu}` |
| ③ 물건 상세 · 히스토리 | `GET /api/units/{unitId}` |

---

## ① GET /api/sites/search

지번/도로명 텍스트로 자리 후보를 찾는다. 랜딩 검색.

**Query**

| 파라미터 | 타입 | 필수 | 설명 |
|---|---|---|---|
| query | string | Y | 지번 또는 도로명 일부. 예: `금토동 405` |

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
      "unitCount": 6,
      "closedCount": 9
    }
  ]
}
```

- `unitCount`: 이 자리에 존재한(현재+과거) 물건 수
- `closedCount`: 이 자리 전체 누적 폐업 건수(리스트에서 미리보기용)
- 후보 없음 → `{ "candidates": [] }` (200)

---

## ② GET /api/sites/{pnu}

한 자리(건물)의 물건 목록. 지도 마커 + 결과 패널에서 물건 선택용.

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
      "unitId": "4113310300104050001-B1F-101",
      "label": "1층 101호",
      "currentBusinessName": "치킨나라",
      "currentStatus": "영업",
      "totalTenancyCount": 5,
      "closedCount": 4,
      "averageSurvivalMonths": 21
    },
    {
      "unitId": "4113310300104050001-2F-201",
      "label": "2층 201호",
      "currentBusinessName": null,
      "currentStatus": "공실",
      "totalTenancyCount": 3,
      "closedCount": 3,
      "averageSurvivalMonths": 14
    }
  ],
  "disclaimer": {
    "dataAsOf": "2026-07-04",
    "note": "인허가 신고 기준 데이터로 실제 영업 현황과 차이가 있을 수 있습니다."
  }
}
```

- `currentStatus`: `영업` | `공실`(현재 영업 가게 없음)
- `label`: 원본 상세주소(예: `"1층 101호"`)가 있으면 그 값. 없으면 분리된 물건 순번 라벨(예: `"물건 A"`, `"물건 B"`). 단일 물건이면 `"단일 점포"`
- pnu 미존재 → 404 `SITE_NOT_FOUND`

---

## ③ GET /api/units/{unitId}

한 물건의 전체 이력(히스토리) + 통계. 물건 상세 화면.

**200**
```json
{
  "unit": {
    "unitId": "4113310300104050001-B1F-101",
    "label": "1층 101호",
    "jibunAddress": "경기도 성남시 수정구 금토동 405-1",
    "roadAddress": "경기도 성남시 수정구 대왕판교로 815"
  },
  "statistics": {
    "totalTenancyCount": 5,
    "closedCount": 4,
    "averageSurvivalMonths": 21,
    "longestSurvivalMonths": 44,
    "shortestSurvivalMonths": 11
  },
  "timeline": [
    {
      "businessName": "고기굽는집",
      "category": "한식",
      "licensedAt": "2016-03-02",
      "closedAt": "2018-11-10",
      "status": "폐업",
      "survivalMonths": 32,
      "closedAtEstimated": false
    },
    {
      "businessName": "치킨나라",
      "category": "치킨",
      "licensedAt": "2023-01-15",
      "closedAt": null,
      "status": "영업",
      "survivalMonths": 41,
      "closedAtEstimated": false
    }
  ],
  "disclaimer": {
    "dataAsOf": "2026-07-04",
    "note": "인허가 신고 기준 데이터로 실제 영업 현황과 차이가 있을 수 있습니다."
  }
}
```

- `timeline`: `licensedAt` 오름차순 정렬(과거→현재)
- `survivalMonths`: 영업중이면 개업~오늘, 폐업이면 개업~폐업(월 내림)
- `closedAtEstimated: true`: 원본 폐업일자 없어 최종수정일로 근사(프론트가 "추정" 뱃지 노출)
- `status`: `영업` | `폐업` | `휴업`
- unitId 미존재 → 404 `UNIT_NOT_FOUND`

---

## 공통 에러

HTTP 4xx/5xx 시:
```json
{ "error": "SITE_NOT_FOUND", "message": "해당 자리를 찾을 수 없습니다." }
```

| code | 상황 |
|---|---|
| SITE_NOT_FOUND | pnu 없음 |
| UNIT_NOT_FOUND | unitId 없음 |
| INVALID_QUERY | query 누락/공백 |
| INTERNAL_ERROR | 서버 오류 |

---

## 계약 고정 규칙

- 모든 조회 응답에 `disclaimer` 상시 포함(누락 금지).
- `disclaimer`는 화면에 반드시 노출(심사 방어선).
- 프론트는 이 문서의 200 예시를 그대로 목 데이터로 쓴다.
- 백엔드는 이 문서의 필드명·타입을 계약 테스트로 검증한다.
- MVP 제외: 주변 밀도/개폐업 추이(소진공 API). 후속 확장.
