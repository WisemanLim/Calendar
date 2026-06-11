# dev-env 시험 시나리오

- 프로파일: ios-swiftui (Swift + SwiftUI + EventKit)
- 목적: 표준 개발환경(Xcode/시뮬레이터) 기동·빌드·테스트 가능 확인

| ID | 시나리오 | 기대 |
|----|----------|------|
| E1 | Xcode 프로젝트 인식 | `xcodebuild -list` 에 Calendar/CalendarTests 타깃 노출 |
| E2 | 디버그 빌드 | iPhone 17 시뮬레이터 Debug 빌드 BUILD SUCCEEDED |
| E3 | 테스트 실행 | `xcodebuild test` TEST SUCCEEDED |
