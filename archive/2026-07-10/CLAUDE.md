# CLAUDE.md — 넥스트스텝(가칭) 프로젝트 컨텍스트

2026 우아한바톤 해커톤 MVP. 이 파일은 루트 진입점이다. 세부는 아래 파일맵의 각 문서를 참조하되, 여기 요약만으로도 대부분의 판단이 가능하게 압축했다.

## 0. 한 줄 정의

지번 단위 상가 자리의 개업–폐업 이력을 보여주는 예비창업자용 입지 실사 도구. 중고차 사고이력 조회의 상가 버전.

## 1. 행사·팀 조건

- 2026-07-10(금) 하루, 배민스타트업스퀘어 A동(경기 성남시 수정구 금토동 405-1 인근, 판교 제2테크노밸리)
- 백엔드 개발자 4인, 자유 창업 아이템, 사전개발 허용(핵심기능은 당일 개발)
- 배포: 프론트 Vercel, 백엔드 Railway. 데이터축: 성남시 수정구 + 분당 일부

## 2. 스택

React 18 + Vite + TS + React Router + TanStack Query + Tailwind + react-leaflet(OSM 타일) / Spring Boot 3 + JPA + PostgreSQL(Railway)

## 3. 파일맵 (루트 기준)

**2026-07-09 6차 개편**: 현재 적용 중인 최신 스펙만 `spec/`에 모으고, 버전 접미사가 붙었던 옛 파일·`files`/`files0`/`files1`(예전 계약·스키마 스냅샷)는 전부 `spec_before/`로 옮겼다. 원본 CSV는 `data_uncleaning/`에 있다(전부 미정제 raw — 스키마가 `spec/` 문서와 다를 수 있음, §9 참조).

| 경로 | 역할 |
|---|---|
| `spec/api-spec.md` | **상위 계약**. 3엔드포인트(search/site/unit) 요청·응답 스키마. 다른 모든 구현의 기준 |
| `spec/frontend-spec.md` | 프론트 단독 완결 명세. 목(mock) 데이터 포함, 백엔드 없이 3화면 전환 가능 |
| `spec/backend-spec.md` | 백엔드 단독 명세. 적재 파이프라인, 정제 규칙, 엔티티, 상권보강 로직 |
| `spec/schema.sql` | DDL. Site—Unit—Tenancy 3계층 + 보강 필드. marketInfo는 테이블 없음(실시간 API+인메모리 캐시, §5) |
| `spec/의사결정-기록.md` | 왜 이렇게 됐는지의 전체 근거(검증 로그, 설계 판단, 정정 사유). 재조사 방지용 |
| `spec/CHANGELOG.md` | 스펙 파일 버전 이력 + 저장 규칙(archive 스냅샷) |
| `spec/상권조회-API-명세.md` | 상가(상권)정보 API 공식 활용가이드(hwp 원문) 기반 확정본. BASE_URL·오퍼레이션·응답스키마 |
| `spec/인허가-데이터-필드명세-v4.md` | 인허가 원본 컬럼 → 도메인 필드 매핑. `spec/데이터_예시.csv`(19컬럼, 20행 예시)가 이 구조의 실례 |
| `spec/sangga_client.py`, `spec/test_client.py` | 상가API 보강 로직의 파이썬 참조 구현. Java로 이식 대상 |
| `spec_before/` | 예전 버전 스펙·계약 전부(구 파일명 그대로 보존, 참고용). 지금은 안 씀 |
| `ingestion/` | Node 시드 변환 파이프라인. **구버전 스키마 기준이라 현재 `spec/schema.sql`과 컬럼이 어긋남** — 그대로 신뢰 금지, §9 참조 |
| `data_uncleaning/` | 원본 raw CSV 모음(성남시 전역, 여러 소스). 컬럼 구조가 제각각이라 적재 전 개별 검증 필요 |
| `우아한바톤-넥스트스텝-기획-v0.3.md`(`spec_before/files1/`에 있음) + PDF | 제출용 기획서(심사 방어 논리 포함). **v0.3 문서가 최신 스펙 반영했는지 재확인 필요** |
| 기타 PDF(원페이저·와이어프레임 등) | 발표·공유용 보조자료, 구현 스펙 아님 |

