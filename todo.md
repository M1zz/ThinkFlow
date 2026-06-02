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
