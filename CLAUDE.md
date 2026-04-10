# Project Conventions

## Git Commit Rules

### Commit Message Format (Conventional Commits)
```
<type>: <subject>
```

**Types:**
- `feat:` 새로운 기능 추가
- `fix:` 버그 수정
- `refactor:` 코드 리팩토링 (기능 변화 없음)
- `style:` 코드 포맷팅, 세미콜론 누락 등 (기능 변화 없음)
- `docs:` 문서 수정
- `chore:` 빌드 설정, 리소스 추가 등
- `test:` 테스트 추가/수정

**Rules:**
- 영어로 작성, 소문자 시작, 마침표 없음
- 현재형 동사 사용 (add, fix, update, remove)
- subject는 50자 이내
- 파일/기능 단위로 커밋 (작고 의미 있는 단위)
- 커밋은 사용자가 명시적으로 요청할 때만 수행

**Rules for committing:**
- Co-Authored-By 헤더 사용하지 않음 (사용자 계정으로만 커밋)
- 푸시도 사용자 요청 시에만 수행

**Examples:**
```
feat: add MarkdownDocument file model
feat: implement editor view with line numbers
fix: resolve scroll sync feedback loop
chore: bundle marked.js and highlight.js resources
refactor: extract HTML export logic to HTMLExporter
```

### Branch Strategy
- `main` 브랜치에 직접 커밋
- 별도 feature 브랜치 사용하지 않음

## Swift Code Conventions (Apple Swift API Design Guidelines)

### Naming
- **Types**: UpperCamelCase (`MarkdownDocument`, `WebViewBridge`)
- **Functions/Properties**: lowerCamelCase (`exportPDF()`, `previewMode`)
- **Constants**: lowerCamelCase (`defaultFontSize`)
- 약어는 대문자 유지: `PDF`, `HTML`, `URL`, `TOC`
- 명확하고 의미 있는 이름 사용, 불필요한 축약 금지

### Code Style
- `self` 생략 (컴파일러가 요구할 때만 사용)
- `guard`로 early return 처리
- 접근 제어자 명시 (`private`, `internal` 등)
- 한 줄 최대 120자
- import 알파벳 순 정렬
- trailing closure 사용

### Architecture
- MVVM-lite 패턴
- `@Observable` 사용 (ObservableObject 대신)
- `nonisolated` 명시 (FileDocument 프로토콜 메서드 등)
- SwiftUI + NSViewRepresentable (AppKit 브릿지)

### File Organization
```
Markdown_Preview_Mac/
├── Model/          # 데이터 모델 (FileDocument, enums)
├── Views/          # SwiftUI 뷰
├── Services/       # 비즈니스 로직 (WebViewBridge 등)
├── Extensions/     # Swift 확장
└── Resources/      # HTML, JS, CSS 리소스
```