**작업 시 우선순위**: `spec/api-spec.md`가 깨지면 다른 모든 게 깨진다. 프론트/백엔드 변경이 계약과 어긋나면 `spec/api-spec.md`를 먼저 고치고 나머지를 맞춘다.

## 4. 확정된 아키텍처

계층: `Site(자리, pnu) 1—N Unit(물건, unitId) 1—N Tenancy(이력)`

엔드포인트 3개, 고정:
- `GET /api/sites/search?query=` — 랜딩 검색
- `GET /api/sites/{pnu}` — 건물 상세(물건 목록만, 상권정보 없음)
- `GET /api/units/{unitId}` — 물건 상세(타임라인+통계+이력별 marketInfo)

## 5. 데이터 소스 원칙 — 절대 섞지 않는다

| 소스 | 역할 | 반영 위치 |
|---|---|---|
| 인허가정보(localdata) | 자리·물건·**히스토리 원천** | `timeline[]`, `statistics` |
| 상가API(동 단위 매칭) | 히스토리 **보강**(층/호/업종) | `units[].industryDetail` 등 |
| 상가API(반경조회) | **주변 같은업종 개수만** | `timeline[].marketInfo.sameCategoryNearbyCount` |
| 없음(미확보) | 임대차·유동인구·공실률 | `marketInfo`의 나머지 5필드, 영구 목업 |

## 6. marketInfo — 가장 헷갈리기 쉬운 지점, 반드시 숙지

물건 상세 화면의 "가게 자세히 보기" 카드(이력별 선택) 필드 6개 중:

- **`sameCategoryNearbyCount`만 실값**(상가API 반경조회, 실패 시 null)
- **나머지 5개(`leaseAreaSqm`, `depositKrw`, `monthlyRentKrw`, `keyMoneyKrw`, `dailyFloatingPopulation`, `vacancyRatePercent`)는 확정적으로 소스 없음.** 국토부 상가 매매실거래가 API는 존재하나 지번 단위 조회 불가·지번 마스킹으로 못 씀. 상가임대차 확정일자는 오픈API가 아니라 세무서 서면 민원 절차라 자동화 불가. **이 5필드에 대한 신규 API 연동을 시도하지 말 것** — 상수 목업 + `isPlaceholder:true`로 응답, 프론트는 "실 데이터 연동 전 예시값입니다" 캡션 상시 노출.

이 구조는 v2에서 잘못 설계했다가(건물상세의 site-level `neighborhood` 패널) 실제 화면 스크린샷으로 정정된 결과다. 스크린샷이 스펙 문서보다 우선한다는 원칙으로 바뀐 사례 — 상세는 `의사결정-기록.md` 5장.

## 7. 물건(Unit) 분리 규칙 — D-1

인허가 raw엔 층/호가 거의 없음. 규칙: 지번 접두사로 자리 내 전체 레코드 수집 → 상세주소 있으면 그 값으로 분리, 없으면 **영업기간 구간 겹침(interval overlap)**으로 분리(동시 영업=다른 물건, 순차 영업=같은 물건 히스토리). `locationSource` 필드로 출처 구분: `license`/`sangga_api`/`overlap_inferred`.

## 8. 상가API 사용 원칙

