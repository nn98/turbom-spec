# CHANGELOG

작업 스펙(Claude Code가 실제 참조하는 4개 파일: `api-spec.md`, `frontend-spec.md`, `backend-spec.md`, `schema.sql`)의 버전 이력. 2026-07-09부터 **파일명 고정 + 이 로그로 이력 관리** 방식으로 전환. 그 이전(v1·v2)은 파일 자체를 삭제해서 원문이 남아있지 않음 — 델타 서술은 `의사결정-기록.md`가 유일한 기록.

2026-07-19(17차)부터 이 파일은 별도 저장소 `nn98/turbom-spec`(public)에서 관리한다. `server`(`turbom-server`)·`ter-view`(`turbom-client`) 리포는 각자 `../turbom-spec/`을 상대경로로 참조하고, 더 이상 `spec/` 사본을 자체 보관하지 않는다. 저장할 때마다 `archive/YYYY-MM-DD/`에 스냅샷을 남기고 이 로그에 한 줄 추가하는 관례는 그대로 유지.

## 왜 이 방식으로 바꿨나

애초에 `api-spec-v2.md` → `api-spec-v3.md`처럼 파일명에 버전을 접미사로 붙이고, 옛 파일은 "혼선 방지"로 삭제하는 방식을 썼음. 문제는 둘이 상충함 — 접미사 버저닝의 존재 이유가 이력 보존인데, 옛 파일을 지우면 이력이 안 남음. 게다가 `backend-spec.md`는 접미사 없이 계속 같은 파일을 덮어써서 스펙 4개끼리 버저닝 방식 자체가 달랐음. 로컬 루트가 git 밖이라는 게 확인되면서, 파일명이 매번 바뀌면 다른 문서들의 상호 참조(`api-spec.md를 참조하라` 같은 문장)가 매번 깨지는 문제도 있었음 — 실제로 v3 전환 때 기획서 원본이 옛 파일명을 그대로 가리키고 있었고, 심지어 v2 시점의 설계(neighborhood)를 그대로 서술하고 있던 게 이번에 발견돼 정정함.

## 이력

### 2026-07-20 (20차) — 캐노니컬 문서를 실제 구현 기준으로 정정: `schema.sql` 재작성 + API 필드 3건 보강

