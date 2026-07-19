# 상권조회 API 명세 v2 (공식 활용가이드 원문 확정)

소상공인시장진흥공단_상가(상권)정보 OpenAPI 활용가이드(2025.6) 원문을 직접 읽어 확정한 최종본. archive의 v1(추정 다수)을 대체.

**v1 대비 핵심 정정**: BASE_URL이 `/sdsc/`가 아니라 **`/sdsc2/`**였음. 오퍼레이션명도 이름의 함정이 있었음 — "반경내 **상권**조회"(`storeZoneInRadius`, 오퍼레이션#2)는 상권 폴리곤 경계 데이터를 주는 **다른 오퍼레이션**이고, 우리가 실제로 써야 하는 건 "반경내 **상가업소**조회"(`storeListInRadius`, 오퍼레이션#10)임. "상권조회"와 "상가업소조회"는 이름이 비슷해도 완전히 다른 스키마다.

## 1. 신청·인증

- 발급처: 공공데이터포털(data.go.kr), 데이터셋 "소상공인시장진흥공단_상가(상권)정보"
- **BASE_URL(확정): `http://apis.data.go.kr/B553077/api/open/sdsc2`**
- 인증: `serviceKey` 쿼리 파라미터
- 데이터 포맷: `type=xml` 또는 `type=json`
- 응답에 항상 `stdrYm`(기준년월, 예: 202503) 포함 — 스냅샷 시점 명시
- 평균응답시간 500ms, 초당 최대 트랜잭션 30tps (공식 문서 명시치)
- 업종분류 체계(2023.03 개편 이후): 대분류(2자리, 예 I2=음식) · 중분류(4자리, 예 I201=한식) · 소분류(6자리, 예 I20102=국/탕/찌개류)

## 2. 사용 오퍼레이션 (2개, 이름 함정 주의)

| 오퍼레이션 번호 | 국문명 | 영문명 | 우리 용도 |
|---|---|---|---|
| 8 | 행정동 단위 **상가업소** 조회 | `storeListInDong` | 히스토리 보강(층/호/업종) — 적재 시 1회 |
| 10 | 반경내 **상가업소** 조회 | `storeListInRadius` | marketInfo.sameCategoryNearbyCount — 실시간 |

**쓰지 않는 유사 오퍼레이션**(혼동 주의): #1 지정상권조회, #2 반경내 **상권**조회(`storeZoneInRadius`), #3 사각형내 상권조회, #4 행정구역단위 상권조회 — 전부 상권(商圈) 폴리곤 경계 데이터라 우리 도메인과 무관. 코드에서 URL 오타로 `storeZoneInRadius`를 쓰면 완전히 다른 응답 스키마가 와서 파싱이 깨진다.

### 2.1 행정동 단위 상가업소 조회 — `GET /storeListInDong`

Call Back URL: `http://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong`

**요청**

| 파라미터 | 항목크기 | 필수 | 샘플 | 설명 |
|---|---|---|---|---|
| servicekey | 100 | 필수 | — | 인증키(URL Encode) |
| divId | 8 | 필수 | `adongCd` | 시도=`ctprvnCd`, 시군구=`signguCd`, 행정동=`adongCd` |
| key | 8 | 필수 | 행정동코드 | divId에 대응하는 코드값 |
| indsLclsCd | 8 | 옵션 | I2 | 대분류 필터 |
| indsMclsCd | 8 | 옵션 | I201 | 중분류 필터 |
| indsSclsCd | 8 | 옵션 | I20102 | 소분류 필터 |
| numOfRows | 4 | 옵션 | 최대 1000 | 페이지당 건수 |
| pageNo | 4 | 옵션 | 1 | 페이지 번호 |
| type | 4 | 옵션 | xml/json | 데이터유형 |

### 2.2 반경내 상가업소 조회 — `GET /storeListInRadius`

Call Back URL: `http://apis.data.go.kr/B553077/api/open/sdsc2/storeListInRadius`

**요청**

| 파라미터 | 항목크기 | 필수 | 샘플 | 설명 |
|---|---|---|---|---|
| servicekey | 100 | 필수 | — | 인증키 |
| radius | 4 | 필수 | 500 | 미터 단위, **최대 2000m** |
| cx | 22 | 필수 | 127.375... | 중심 경도(WGS84) |
| cy | 22 | 필수 | 36.322... | 중심 위도(WGS84) |
| indsLclsCd/indsMclsCd/indsSclsCd | 8 | 옵션 | I2/I201/I20102 | **서버 측 업종 필터** — 클라이언트에서 필터링 안 해도 됨(v1 설계보다 효율적) |
| numOfRows/pageNo/type | — | 옵션 | — | 상동 |

**설계 변경 시사점**: `indsSclsCd` 파라미터로 서버가 직접 필터링해주므로, marketInfo.sameCategoryNearbyCount 계산 시 "전체 반경조회 후 클라이언트에서 indsSclsNm 비교"가 아니라 **요청 시점에 대상 업종의 indsSclsCd를 넘겨서 필터된 결과의 totalCount를 그대로 쓰는 게 더 정확하고 빠르다.** `spec/sangga_client.py`·`backend-spec.md` 6.1절 반영 필요(하단 6장).

## 3. 응답 스키마 (공식 원문 확정)

```xml
<response>
  <header>
    <description>소상공인시장진흥공단 반경내 상가업소정보</description>
    <columns>상가업소번호,상호명,...</columns>
    <stdrYm>202503</stdrYm>
    <resultCode>00</resultCode>
    <resultMsg>NORMAL SERVICE</resultMsg>
  </header>
  <body>
    <items>
      <item> ... </item>
    </items>
    <numOfRows>2</numOfRows>
    <pageNo>1</pageNo>
    <totalCount>13</totalCount>
  </body>
</response>
```

**확정**: `numOfRows`/`pageNo`/`totalCount`는 `body` 하위, `items`와 형제 노드. JSON도 동일 구조(`body.totalCount`, `body.items[]`)로 매핑됨 — `spec/sangga_client.py`가 이미 이 구조를 정확히 가정하고 있었음(우연히 맞았던 것, 이번에 원문으로 확인됨).

## 4. 응답 필드 전체 (39개, 원문 그대로) — 우리가 쓰는 6개 표시

| 필드 | 국문명 | 크기 | 필수 | 채택 |
|---|---|---|---|---|
| bizesId | 상가업소번호 | 20 | 필수 | 매칭키(응답 미노출) |
| bizesNm | 상호명 | 500 | 필수 | merge.py 매칭키 |
| brchNm | 지점명 | 500 | 옵션 | |
| indsLclsCd/Nm | 상권업종대분류 | 8/100 | 필수 | |
| indsMclsCd/Nm | 상권업종중분류 | 8/100 | 필수 | |
| indsSclsCd/Nm | 상권업종소분류 | 8/100 | 필수 | industryDetail 소스 |
| ksicCd/Nm | 표준산업분류 | 8/100 | 옵션 | |
| ctprvnCd/Nm | 시도 | 5/50 | 옵션 | |
| signguCd/Nm | 시군구 | 5/50 | 옵션 | |
| adongCd/Nm | 행정동 | 20/50 | 옵션 | (요청 key로도 사용) |
| ldongCd/Nm | 법정동 | 20/50 | 옵션 | |
| lnoCd | PNU코드 | 20 | 옵션 | (참고용, 우리 PNU는 인허가DB가 원천) |
| plotSctCd/Nm | 대지구분 | 1/10 | 옵션 | |
| lnoMnno/Slno | 지번 본/부번 | 22 | 옵션 | |
| lnoAdr | 지번주소 | 300 | 옵션 | merge.py 매칭키 |
| rdnmCd/rdnm | 도로명 | 20/500 | 옵션 | |
| bldMnno/Slno | 건물 본/부번 | 22 | 옵션 | |
| bldMngNo | 건물관리번호 | 50 | 옵션 | |
| bldNm | 건물명 | 500 | 옵션 | |
| rdnmAdr | 도로명주소 | 300 | 옵션 | |
| oldZipcd/newZipcd | 우편번호 | 6/5 | 옵션 | |
| dongNo | 동정보 | 50 | 옵션 | |
| flrNo | 층정보 | 50 | 옵션 | Unit.label 보강(우선순위 낮음, D-1 참조) |
| hoNo | 호정보 | 50 | 옵션 | 상동 |
| lon/lat | 경도/위도 | 22 | 옵션 | Site 좌표 폴백 |

미채택 필드(우편번호·건물관리번호·법정동코드 등)는 프론트 계약에 안 내려감.

## 5. 우리 도메인 응답과의 매핑

| 상가API 필드 | 우리 응답 필드 | 위치 |
|---|---|---|
| `indsSclsNm` (동단위 매칭 성공 시) | `industryDetail` | `units[]`, `timeline[]` |
| `flrNo`/`hoNo` 존재 여부 | `locationSource = "sangga_api"` | `units[]` |
| 반경조회(indsSclsCd 필터) `totalCount` | `marketInfo.sameCategoryNearbyCount` | `timeline[].marketInfo` |

## 6. spec/sangga_client.py 및 backend-spec.md 반영 필요 사항

1. **`DEFAULT_BASE_URL`을 `https://apis.data.go.kr/B553077/api/open/sdsc2`로 수정** (기존 `/sdsc` → `/sdsc2`). 이전 문서의 TODO("BASE_URL 확인 필요")가 이번에 해소됨.
2. **`fetch_dong_stores`의 엔드포인트명은 `storeListInDong`으로 이미 정확** — 변경 없음.
3. **반경조회 함수 신설 필요**: 현재 `sangga_client.py`엔 `fetch_dong_stores`만 있고 `storeListInRadius` 호출 함수가 없음. `fetch_radius_stores(cx, cy, radius, inds_scls_cd=None)` 추가, `indsSclsCd` 서버 필터 활용.
4. **marketInfo.sameCategoryNearbyCount 계산 로직 단순화**: "전체 조회 후 클라이언트 필터"에서 "indsSclsCd로 서버 필터링된 응답의 totalCount 그대로 사용"으로 변경 — 정확도·성능 둘 다 개선.
5. **radius 최대값 2000m 검증 추가**: 300m 고정값 사용 중이라 현재는 문제없으나, 향후 반경 조정 시 상한 체크 필요.

## 7. 스코프 밖 (원문에서 확인, 명시적으로 안 쓰는 것)

1) 지정상권조회, 2) 반경내상권조회(storeZoneInRadius), 3) 사각형내상권조회, 4) 행정구역단위상권조회, 5) 단일상가업소조회, 6) 건물단위조회, 7) 지번단위조회, 9) 상권내상가업소조회, 11)~15) 사각형/다각형/업종별/수정일자기준/변경요청, 16)~19) 업종·행정구역 코드조회 — 전부 원문 목차에 존재하나 이번 두 용도(#8, #10)에 불필요.

## 8. 원본 문서

`소상공인시장진흥공단_상가_상권_정보_OpenApi_활용가이드.hwp`(2025.6). hwp5txt/hwp5html로 텍스트·표 추출해 본 문서 작성. 표 구조는 hwp5html 변환 후 파싱(순수 텍스트 추출은 `<표>` 태그만 남고 내용이 소실됨 — 향후 유사 hwp 문서는 hwp5html 경유 필수).