- 조회는 **동 단위로 묶어서**(`storeListInDong`) — PNU 개별 호출은 쿼터(개발계정 일 1,000건) 즉시 소진
- 조인(매칭)은 **지번+상호명 정확 일치**로만 — prefix 매칭은 과합침 위험
- 지오코딩은 VWorld(국토부 계열, 무료)
- 참조 구현: `spec/sangga_client.py`(페이지네이션·재시도, BASE_URL `/sdsc2/` 확정), `spec/test_client.py`. Java 이식 시 분기 로직 그대로 포팅. 오퍼레이션 이름 함정 주의: "반경내 상권조회"(`storeZoneInRadius`)와 "반경내 상가업소조회"(`storeListInRadius`)는 다른 오퍼레이션 — 우리가 쓰는 건 후자(상세: `spec/상권조회-API-명세.md`)

## 9. 아직 안 된 것 (다음 액션)

- **`data_uncleaning/`의 raw CSV들이 `spec/schema.sql`이 가정하는 19컬럼(category/subCategory 분리, 폐업일자 실컬럼) 구조와 다 다름** — 대용량(9.8만행) 파일엔 폐업일자 컬럼 자체가 없고, 카테고리분리+폐업일자 둘 다 있는 파일은 `spec/데이터_예시.csv`(20행 예시)뿐. 실규모 적재 파이프라인은 이 불일치를 먼저 해소해야 함(별도 작업, 백엔드 서버 구현과는 분리)
- **`ingestion/`(Node 파이프라인)은 구버전 스키마 기준**(`category_code` 단일 컬럼, `unit_statistics`/`site_statistics` 테이블 등 현재 `spec/schema.sql`에 없는 구조) — 포팅 없이 그대로 못 씀
- 성남 수정구 전체 인허가 파일의 좌표(x,y) 채움률 미검증(R-A). 지오코딩 폴백이 실제로 얼마나 필요한지 실측 안 됨
- Spring Boot 백엔드 구현 진행 중(이 세션)
- 상가API 서비스키 확보됨. 이 세션 환경은 apis.data.go.kr 네트워크 차단으로 mock까지만 완결, 실호출은 Railway 배포 후 검증
- 행정동코드(adongCd) 정확값 미확정 — 법정동코드와 다를 수 있음

## 10. 팀 분업 (제안, 확정 아님)

- A 파이프라인: 다운로드→정제→물건분리→적재
- B 도메인·조회: 엔티티, API 3종, marketInfo 조립
- C 연동·인프라: 상가API 클라이언트(`spec/sangga_client.py` 이식), VWorld 지오코딩, Railway 배포
- D 프론트·발표: 3화면, 발표자료

## 11. 문서 관리 규칙

작업 스펙 4개(`spec/api-spec.md`/`spec/frontend-spec.md`/`spec/backend-spec.md`/`spec/schema.sql`)는 파일명 고정, `spec/` 아래에 둔다. 예전 버전은 지우지 말고 `spec_before/`에 원래 파일명 그대로 보존. 수정 시 `CHANGELOG.md`에 한 줄 추가. 이 로컬 저장소 루트는 git 미관리라(하위 프로젝트 폴더만 git) 파일 자체가 유일한 이력이다 — 덮어쓰기 전 `spec_before/`에 스냅샷 필수. 상세 규칙은 `spec/CHANGELOG.md` 참조.

## 12. 스펙 간 정합성 체크리스트 (변경 시마다)

지난번 실수: 화면 구조를 정정(v2→v3)했는데 기획서 원본이 예전 설계를 그대로 서술하고 있어서 뒤늦게 발견함. 앞으로 `spec/api-spec.md`를 바꾸면 다음을 같이 확인:

- [ ] `spec/frontend-spec.md`의 타입·목데이터가 새 필드를 반영하는가
- [ ] `spec/backend-spec.md`의 엔티티·엔드포인트 표가 일치하는가
- [ ] `spec/schema.sql`이 새 필드의 컬럼을 갖는가
- [ ] 기획서(우아한바톤-넥스트스텝-기획-*.md, `spec_before/files1/`)의 API/도메인모델 섹션이 뒤처지지 않았는가
- [ ] `spec/의사결정-기록.md`에 변경 사유가 남았는가