19차 이후 진행한 전 스펙 문서 드리프트 점검(아래 하우스키핑 항목)에서 발견한 것 중, 실제 코드와
서로 다른 캐노니컬 문서끼리도 어긋나 있던 부분을 **실물 기준으로** 정정(CLAUDE.md §5의 "문서와
실물이 어긋나면 실물이 이긴다" 원칙 적용).

**`schema.sql` 전면 재작성**: v5(site/unit/tenancy_record 정규화 3테이블)는 스펙 작성 단계의
설계였고, 실제 구현은 처음부터 단일 플랫 테이블(`licensed_business_record`, CSV 컬럼 그대로) +
조회 시점 도메인 조립(Site/Unit/Tenancy는 turbom-server가 매번 계산)으로 갔다. 이 간극이 정확히
언제 생겼는지는 이력이 없다(turbom-server 클론이 얕은 클론이라 커밋 이력 확인 불가) —
`backend-spec.md` §3이 이미 이 실제 모델을 서술하고 있었는데 `schema.sql`만 안 갱신된 채였다.
v6은 turbom-server의 실제 `src/main/resources/schema.sql`/`scripts/mysql/mysql-schema.sql`을
그대로 반영(`licensed_business_record` + 비공개 실험 테이블 `auction_case`/`auction_schedule_entry`).
상세 근거: `의사결정-기록.md` §12.

**API 스펙 변경점 — `api-spec.md`/`frontend-spec.md`, 프론트 영향 있음**:
1. `GET /api/sites/search`의 `candidates[]`에 `currentSubCategory`(string\|null) 추가 — 실제
   `ApiDtos.SiteCandidateDto`엔 있었는데 문서화가 안 돼 있었음.
2. `GET /api/sites/{pnu}`의 `units[]`와 `GET /api/units/{unitId}`의 `unit`에
   `parsedFloor`/`parsedUnitNo`/`parseConfidence` 3필드 추가 — 실제 `ApiDtos`엔 있었는데 문서화가
   안 돼 있었음. `parseConfidence`가 `"HIGH"`일 때만 나머지 두 필드·`label`의 파싱 결과를 신뢰할 것.
3. `frontend-spec.md`의 TS `SiteDetail` 타입에 `noStorefrontRegistrations`(api-spec.md는 이미
   2026-07-18부터 문서화돼 있었으나 frontend-spec.md TS 타입엔 반영 안 돼 있었음) 추가.
4. `api-spec.md`의 `GET /api/units` JSON 예시가 `category`를 `"음식_일반음식점"`(대분류_소분류
   결합 문자열)로 잘못 보여주고 있었음 — 같은 문서 바로 아래 필드 표는 애초에 `category`/
   `subCategory`를 별개 필드로 정확히 설명하고 있었고, 실제 코드도 별개 필드다. 예시만 고침.

이 중 1~3번은 실제 API 응답 필드가 바뀌는 게 아니라(이미 이렇게 나가고 있었음) **문서만 코드를
뒤늦게 따라잡는 것** — 프론트가 이미 실 API를 호출 중이라면 동작 변화 없음, 다만 `ter-view`의
`spec-drift-check.yml`이 이 커밋으로 대조 대상 필드가 늘어난 걸 감지할 수 있으니 참고.

### 2026-07-20 (하우스키핑, 번호 미부여) — 전 스펙 문서 드리프트 점검, 죽은 `spec/` 경로 참조 3건 정정

`api-spec.md`/`backend-spec.md`/`schema.sql`/`의사결정-기록.md`/frontend 계약 문서 전반을 실제
`turbom-server` 코드와 대조. 살아있는 상호참조 중 2026-07-19 스펙 통합 이전 경로(`spec/` 접두)가
안 바뀐 채 남아있던 3건을 고침(`api-spec.md`의 `spec/backend-spec.md` → `backend-spec.md`,
`frontend-spec.md`의 `spec/프론트-제작-프롬프트.md` → `프론트-제작-프롬프트.md` 2곳,
`상권조회-API-명세.md`의 `spec/sangga_client.py` → `sangga_client.py` 3곳). CHANGELOG 안의 같은
문자열은 당시 시점을 서술하는 역사적 인용이라 그대로 둠.

**같이 발견한 더 큰 필드/스키마 단위 드리프트는 20차로 정정**(위 항목 참고) — `FRONTEND-INTEGRATION-CONTRACT.md`가
자체적으로 "2026-07-10/11 시점에 멈춤"이라 밝힌 건 이번 정정과 별개(그건 이미 자기 오래됨을
인지하고 있어 그대로 둠).

집단급식소/위탁급식영업 페어링, 위치미특정 레코드(레코드 단위 판정 — §9 실측대로 카테고리 단위
아님), businessStatus/licensed_at 신뢰도(§9의 미해결 후보 중 하나를 일반화)를 다루는 `BusinessType`
도메인 설계를 브레인스토밍으로 확정. 아직 구현 전(writing-plans 단계 예정), 코드 변경 없음. 상세:
`의사결정-기록.md` §11, `server/docs/superpowers/specs/2026-07-20-business-type-domain-design.md`.

### 2026-07-20 (19차) — DB를 H2 인메모리 → MySQL로 전환 (`turbom-server`)

158만 행 규모로 커진 시드 데이터를 기동마다 재파싱하던 구조(부팅 ~90초, jar 354MB)를 MySQL 8
상시 인스턴스로 전환. `spring.sql.init.mode: never`로 앱 기동에서 시딩을 완전히 분리하고,
`scripts/mysql/load-new-chunks.sh`가 `seed_files_applied` 추적 테이블 기준으로 신규 청크만
배포 파이프라인에서 idempotent 적재. 테스트는 `src/test/resources/application.yml`에 기존 H2
설정을 그대로 복제해 전혀 안 건드림(79개 테스트 그대로 통과). 실측: 부팅 90초→9초, jar
354MB→239MB(단 191MB는 Playwright 바이너리라 이번 변경과 무관 — "jar가 수 MB로 준다"는 최초
기대는 실측으로 정정됨), MySQL 행수(1,587,341)가 H2와 일치 확인. 겸사겸사 `Java 17`→`21` 표기
정정(실제로는 이미 21로 운영 중이었으나 스펙 미반영 상태였음). 커밋: `turbom-server` `d1bff4b`.
상세: `의사결정-기록.md` §10, `backend-spec.md` §7.

### 2026-07-19 (미해결 기록 — 번호 미부여, 코드 변경 없음) — 담배소매업 `licensed_at` 신뢰성 이슈

실사례(`4113111600002700009-U1`, 씨유 성남대왕판교로점)에서 `licensed_at`이 브랜드 런칭연도보다
훨씬 이른(1999년, CU는 2012년~ 브랜드) 27년짜리 단일 테넌시가 뜨는 걸 발견·조사. 담배소매업은
실제 운영 상호가 바뀌어도 인허가가 승계돼 날짜가 승계 이전 시점을 가리키는 경우가 흔함(브랜드
런칭연도보다 이른 비율 씨유 10.1%·GS25 5.6%·이마트24 5.2% 실측). `NoStorefrontSubCategories`에
카테고리 통째로 추가하는 방향을 검토했다가 **기각**(84.5%가 정상 개별 점포라 카테고리 배제는
과함, 애초에 "층/호 없음" 기준이 겨냥한 문제가 아님) — 레코드 단위 핸들링 방법이 아직 없어 코드
변경 없이 조사 결과만 기록. 상세: `의사결정-기록.md` 9장.

### 2026-07-19 (18차) — 경매 수집기 라이브 검증·수정 완료 + 테스트 힙 상향 (`turbom-server`)

16차에서 "라이브 검색 결과 0건"으로 남겨뒀던 문제를 이 세션에서 실제로 브라우저(claude-in-chrome)로
`courtauction.go.kr`을 직접 조작해가며 원인 4가지를 전부 찾아 수정. 최종적으로 성남시 수정구
상업용 매물 **5건을 실제로 수집**해서 검증 완료(`CourtAuctionCollectorManualCheck` 수동 실행 결과,
주소·감정가 등 실값 확인). 커밋: `turbom-server` `493e0cc`.

**발견·수정된 버그 4개**(전부 `CourtAuctionCollector.java`/`AuctionListParser.java`):

1. **`page.waitForLoadState()`가 이 사이트에서 아무 효과가 없었음** — courtauction.go.kr의
   매각예정물건 검색은 AJAX로만 동작하고 실제 브라우저 네비게이션이 없음(검색해도 URL이 그대로,
   claude-in-chrome으로 직접 확인). `waitForLoadState()`는 최초 페이지 로드 시점에 이미 만족된
   상태라 검색 결과를 전혀 기다리지 않고 즉시 통과 — 실제 렌더된 콘텐츠 텍스트를 기다리는 방식으로
   교체.
2. **`AuctionListParser.ITEM_LINE` 정규식이 공백을 기대했는데 실제 페이지는 탭 문자로 구분**
   (`2025타경51795<TAB>1<TAB>`) — 게다가 항목번호 뒤 트레일링 탭이 정규식의 줄끝(`$`) 앵커를 깨서
   매칭 자체가 실패. `\s+`로 변경.
3. **목록→상세 진입 클릭 대상이 틀렸음** — 원래 코드는 `"{사건번호} 선택"` 텍스트를 클릭했는데,
   이건 행 선택용 체크박스 라벨이었고 실제 상세 이동 링크는 "소재지 및 내역" 칸의
   `<a onclick="moveDtlPage(N)">`(행 인덱스 기반)이었음. 인덱스 기반 클릭으로 교체.
4. **숨김 접근성 캡션이 텍스트 대기를 오염시킴** — 이 사이트의 모든 그리드에는 스크린리더용
   `<caption>`이 있는데 그 안에 모든 컬럼 라벨이 전부 텍스트로 들어있어서(예: "청구금액"도 포함),
   `text=라벨` 형태의 대기가 이 숨겨진(영원히 안 보이는) 캡션에 매칭돼 타임아웃까지 멈춰버림 —
   `.last()`로 실제 렌더된 요소를 타겟하도록 수정. `page.goBack()`도 상세 진입이 실제 네비게이션이
   아니라 안 먹혀서, 건마다 검색을 처음부터 재실행하는 방식으로 변경.
5. (버그는 아니지만 같이 발견) 그리드 위젯이 라벨/구조는 즉시 렌더하고 실제 셀 값은 별도의
   지연된 데이터 바인딩으로 채워서, 라벨 텍스트 등장만으론 값 로딩 완료를 보장 못함 — 고정 지연
   2초 추가로 완화(더 나은 신호가 없어 이번엔 이렇게 처리, 개선 여지 있음).

**테스트 힙 상향**: `pom.xml`의 `surefire.jvm.args`를 `-Xmx768m` → `-Xmx4096m`으로 변경. 16차에서
기록한 대용량 시드(약 158만 행) OOM 문제의 실제 원인 확인 — 여러 `@DataJpaTest`/`@SpringBootTest`
컨텍스트가 스택되며 힙이 부족해지는 것으로, 단일 클래스는 2048m로 충분하지만 전체 스위트는
4096m에서 안정적으로 통과(14클래스·79테스트 전부 green). 이 값은 테스트 전용이라 배포 워크플로우의
JVM 설정과 무관(별도 확인 완료).

### 2026-07-19 (17차) — 스펙 통합: 독립 저장소 `turbom-spec`로 분리

지금까지 스펙이 4곳에 흩어져 있었다: root `spec/`(git 미관리, 사실상의 원본), `spec_before/`(구버전
보존), `server/spec/`(git 추적되지만 2026-07-10~07-16 시점에 정체된 별도 사본), `ter-view/spec/`(대부분
root와 동일하되 CHANGELOG만 독자적으로 갱신, `ter-view/CLAUDE.md`에 문서화되지 않은 비공식 전체 사본).
분산 관리 중 실제로 이력이 유실된 사례가 발견됨 — root CHANGELOG의 15차("PNU 권위 파일 조인 정정")
항목이 섹션 헤더 누락으로 16차 블록에 파묻혀 있었고(`ter-view/spec/CHANGELOG.md`에는 정상 헤더로
남아있어 대조 중 발견, 이번에 헤더 복원으로 수정), `server/spec/backend-spec.md`는 07-19 경매 스파이크
섹션이 누락된 채 방치돼 있었음.

**`ter-view/docs/spec/`는 통합 대상에서 제외**: 이건 사본이 아니라 `ter-view/CLAUDE.md`가 명시하는
공식 로컬 미러(`api-spec.md`/`frontend-spec.md` 2개만) — `.github/workflows/spec-drift-check.yml`이
매일 이 미러를 upstream과 자동 대조해 어긋나면 이슈를 여는 살아있는 장치라 그대로 둔다. 대신 그
워크플로우가 보던 upstream(`raw.githubusercontent.com/nn98/turbom-server/main/spec/*`)을
`nn98/turbom-spec`(이 저장소) 루트로 재타게팅했다 — server 쪽 삭제로 그대로 뒀으면 워크플로우가
조용히 실패했을 것.

**병합 원칙**: 최신 우선(mtime) > 내용 우선(고유하고 유효한 정보면 채택). `api-spec.md`·
`frontend-spec.md`·`backend-spec.md`·`schema.sql`은 root 버전을 그대로 채택(root가 이후 세션들의
수정을 계속 반영해 옴 — server/ter-view 사본과의 diff가 대부분 500줄 이상으로 사실상 다른 문서).
`server/spec` 고유 파일 `FRONTEND-INTEGRATION-CONTRACT.md`(영문 연동계약서, 2026-07-10/11 시점
스냅샷)는 유지하되 최신화 필요 주석 추가. 각 위치의 아카이브(root `archive/`, `spec_before/`,
`server/spec/archive/2026-07-10/`)는 전부 이 저장소 `archive/` 밑에 날짜별로 통합 — 병합 대상이
아니라 이미 확정된 스냅샷이므로 그대로 보존. (`ter-view/docs/spec/`의 2026-07-16 시점 스냅샷도
참고용으로 `archive/2026-07-16-ter-view-docs-spec/`에 남겨뒀다 — 위에서 설명한 대로 원본은 그대로
살아있고 이건 그 시점의 사본일 뿐.)

**이후 관례**: `server`·`ter-view`의 전체-스펙 사본(`spec/`)은 만들지 않고 `../turbom-spec/`을 상대경로로
참조한다(각 리포 CLAUDE.md에 명시). `ter-view/docs/spec/`처럼 특정 파일만 골라 로컬 검증용으로 미러링하는
건 계속 허용 — 그건 이번에 없앤 "전체 사본" 문제와 다른 종류다. 팀원 전원이 로컬에서
`turbom-server`·`turbom-client`·`turbom-spec`을 형제 폴더로 clone해 작업하는 걸 전제로 함 — 만약
나중에 GitHub에서 서버/프론트 리포만 단독 clone해야 하는 상황이 생기면 그때 git submodule로 전환
(지금은 YAGNI로 보류).

### 2026-07-19 (프론트 세션 발견사항 — 번호 미부여, 백엔드 세션 확인 대기) — 프론트에 `/updates`·`/auctions` 화면 신설, 둘 다 백엔드 API 미의존

`turbom-client` 세션이 사용자 요청("백엔드 스펙 변경점·API 변경로그 보고 + 경매물건 확인 페이지")으로 두 화면을 신설. 근거 문서: `turbom-client/docs/superpowers/specs/2026-07-19-updates-and-auctions-pages-design.md`. (원래 `server/spec/CHANGELOG.md`에 미커밋 상태로 남아있던 항목 — 2026-07-19 스펙 통합 작업 중 발견해 이 저장소로 이관.)

- **`/updates`("업데이트 소식")**: 이 CHANGELOG의 실제 항목을 사용자가 읽을 수 있는 평문으로 큐레이션해 프론트에 정적으로 하드코딩(`src/lib/updates-data.ts`). API 호출 없음 — 이 CHANGELOG가 갱신돼도 프론트가 자동으로 따라가지 않으니, 사용자에게 노출할 만한 변경(데이터 범위 확장, 표시 오류 수정 등)이 생기면 프론트 세션에 갱신을 요청하거나 직접 반영 필요. "n차" 번호는 화면에 노출하지 않음.
- **`/auctions`("경매물건 확인")**: 이 스파이크(`AuctionCase`/`AuctionScheduleEntry`, 16차)가 아직 어떤 `@RestController`에도 연결돼 있지 않아서, 프론트는 두 레코드의 필드를 1:1로 미러링한 TS 타입만 만들고 목업 데이터로 채웠다(`src/lib/api/auction.ts`). 카드마다 "예시" 배지 + "백엔드가 `api-spec.md`에 경매 엔드포인트를 먼저 추가해야 실 데이터로 전환 가능하다"는 안내 배너를 넣어둠 — **실 연동을 원하면 이 CHANGELOG 16차의 courtauction.go.kr 이용약관 이슈(제15조)가 먼저 풀려야 하고, 그 다음 `api-spec.md`에 엔드포인트·응답 스키마(`AuctionCase`/`AuctionScheduleEntry` 필드 기준)를 추가해야 프론트가 목업을 실 API 호출로 교체할 수 있다.**
- 프론트 쪽 코드 변경은 이 스펙 저장소·백엔드 레포 어디에도 영향 없음(읽기 전용으로 도메인 레코드 필드만 참고) — 이 항목은 순수 교차 기록.

### 2026-07-19 (16차) — 경매정보 수집 개발용 스파이크 추가 (`backend-spec.md`만 변경, API 계약 불변)

법원경매(courtauction.go.kr) 이력을 자리(PNU) 단위로 곁들이는 기능의 실현 가능성을 검증하는
**내부 검증 전용 스파이크**를 subagent-driven-development로 구현(6태스크, 전부 태스크별 리뷰
승인 + 최종 전체 브랜치 리뷰 승인 후 main 병합). 도메인 레코드(`AuctionCase`/`AuctionScheduleEntry`),
목록/상세 파서(이번 세션 실측 캡처 텍스트 기준 TDD), Playwright 기반 `CourtAuctionCollector`,
JPA 영속성 + 수동 트리거 서비스를 추가. 상세: `backend-spec.md` 11장,
`의사결정-기록.md` 8장, `server/docs/superpowers/plans/2026-07-19-auction-data-collection-spike.md`.

**공개 계약 변경 없음** — `api-spec.md`·`frontend-spec.md`·캐노니컬 `schema.sql`은 전혀 건드리지
않음(의도적). courtauction.go.kr 이용약관 제15조(법원행정처 동의 없는 가공/영리목적 이용 금지)가
아직 안 풀려서, 이번 구현은 어떤 `@RestController`에도 연결되지 않고 `@Scheduled`도 없는 순수
개발자-수동-트리거 코드로만 존재한다 — 프로덕션 서비스 노출은 CODEF 라이선싱 문의 또는 법원행정처
직접 동의 확인 이후로 계속 보류.

실사이트 대상 라이브 테스트(Playwright 폼 조작까지는 성공, 검색 결과는 현재 0건)는 `Test`/`Tests`/
`TestCase` 접미사를 의도적으로 피해 Maven Surefire 기본 인클루드 패턴에서 제외 — CI(`mvn test`)는
절대 실행하지 않음.

**부수 발견(이번 변경과 무관, 별도 기록만)**: 이 작업 중 `PersistenceSmokeTest` 등 기존
`@DataJpaTest`가 프로젝트 기본 힙 설정(`pom.xml`의 `surefire.jvm.args=-Xmx768m`)에서 간헐적으로
`OutOfMemoryError`를 내는 걸 발견 — main 브랜치 병합 전 상태(이번 변경 이전 커밋)에서도 동일하게
재현됨을 별도 디스포저블 워크트리로 직접 확인, `-Xmx2048m`에서도 전체 스위트 기준으로는 여전히
간헐적으로 재현(개별 테스트 클래스 단위로는 `-Xmx2048m`에서 안정적으로 통과). 대용량 시드
데이터(약 158만 행) 대비 힙 여유가 타이트해진 것으로 추정 — 이번 스파이크가 만든 문제는 아니고,
힙 설정값 자체를 올리는 별도 작업이 필요함(이번 변경 범위 밖, 미착수).

### 2026-07-18 (프론트 세션 발견사항 — 번호 미부여, 백엔드 세션 확인 대기) — 지하/B 층 파싱 누락, 동일 파싱결과인데 유닛이 안 합쳐지는 케이스

`turbom-client` 세션이 위든타워(성남시 수정구 금토동 690, `pnu 4113111600106900000`) 실데이터를 조사하며 발견한 버그 2건. 둘 다 재현 가능한 실측이라 unitId 그대로 남긴다(`curl https://turbom.duckdns.org/api/units/{unitId}`로 바로 재현 가능). (원래 `server/spec/CHANGELOG.md`에 미커밋 상태로 남아있던 항목 — 2026-07-19 스펙 통합 작업 중 발견해 이 저장소로 이관, 아직 정식 검토·번호 부여 안 됨.)

**버그 A — 지하/B 층 표기를 `AddressDetailParser`가 인식 못 함**

- `4113111600106900000-U1`: `unit.jibunAddress = "경기도 성남시 수정구 금토동 690 지1층 B113호 "` → `parsedFloor: null`, `parsedUnitNo: null`, `parseConfidence: "LOW"`, `label: "단일 점포"`
- `4113111600106900000-U2`: `unit.jibunAddress = "경기도 성남시 수정구 금토동 690 지1층 B114호 "` → 위와 동일하게 전부 `null`/`LOW`/`"단일 점포"`
- 물건 분리 자체는 정확함(B113호와 B114호가 서로 다른 유닛 `U1`/`U2`로 올바르게 나뉘어 있음) — 문제는 순전히 **라벨 표시**다. "지1층"(지하1층 약식 표기)·"B113호"(B+숫자 형태의 지하 호수)를 `parsedFloor`/`parsedUnitNo`로 뽑아내지 못해서, 서로 다른 물건인 `U1`과 `U2`가 화면에 똑같이 "단일 점포"로 보인다(어느 게 B113이고 어느 게 B114인지 라벨만으로 구분 불가).
- **제안**: `AddressDetailParser`(CHANGELOG 10차, `src/main/java/...`)에 지하 표기 패턴 추가 — `지(하)?\d*층` → 지하 N층(N 없으면 지하1층), `B\d+호` → 지하 호수로 파싱. 10차 실측 기준 `LOW` 10.8%(5,111건) 중 상당수가 이 패턴일 가능성이 있어 재생성 시 `HIGH` 비율이 유의미하게 오를 수 있음(전체 재검증 필요).

**버그 B — 같은 층·같은 호로 파싱 신뢰도 HIGH인데 유닛이 안 합쳐짐 (원본 주소 텍스트가 다르다는 이유만으로)**

같은 사이트의 GS25 편의점이 서로 다른 업종 인허가 2개(담배소매업 + 식품자동판매기업 — 편의점이 흔히 겸업 등록하는 조합, `씨유(CU)` 케이스와 동일 패턴)를 냈는데, 이번엔 **테넌시가 아니라 유닛 자체가 둘로 쪼개졌다**:

- `4113111600106900000-U3`: `unit.jibunAddress = "경기도 성남시 수정구 금토동 690"`(접미어 없음) → `parsedFloor: "1"`, `parsedUnitNo: "102"`, `parseConfidence: "HIGH"`. `timeline[0].businessName = "지에스25 위든타워점"`(담배소매업)
- `4113111600106900000-U5`: `unit.jibunAddress = "경기도 성남시 수정구 금토동 690 1층 102(일부)호 "` → `parsedFloor: "1"`, `parsedUnitNo: "102"`, `parseConfidence: "HIGH"`(U3와 완전히 동일한 파싱 결과). `timeline[0].businessName = "지에스(GS)25 위든타워점"`(식품자동판매기업)
- 둘 다 `parseConfidence: HIGH`로 **파싱 결과가 완전히 일치**하는데도 서로 다른 유닛(`U3`/`U5`)으로 남아있다 — 물건분리(D-1 규칙) 로직이 원본 주소 텍스트("690" vs "690 1층 102(일부)호", 실제로 다른 문자열)로만 그룹핑하고, 파싱이 끝난 뒤 `parsedFloor`+`parsedUnitNo`가 같으면 병합하는 후처리 단계가 없는 것으로 보인다.
- **제안**: 물건분리 단계에서 `parseConfidence: HIGH`인 레코드끼리는 원본 텍스트가 달라도 `parsedFloor`+`parsedUnitNo` 일치 시 같은 유닛으로 병합하는 후처리 규칙 추가 검토. (같은 이유로, 위 버그 A가 고쳐져 지하 호수 파싱 신뢰도가 오르면 이 병합 규칙의 적용 범위도 자연히 넓어짐 — 두 버그가 연쇄적으로 얽혀 있음.)

### 2026-07-18 (15차) — PNU 권위 파일 조인 정정 (구현 완료)

`turbom-client`(프론트) 세션이 검색결과에서 동일 자리가 다른 `pnu`로 중복 노출되는 버그를 리포트
(금토동 534-8 실사례, `license_no` 동일·`jibun_address` 텍스트 동일·`pnu`만 산여부 자리가 다름).
프론트 세션의 조사·제안은 `server/spec/CHANGELOG.md`(git 추적되지만 8개 커밋 뒤처진 별도 미러,
미커밋 상태로 방치돼 있던 걸 이번에 발견)와 `ter-view/docs/superpowers/specs/2026-07-18-site-entity-similarity-design.md`에
남아 있었음 — 백엔드 세션이 정식 검토해 이 항목으로 재정리.

**조사 결과**: "유사 항목 매칭" 문제가 아니라 **진짜 중복 행**이었음. 우리 지번 정규식 파서
(`jibun_pnu.py`)는 주소 텍스트에 "산"이 문자 그대로 있어야만 산여부=1을 판정하는데, 텍스트가
동일한 두 행의 `pnu`가 산여부만 다르다는 건 서로 다른 시점/로직으로 중복 적재됐다는 뜻. 기존
93개 청크(9만1천여 건)만 스캔해도 동일 `license_no`가 다른 `pnu`를 가진 쌍이 **1,630개** 확인됨.

**근본 원인**: `data_uncleaning/PNU(지번)기반_개폐업정보현황_성남시_10년.csv`(9.8만행, `CLAUDE.md`
§9에 "폐업일자 컬럼 없어 1차 소스로 못 씀"이라고만 기록돼 있던 파일)에 관리번호별 PNU가 이미
정확히 계산돼 있고, 그 값이 우리 legacy(사전 dedup 도입 전) 청크의 값과 일치함 — 이 권위 파일이
과거 한 번 쓰였다가 이후 잊힌 것으로 보임. 이 파일은 우리 정규식이 `UNPARSEABLE_OR_DONG_NOT_FOUND`로
포기하는 케이스의 PNU도 갖고 있어 커버리지 개선 효과도 있음. 단 `폐업일자` 컬럼이 없어(36개 컬럼
전수 확인) 전면 대체는 불가 — `license_no` 기준 조인으로 PNU만 가져오고 `closed_at`은 계속
LOCALDATA(`data/경기도`)에서 옴.

**구현**: `license_no → PNU` 조인 레이어(`server/scripts/pnu_ledger.py`, 신규)를
`parse_licensed_records.py`의 지번 정규식 계산 *앞*에 끼워 넣음(적중 시 정규식 스킵, 미스 시 기존
로직 그대로 폴백 — 서울/성남 외 경기도는 이 파일이 없어 자동으로 기존 로직 유지).
`batch_parse_licensed_records.py`에 `--ledger <path>` 플래그 추가(배치 1회 로드, 파일마다 재로드
안 함). 기존 충돌은 일회성 스크립트(`dedupe_pnu_ledger_conflicts.py`, 신규)로 권위 PNU 기준 정리 —
리뷰 과정에서 "ledger 값이 기존 어느 pnu와도 안 맞으면 전부 삭제되는데 로그가 안 남는" Important
결함을 발견해 수정(전부삭제 케이스를 별도 플래그·리포트로 남기도록 보강, 실제 실행 결과 0건).
상세 설계: `docs/superpowers/specs/2026-07-18-pnu-ledger-correction-design.md`.

**실제 실행 결과** (2026-07-18, subagent-driven-development로 구현·리뷰·적용):
- 기존 93개 청크 정리: **1,630행 삭제**(예상과 정확히 일치), ledger 미커버로 보류 9,524건(전부 서울
  쪽 — Seongnam 전용 ledger라 예상된 결과), 전부삭제(full-wipe) 0건.
- 경기도+서울 전체 재적재(`--ledger` 적용): **1,567,569건 생성**(14차의 1,514,685건보다 **52,884건
  더 많음** — ledger가 정규식이 포기했던 `UNPARSEABLE_OR_DONG_NOT_FOUND` 행을 그만큼 구제).
- 총 레코드: 1,606,457 → **1,587,341**(dedup으로 줄었지만 더 정확함). 신흥동 검색 결과가
  8,329→6,603으로 크게 줄었는데, 이게 정확히 이번 수정이 잡으려던 성남시/서울 동명 충돌
  오염분이 빠진 것.
- `mvn test` 76/76 통과(하드코딩된 카운트 3건 갱신: `PersistenceSmokeTest`/`SiteControllerTest`).

API 계약(`api-spec.md`)·스키마(`schema.sql`) 변경 없음(순수 적재 파이프라인 정정).

### 2026-07-18 (14차) — 데이터축을 서울특별시 전체 + 경기도(성남시)로 확장

`data/경기도`·`data/서울특별시`에 LOCALDATA 카테고리별 원본 195개 파일씩(총 390개, ~1.78GB) 추가
후 전량 적재. 기존 `server/scripts/parse_licensed_records.py`(단일 지역·단일 관할코드 하드코딩)를
`server/scripts/batch_parse_licensed_records.py`(신규 배치 러너)로 여러 파일·여러 지역을 한 번에
처리하도록 확장.

**스코프 확장 내용**: `SEONGNAM_GOV_CODE` 단일값 비교 → `ACCEPTED_GOV_CODES`(성남시 `3780000` +
서울 25개 구 코드 `3000000`~`3240000` + 서울시 본청 직발급 코드 `6110000`) 집합 비교로 일반화.
`REGION_FILTER` 단일 문자열 → `REGION_FILTERS`(`["성남시", "서울특별시"]`) 리스트로 일반화.

**실행 결과**: 195개 파일 × 2지역, 897MB+881MB, 약 13분, **1,514,685건 신규 적재**
(기존 91,772건 → 총 1,606,457건, `mvn test` 확인 완료).

**적재 중 발견·수정한 버그 4건**(전부 `server/scripts/` 단위테스트로 회귀 방지):
1. 자원환경 카테고리 6개 파일(원목생산업 등)에 `폐업일자` 컬럼 자체가 없어 `KeyError`로 죽던 문제 —
   `row.get("폐업일자")` 방어.
2. 지번 오기(誤記)로 본번/부번이 4자리(PNU 스펙)를 넘는 값(예: "678-14"가 "67814"로 하이픈 누락)이
   19자 초과 PNU를 만들어 DB 컬럼 제약을 깨던 문제 — `jibun_pnu.parse_pnu()`에 `bon>9999 or bu>9999`
   방어 추가.
3. 서울 스코프 추가로 짧은 동이름 충돌 발견(갈현동: 성남시 중원구 ↔ 서울 은평구, 시흥동: 성남시
   수정구 ↔ 서울 금천구, 신촌동: 성남시 수정구 ↔ 서울 서대문구) — `jibun_pnu.parse_pnu()`가 짧은
   동이름 매칭 후 바로 위 구/시 이름도 주소 텍스트에 있는지 추가 검증하도록 방어.
4. 원본 날짜 필드가 존재하지 않는 달력날짜(예: "20090229" — 2009년은 윤년 아님, 하이픈도 없는
   `YYYYMMDD` 형식)를 담고 있어 H2가 시드 스크립트 전체를 실패시키던 문제 —
   `_valid_date_or_none()`으로 `licensed_at`(필수, 무효면 행 스킵)/`closed_at`(선택, 무효면 NULL)
   각각 검증.
5. **`mvn test` 검증 중 발견 — 데이터 파이프라인이 아니라 테스트 인프라 버그**:
   `TenancyQueryServiceTest`/`SiteControllerTest`의 `@Sql` 픽스처가 id `990001`~`990701` 범위를
   "실 데이터가 절대 안 닿을 안전한 값"으로 가정하고 하드코딩했는데, 이번 확장으로 실 데이터 id가
   1,606,457까지 올라가면서 그 범위를 실제로 침범해 PRIMARY KEY 충돌로 `mvn test` 전체가 깨짐.
   처음엔 "여러 스프링 테스트 컨텍스트가 같은 이름의 H2 인메모리 DB를 공유해서 생기는 문제"로
   오판(각 컨텍스트에 랜덤 DB 이름을 주는 우회 수정을 했다가, 컨텍스트 하나만 격리해서 돌려도
   똑같이 재현되는 걸 확인하고 진짜 원인이 아님을 깨달아 되돌림) — `ScriptUtils`에 DEBUG 로그를
   켜서 어떤 INSERT가 실패하는지 직접 확인해서야 픽스처 id 충돌임을 특정함. 두 테스트 파일의
   픽스처 id를 전부 90억대(`9,900,000,000 + (기존id - 990,000)`)로 이동해 실 데이터 범위와
   영구히 분리(현재 규모 대비 ~6000배 여유, 향후 지역이 더 늘어도 안전).

**서울특별시 194→195개 파일 전부 실제 유효 데이터임을 사전 확인**: `SEONGNAM_GOV_CODE` 단일값이던
과거엔 서울 데이터가 0건으로 전량 스킵됐을 것 — 이번 일반화로 실제 반영됨.

가이드: `server/scripts/README.md` "여러 파일 한꺼번에 돌리기" 섹션.

### 2026-07-18 (13차) — 배포 스택 정정: Railway/PostgreSQL → AWS/H2 인메모리

실제 배포 방식이 Railway+PostgreSQL이 아니라 **AWS에 Spring Boot 서버 프로세스를 직접 올리고
DB는 H2 인메모리**로 확정됨(별도 관리형 DB 서버 없음). `CLAUDE.md`(§1, §2, §9, §10),
`spec/api-spec.md`(Base URL), `spec/backend-spec.md`(§7 스택·배포, 아키텍처 다이어그램,
§10 착수순서)의 Railway/PostgreSQL 언급을 전부 AWS/H2로 정정. 핵심 함의: H2 인메모리라
**서버 프로세스가 재시작되면 DB 내용도 그 시점의 `licensed-business-records-*.sql` 시드
파일 기준으로 재구성됨**(영속 디스크 스토리지 없음) — 데이터 용량 계획은 디스크가 아니라
AWS 인스턴스 RAM(JVM 힙) 기준이어야 함. `spec/frontend-spec.md`는 Vercel 배포만 언급해서
변경 없음(프론트 배포는 그대로 Vercel).

### 2026-07-18 (12차) — 무점포 전용 자리(units 0개)를 검색 결과에서 제외

11차(`noStorefrontRegistrations` 분리)의 부작용으로, 인허가 이력이 전부 무점포업종뿐인 PNU가
`units.size()==0`인 채로 검색 결과·지도 마커에 계속 노출되는 버그 발견. 사용자 실사용 리포트 3건
(금토동 390-11 "좌표가 혼자 튀어있고 실제와 다름", 436-3 "마커는 뜨는데 가게는 없음", 517-7 동일)로
확인 — 셋 다 조사해보니 자원환경/고압가스업(설비 인허가) 또는 폐업한 통신판매업만 있는 자리라
`units`가 0개였음. `SiteQueryService.search()`에서 `units`가 빈 Site를 후보 목록에서 제외하도록 수정
(`spec/api-spec.md` ① 섹션에 반영). 390-11의 "좌표가 튀어있다"는 부분은 별개로 확인 — 원본 데이터의
`road_address`가 분당구 삼평동, `jibun_address`가 수정구 금토동으로 서로 다른 구/동을 가리키는 게
원인(판교 제2테크노밸리 E11-1,2블럭이 두 동 경계에 걸쳐있는 것으로 추정). 지오코딩을 안 쓰고 원본
좌표를 그대로 쓰는 원칙(§8)상 좌표 자체는 원본 그대로가 맞고, 이번 수정으로 units가 0개라 검색/지도에
아예 안 뜨게 되므로 별도 좌표 보정은 하지 않음. 서버 코드: `SiteQueryService.java`.

### 2026-07-18 (11차) — 무점포/자가신고형 업종 분리(`noStorefrontRegistrations` 신규)

프로덕션 실사례(`4113110800105560000-U2`)에서 `단일(상세주소불명)` Unit 하나에 동물판매업·통신판매업 4건이 동시에 "영업 중"으로 뜨는 걸 발견. 원본과 대조한 결과 파싱 버그도 샵인샵도 아니고 원본 데이터 자체에 층/호가 없어서(`parse_method='NONE'`) 생긴 현상임을 확인. 전체 91,772건을 (category, subCategory)별 "층/호 없음" 비율로 전수 분석한 결과 뚜렷한 이분 구조 발견 — 통신판매업(99.5%)·방문판매업(98%)·의료기기판매(임대)업(98.3%) 등 47개 조합이 90% 이상(업종 특성상 물리적 점포 없이 신고 가능), 일반음식점(20.4%)·휴게음식점(17.5%) 등 정상 매장업종은 순수 개별 데이터 누락 수준. 이번 세션에 직접 적재한 담배소매업(84.5%)은 임계값 아래라 자동으로 정상 분류(수동 예외 불필요, 기존 도메인 지식과 일치). 완전 제외 대신 `units[]`와 분리된 `noStorefrontRegistrations[]`로 노출하기로 결정(사용자 판단: "이것도 나름의 판단근거가 될 수 있다"). `spec/api-spec.md`(`GET /api/sites/{pnu}` 신규 필드), `spec/backend-spec.md`(`Site.noStorefrontRegistrations`, `NoStorefrontSubCategories` 분류 로직)에 반영. 설계 문서: `docs/superpowers/specs/2026-07-18-no-storefront-registrations-design.md`(server 하위 git 저장소).

### 2026-07-17 (10차) — `survivalMonths` null 처리 (종료일자 없는 비영업 상태 오표시 수정)

프로덕션 실사례(`4113110800105430000-U1`)에서 `상세영업상태='취소/말소/만료/정지/중지'`인데 원본에 폐업일자가 없는 레코드가 `survivalMonths=110`(licensedAt~오늘로 계산)로 나와 "9년째 영업 중"처럼 보이는 문제 발견. `Tenancy.survivalMonths()`가 status를 안 보고 `closedAt`이 null이면 무조건 오늘까지로 계산했던 게 원인 — 이 전제는 `status=영업/정상`일 때만 유효한데, 취소/말소/휴업/제외 등은 "종료됐지만 원본에 날짜만 없는" 경우라 다르게 처리해야 함. `status != 영업/정상`이고 `closedAt == null`이면 `survivalMonths`가 `null`을 반환하도록 수정(`ApiDtos`는 이미 `Integer`로 선언돼 있어 API 계약 변경 없음). `UnitStatistics.closedCount`는 이런 레코드도 "폐업 이력"으로는 카운트하되 평균/최장/최단 계산에서는 제외. 실측: 전체 91,772건 중 2,221건(2.3%, 취소/말소류 1,821 + 제외/삭제/전출 263 + 휴업 117 + 폐업인데 날짜없음 20)이 해당. `spec/backend-spec.md` §3.3(Tenancy/TenancyPeriod 정의, 5버킷 status로 갱신 — 이 부분은 원래 3버킷으로 서술돼있던 걸 발견해 같이 정정)과 `spec/api-spec.md`의 `timeline[].survivalMonths` 필드 설명에 반영. 서버 코드: `Tenancy.java`, `UnitStatistics.java`.

### 2026-07-10 (9차) — `schema.sql` 멱등화 (다중 테스트 컨텍스트 DB 공유 충돌 수정)

`server` 백엔드에서 `mvn test` 전체 스위트 실행 시 `SiteControllerTest`(`@SpringBootTest`+`@AutoConfigureMockMvc`)가 `Table "SITE" already exists`로 실패하는 문제 발견. 원인: `application.yml`이 이름 있는 인메모리 H2(`jdbc:h2:mem:nextstep;DB_CLOSE_DELAY=-1`)를 쓰는데, 애노테이션 조합이 다른 `SiteControllerTest`와 `TenancyQueryServiceTest`가 Spring에서 서로 다른 ApplicationContext로 뜨면서 같은 이름의 DB를 공유함. `DB_CLOSE_DELAY=-1`이 DB를 계속 살려두므로, 두 번째 컨텍스트가 뜰 때 `spring.sql.init.mode: always`가 `schema.sql`을 재실행하다가 이미 존재하는 테이블과 충돌. 자식→부모 역순 `DROP TABLE IF EXISTS ... CASCADE` 4줄을 파일 맨 앞에 추가해 재실행에 멱등하도록 수정(테이블 정의·인덱스는 무변경). `server/src/main/resources/schema.sql`에 동일 수정 반영, `mvn test` 전체 재통과 확인. 수정 전 스냅샷: `spec_before/schema-2026-07-10-before-idempotent-drop.sql`.

### 2026-07-10 (8차) — 프론트 제작 프롬프트 v2 병합 (`spec/프론트-제작-프롬프트.md`)

세 소스를 병합: ① 기존 v1 프롬프트, ② `frontent-UI-design-prompt.md`(Loveable용 디자인 프롬프트, 이번에 `spec_before/`→`spec/`로 승격), ③ nextstep-client 실 검색화면(`Home.tsx`+`Map.tsx`) 리버스 프롬프팅.

- 구조는 v1 유지, 디자인 프롬프트의 보고서 페이지 11섹션 순서(Header→Summary→종합분석→주변상권분석→위험도→인사이트→운영이력→통계→가게자세히보기→체크리스트→CTA)로 확장
- `## 검색 페이지`는 디자인 프롬프트의 다단계 서술 대신 nextstep-client `Map.tsx`(지도+플로팅패널+세그먼트탭) 리버스 프롬프팅으로 교체 — 사용자 확정
- **주변상권분석/체크리스트가 요구하는 확장 필드(업종구성/경쟁도/전체점포수/최근개업수/상권특징)는 `api-spec.md`에 없음** — 실측 불가로 이미 확정된 사실(§6). 백엔드 확장 없이 프론트 전용 mock 타입(`MarketAnalysisMock`)으로 분리, "예시" 캡션 필수. 차후 기능 보강 대상으로 명시
- nextstep-client `insights.ts`(riskLevel/repeatCategoryFailure/signals/diagnosis/checklist) 포팅 명시 — 사용자 확정, 새로 작성하지 않음
- shadcn/ui 신규 채택(디자인 프롬프트 따름) — 사용자 확정. `npx shadcn@latest init -t vite` 기준 설치 절차 확인 후 반영(context7)
- 디자인 프롬프트 하단 Supabase Edge Function/IndexedDB/API키 직접입력/프로젝트명 "코스잇다" 섹션은 우리 스택(Spring Boot+Railway)과 무관한 다른 템플릿 잔재로 판단, 전부 제외 — 사용자 확정
- 수정 전 스냅샷: `archive/2026-07-10/프론트-제작-프롬프트.md.before-merge`

**병합 직후 재검토(같은 날)로 추가 발견·수정**: `frontend-spec.md` §3 라우트 표·§4② 헤딩이 여전히 `/sites/:pnu`(경로파라미터)로 남아있었음 — 실제로는 `/map?q=&pnu=`(지도+쿼리스트링) 방식임을 반영해 정정, ②의 지도가 "마커 1개"로 서술돼 있던 것도 실제 구현(후보 전체 마커+`fitBounds`)에 맞게 수정. `프론트-연동계약서.md`의 ① 랜딩 클릭 목적지도 동일하게 정정. shadcn/ui 설치 명령·컴포넌트 10종 실존 여부는 context7로 재검증 완료(문제 없음).

### 2026-07-10 (7차) — 정합성 점검(스펙 문서 간 교차검증, 코드 변경 없음)

프론트/백 실 구현 착수 전, `spec/` 8개 문서 + `CLAUDE.md`를 전수 교차검증해 버전 변동 과정에서 갱신 안 된 잔재를 정리:

- **`backend-spec.md` §3.2 LocationSource.LICENSE 근거 정정**: `호실분리여부`+`호실단위지번주소`(구 v2, 36컬럼 데이터셋 기준)를 실제 19컬럼 필드명 `주소분리여부`로 교체. 실측상 이 필드는 **전부 false**(`인허가-데이터-필드명세-v4.md` §3)라 LICENSE 분기가 실데이터에서 사실상 발동 안 함을 명시
- **좌표 지오코딩 폴백(VWorld·상가API lon/lat) 전면 불필요로 정정**: `인허가-데이터-필드명세-v4.md` §7 실측(원본좌표 결측 0%, 10건 표본)을 근거로 `CLAUDE.md`(§8·§9·§10 3곳), `상권조회-API-명세.md`(§4 lon/lat 필드), `의사결정-기록.md`(D-GEO)를 정정. `backend-spec.md` §6 Site.coordinate 매핑에 근거·잔여 리스크(전량 적재 시 개별 변환 실패 가능성, `COORD_CONVERT_FAIL` 처리 유지) 명시
- **"18컬럼" 잔재 정정**: `backend-spec.md`(2곳)·`schema.sql` 헤더 주석이 v3(18컬럼) 시점 그대로 남아있었음 — 본문(sub_category 컬럼 등)은 이미 19컬럼 기준이라 실제 동작엔 영향 없었음. 19컬럼으로 통일
- **`frontend-spec.md` 자기참조 깨짐 수정**: 도입부가 개명 전 파일명 `api-spec-v3.md`를 참조하고 있었음(1차 개편 때 `api-spec.md`로 개명됨) → `api-spec.md`로 수정
- **`인허가-데이터-필드명세-v4.md` §8 자기모순 수정**: 본문은 `subCategory`로 이미 정정했는데 "다음 반영 대상" 문장에만 옛 필드명 `businessType`이 남아있었음
- 수정 전 스냅샷: `archive/2026-07-10/`

### 2026-07-09 (6차) — 디렉토리 재편(spec/ · spec_before/) + 백엔드 구현 착수

- 현재 적용 중인 최신 스펙만 루트의 `spec/`로 이동: `api-spec.md`·`frontend-spec.md`·`backend-spec.md`·`schema.sql`·`CHANGELOG.md`·`의사결정-기록.md`·`상권조회-API-명세.md`·`인허가-데이터-필드명세-v4.md`·`데이터_예시.csv`·`sangga_client.py`·`test_client.py`
- 버전 접미사 붙은 옛 파일(`api-spec-v3.md`·`frontend-spec-v3.md`·`schema-v3.sql`·`10-backend-spec.md`·`11-backend-spec.md`·`20-frontend-spec.md`)과 옛 계약 스냅샷 디렉토리(`files/`·`files0/`·`files1/`), 갱신 안 된 `프론트-연동계약서.md`·`프론트-제작-프롬프트.md`는 전부 `spec_before/`로 이동(삭제 아님, 원본 파일명 그대로 보존)
- `CLAUDE.md` 파일맵을 새 경로(`spec/` 접두)로 갱신
- **적재 데이터 실사**: `data_uncleaning/`의 raw CSV들을 열어보니 `schema.sql`이 가정한 19컬럼(category/subCategory 분리 + 폐업일자 실컬럼) 구조와 일치하는 대용량 파일이 없음이 확인됨. 9.8만행짜리 `PNU(지번)기반_개폐업정보현황_성남시_10년.csv`는 폐업일자 컬럼 자체가 없고, `식품_일반음식점_...csv`는 일반음식점 단일업종뿐. `spec/데이터_예시.csv`(20행)만 정확히 목표 구조와 일치 — 이건 예시값일 뿐 전체 규모 데이터셋은 아님(사용자 확인)
- **범위 확정**: 대용량 실데이터 적재는 이번 백엔드 서버 구현과 별개 작업으로 분리. 이번 세션은 `spec/schema.sql` 그대로 Spring Boot 서버(전 6단계, 상가API 클라이언트 포함)를 완성하고, 로컬 개발/데모용 시드는 `데이터_예시.csv`와 동일 구조의 소규모 데이터로 채움
- `ingestion/`(Node 파이프라인)은 구버전 스키마(`category_code` 단일 컬럼 등) 기준이라 현재 스키마에 그대로 못 씀을 확인, 재사용하지 않기로 함

### 2026-07-09 (5차) — 상가API 공식 명세 확정 (hwp 원문)

- 사용자가 업로드한 공식 활용가이드(hwp)를 hwp5html로 표 구조까지 추출해 읽음
- **BASE_URL 확정**: `/sdsc/`가 아니라 `/sdsc2/`였음(코드 기본값 수정)
- **오퍼레이션 함정 발견**: "반경내 상권조회"(storeZoneInRadius, #2, 폴리곤 데이터)와 "반경내 상가업소조회"(storeListInRadius, #10, 우리가 실제 쓰는 것)는 이름이 비슷해도 완전히 다른 오퍼레이션. 코드 URL 오타 위험 요소였음
- **설계 개선**: 반경조회에 `indsSclsCd` 서버 측 필터가 있음을 확인 → marketInfo.sameCategoryNearbyCount 산출을 "클라이언트 필터링"에서 "서버 필터 + totalCount 그대로 사용"으로 단순화(정확도·성능 개선)
- 응답 스키마 확정: `numOfRows`/`pageNo`/`totalCount`가 `body` 하위, `items`와 형제 노드(우리 클라이언트 코드가 우연히 정확했음이 확인됨)
- `enrichment/sangga_client.py`: BASE_URL 수정, `fetch_radius_same_category_count` 신규 메서드 추가, `_request_page`→`_request` 공통 재시도 헬퍼로 리팩터링, 테스트 3건 추가(20개 전체 통과)
- `상권조회-API-명세.md` v1(추정 다수, archive)를 hwp 원문 기반 v2로 전면 교체
- `backend-spec.md` 4.2절(상권 조회 파이프라인) 서버 필터 방식으로 갱신

### 2026-07-09 (4차) — 대분류/소분류 컬럼 분리 (업종 3계층 확정)

- 데이터셋 19컬럼으로 변경(대분류_소분류 묶였던 것을 원본 행안부 구조대로 분리)
- 업종 3계층 확정: `category`(대분류, 타임라인 표시) / `subCategory`(소분류, 상세 표시) / `industryDetail`(상가API 세부, 있으면 우선). 별도 필드 유지로 출처 보존(사용자 확정 A안)
- `businessType`(업종명) 필드 **제거** — 전부 공백, 소분류가 역할 대체
- 주소분리여부: 사용자 입력 표현 제각각(101호=1층1호)이라 신뢰불가 → 자리=물건 1:1 기본 확정
- 반영: `api-spec.md`·`frontend-spec.md`(타입·목데이터 JSON 7블록 재검증)·`schema.sql`(sub_category 컬럼)·`backend-spec.md`·`프론트-연동계약서.md`·`프론트-제작-프롬프트.md`·`인허가-데이터-필드명세-v4.md`(v3 아카이브)

### 2026-07-09 (3차) — 실데이터셋 검증 + category/businessType 분리 + 프론트 연동계약

- 실 CSV(18컬럼) 검증 완료 → 가정을 실측으로 대체. `인허가-데이터-필드명세-v3.md` 신규(v2 아카이브)
- 확정 사항: PNU 100%·폐업일자 실값·좌표 100%(투영, 변환필요)·**업종명 전부 공백**·**주소분리여부 전부 false**
- API 계약: `category`(대분류, NOT NULL) / `businessType`(업종명, nullable) / `industryDetail`(상가API) 3필드 분리. `api-spec.md`·`frontend-spec.md` 목데이터·타입 반영, JSON 7블록 재검증 통과
- `schema.sql` v5: 실 CSV 컬럼 확정(original_x/y 보존, address_corrected 마스킹 지표, business_type nullable)
- 물건분리 D-1 재확정: 주소분리여부 신뢰불가 → 자리=물건 1:1 기본, 연대기는 "한 PNU에 여러 Tenancy 시간순"
- 신규: `프론트-연동계약서.md`(엔드포인트·타입·도메인 한 장), `프론트-제작-프롬프트.md`(Claude Code용)
- 마스킹 처리 규칙 신설(10만→유효 5만, ingestion_exclusion_log)

### 2026-07-09 (2차) — 백엔드 상세 아키텍처 + 인허가 신형 스키마 (archive/2026-07-09-detailed/)

- **개폐업(DB조회) / 상권(API 실시간호출) 두 파이프라인을 아키텍처 레벨에서 분리** — 시간 특성이 다른 두 소스를 신뢰 경계 A(DB)/B(외부API)로 나누고, B 실패가 A를 막지 않는 부분실패 격리를 SiteQueryService의 try-catch로 구현
- `backend-spec.md`를 상세판으로 교체(레이어·도메인모델·데이터흐름·착수순서). 이전판은 archive에 보존
- `schema.sql` v4: **상권 테이블 전부 제거**(tenancy_market_info, site_radius_store_cache) — 상권은 DB 영속화 안 하고 인메모리 캐시만. DB는 개폐업만
- 인허가 신형 데이터셋 반영: PNU 직접 제공(유도 불필요), **폐업일자 실값**(추가 전제 → closedAtEstimated 항상 false), 호실분리여부 기반 물건 분리(locationSource LICENSE 최우선)
- 조회 식별자 = PNU로 두 소스(개폐업 DB + 상권 API) 연결
- 근거: `인허가-데이터-필드명세-v2.md`(신형 컬럼 36개 분석), `backend-spec.md` 1·4장

### 2026-07-09 (1차) — 캐노니컬 전환 + marketInfo 정정 스냅샷 (archive/2026-07-09/)

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
