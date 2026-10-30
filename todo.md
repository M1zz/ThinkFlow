# ThinkFlow 개선 작업

핵심 경험("생각을 조금조금 이어 나가기") 점검 후 발견한 마찰 지점 수정.

## 작업 목록

- [x] 1. Progressive Summarization 살리기 — 엔트리 layer 승급 칩(Menu) 추가 (EntryRowView)
- [x] 2. 샘플 데이터 분리 — 첫 실행에 샘플 미저장, HomeView 빈 상태/온보딩 추가
- [x] 3. 세션 타이머 단일화 — depth 카운팅으로 중복/유실 버그 수정 (ThoughtStore)
- [x] 4-1. "닫기" 라벨/동작 불일치 수정 (ContinueThinkingSheet)
- [x] 4-2. 개별 엔트리 수정/삭제 기능 추가 (EntryRowView + EntryEditSheet + ThreadDetailView)
- [x] 5. 죽은 코드 정리 — NewThreadSheet 삭제(+pbxproj), HemingwayBridge.currentState 제거(위젯·Live Activity 포함)

## 문서 & 접근성

- [x] 6. 사용 시나리오 문서 작성 (docs/usage-and-accessibility.md)
- [x] 7. VoiceOver/저시력 접근성 구현
  - [x] 섹션 제목 헤더 trait (HomeView, ThreadDetailView)
  - [x] 아이콘 버튼 라벨 (+, 복사, 더보기, 브릿지수정 등)
  - [x] 덤프 행 → 시맨틱 버튼 + 삭제 접근성 액션
  - [x] 복사/레이어변경 음성 안내(UIAccessibility.post)
  - [x] 타임스탬프 합치기 + 장식 요소 숨김 (EntryRowView)
  - [x] TextEditor 라벨 (이어쓰기 2곳, 브레인덤프)
  - [x] 고정 폰트 → Dynamic Type (진행도 링, 레이어 칩)
  - [x] 시트 단계 전환 음성 안내 (생각→끊어두기)
  - [x] 통계 항목 라벨+값 결합, 브레인덤프 선택 trait

## 검증
- [x] 빌드 통과 (xcodebuild, ThinkFlow + widgetExtension 모두 BUILD SUCCEEDED)
- [x] 접근성 적용 후 재빌드 통과 (BUILD SUCCEEDED)

## 아이폰 듀오 대응 (2026-10-31, 듀오 시뮬레이터 대상 빌드 성공 · 화면 확인 못 함)
- [x] LeeoKit Fold: 앱 루트에 `.foldAware()`. 시트 · 알림창이 접힌 선을 비킨다
- [x] 펴면 왼쪽(세로면 아래) 생각 목록 | 오른쪽(위) 고른 생각의 스레드 화면(`HomeView` 의 `FoldSplitView` · `FoldThreadPane`). 안 골랐으면 가장 최근 생각
- [x] 펼친 화면에서 카드를 누르면 밀어 넣지 않고 오른쪽 판을 바꾼다. 열린 카드는 주황 테두리
- [x] 접힌 채 스레드를 보다가 펴면 그 스레드가 오른쪽으로 옮겨 간다. 목록 · 스크롤은 그대로 이어진다
- [x] 글자만 있던 툴바 단추에 아이콘(취소 · 저장 · 닫기 · 다음 · 완료 · 다 꺼냈어요). 문구는 그대로라 번역 추가 없음
- [ ] 듀오 시뮬레이터 캡처: 이번에는 시뮬레이터 서비스가 응답하지 않아 못 찍었다
- [ ] 가로로 편 화면 · 실기기 확인

확인: 듀오 시뮬레이터에 설치 후 `-FoldPretend` 로 띄우면 펼친 배치, 인자 없이 띄우면 접힌 화면(지금 그대로).
스크린샷 데이터는 `python3 scripts/screenshot_seed.py ko home <json>` 으로 만들고 `-ScreenshotSeed <json>` 으로 넘긴다.
