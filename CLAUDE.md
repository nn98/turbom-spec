# CLAUDE.md — turbom-spec

넥스트스텝(우아한바톤 해커톤) 프로젝트의 스펙 원본 저장소. `turbom-server`(백엔드)·`turbom-client`(프론트) 둘 다 이 저장소를 형제 폴더(`../turbom-spec/`)로 참조하며, 자체 사본을 두지 않는다. 전체 프로젝트 컨텍스트는 `../CLAUDE.md`(root) 참조.

## 이 저장소가 존재하는 이유

2026-07-19 이전엔 스펙이 root `spec/`(git 미관리)·`server/spec/`·`ter-view/spec/`·`ter-view/docs/spec/` 여러 곳에 흩어져 있었다. 분산 관리 중 실제로 이력이 유실되는 사고가 반복됐다(root CHANGELOG 15차 항목이 섹션 헤더 누락으로 파묻힘, 프론트 세션의 버그 리포트 2건이 미커밋 상태로 며칠째 방치 — 자세한 경위는 아래 CHANGELOG 17차). 그래서 스펙을 이 독립 저장소 하나로 모았다.

## 작업 규칙

1. **여기서 직접 수정한다.** `server`나 `ter-view`에 사본을 만들어서 고치고 나중에 옮기지 않는다.
2. **커밋만으로 끝내지 않는다 — 반드시 `git push`까지 한다.** 이 저장소가 존재하는 이유 자체가 "커밋해뒀지만 push 안 해서 다른 세션이 못 본" 사고를 막기 위해서다. `git push` 전에 작업을 완료로 보고하지 않는다.
3. 예전 버전은 지우지 말고 `spec_before/`에 원래 파일명 그대로 보존, 저장할 때마다 `archive/YYYY-MM-DD/`에 스냅샷.
4. 수정 시 `CHANGELOG.md`에 한 줄 추가(형식은 기존 항목 참고 — 몇 차인지, 무엇을 왜 바꿨는지, API 계약 영향 여부).
5. `api-spec.md`를 바꾸면 root `CLAUDE.md` §12 체크리스트(`frontend-spec.md`/`backend-spec.md`/`schema.sql`/기획서/`의사결정-기록.md`)를 같이 확인한다.
6. `ter-view`의 `.github/workflows/spec-drift-check.yml`이 매일 이 저장소의 `api-spec.md`/`frontend-spec.md`를 `ter-view/docs/spec/`과 자동 대조한다 — 이 두 파일을 바꾸면 그 워크플로우가 며칠 내로 드리프트 이슈를 열 수 있다는 걸 감안한다.
