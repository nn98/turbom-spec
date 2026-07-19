# CHANGELOG

작업 스펙(Claude Code가 실제 참조하는 4개 파일: `api-spec.md`, `frontend-spec.md`, `backend-spec.md`, `schema.sql`)의 버전 이력. 2026-07-09부터 **파일명 고정 + 이 로그로 이력 관리** 방식으로 전환. 그 이전(v1·v2)은 파일 자체를 삭제해서 원문이 남아있지 않음 — 델타 서술은 `의사결정-기록.md`가 유일한 기록.

로컬 저장 경로(`D:\Dev\_Woowahan-Techcourse\woowaTon`) 루트는 git 미관리이므로, 저장할 때마다 `archive/YYYY-MM-DD/`에 스냅샷을 남기고 이 로그에 한 줄 추가하는 걸 권장.

## 왜 이 방식으로 바꿨나

애초에 `api-spec-v2.md` → `api-spec-v3.md`처럼 파일명에 버전을 접미사로 붙이고, 옛 파일은 "혼선 방지"로 삭제하는 방식을 썼음. 문제는 둘이 상충함 — 접미사 버저닝의 존재 이유가 이력 보존인데, 옛 파일을 지우면 이력이 안 남음. 게다가 `backend-spec.md`는 접미사 없이 계속 같은 파일을 덮어써서 스펙 4개끼리 버저닝 방식 자체가 달랐음. 로컬 루트가 git 밖이라는 게 확인되면서, 파일명이 매번 바뀌면 다른 문서들의 상호 참조(`api-spec.md를 참조하라` 같은 문장)가 매번 깨지는 문제도 있었음 — 실제로 v3 전환 때 기획서 원본이 옛 파일명을 그대로 가리키고 있었고, 심지어 v2 시점의 설계(neighborhood)를 그대로 서술하고 있던 게 이번에 발견돼 정정함.

## 이력

### 2026-07-09 — 캐노니컬 전환 + marketInfo 정정 스냅샷 (archive/2026-07-09/)

- 파일명에서 버전 접미사 제거: `api-spec-v3.md`→`api-spec.md`, `frontend-spec-v3.md`→`frontend-spec.md`, `schema-v3.sql`→`schema.sql`, `10-backend-spec.md`→`backend-spec.md`
- 내용상 실질 버전은 "v3"에 해당 — 스크린샷 기반 정정 완료 상태(아래 참조)
- 기획서 원본(`우아한바톤-넥스트스텝-기획-v0.3.md`)이 이 정정 이전(v2 설계: neighborhood 건물상세) 내용을 그대로 담고 있던 걸 발견, marketInfo 기준으로 동기화

### (소급 기록) v2 → v3 — marketInfo 위치·필드 정정

- 계기: 실제 구현 화면 스크린샷 확인
- 변경: `GET /api/sites/{pnu}`의 `neighborhood` 객체 제거 → `GET /api/units/{unitId}`의 `timeline[].marketInfo`로 이전
- 필드 재정의: 6필드 중 `sameCategoryNearbyCount`만 실값(상가API), 나머지 5필드(전용면적/보증금/월세/권리금/유동인구/공실률)는 `isPlaceholder:true` 목업으로 확정
- DDL: `neighborhood_snapshot`(site-level) 폐기 → `tenancy_market_info`(이력 단위) + `site_radius_store_cache` 신설
- 근거: `의사결정-기록.md` 5장·6장

### (소급 기록) v1 → v2 — 물건(Unit) 계층 도입 + 상권정보 반영

- Site-Tenancy 2계층 → Site-Unit-Tenancy 3계층으로 확장(D-U1: 지번 접두사 수집 + 상세주소/영업기간겹침 분리 규칙)
- 상가API 보강 필드(industryDetail/locationSource/enrichmentSource) 도입
- 지오코딩 VWorld, 지도 react-leaflet, 스타일 Tailwind 확정(D-GEO/D-MAP/D-STYLE)
- 원문 파일(`00-api-contract-v1.md`, 구 `api-spec.md`, 구 `frontend-spec.md`, 구 `schema.sql`)은 삭제되어 복구 불가. 델타만 `의사결정-기록.md` 3장에 서술로 남음

## 앞으로 저장할 때

1. 수정 전 현재 파일을 `archive/YYYY-MM-DD/`에 복사(스냅샷)
2. 캐노니컬 파일(`api-spec.md` 등)을 직접 수정
3. 이 CHANGELOG에 날짜+요지 한 단락 추가
4. 서로 다른 스펙 파일이 이번 변경으로 어긋나지 않는지 교차 확인(이번에 기획서-API계약 불일치를 뒤늦게 발견한 사례 참고)
