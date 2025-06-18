# Sight of Emotion - Flutter `lib` Directory README

이 문서는 Flutter 애플리케이션의 `lib` 디렉토리에 있는 소스 코드에 대한 분석 및 가이드입니다. 프로젝트의 구조, 각 파일의 기능, 현재 코드의 문제점 및 개선 방안을 포함하고 있습니다.

## 1. 프로젝트 개요

이 애플리케이션은 YouTube 트렌드 동영상(주로 '게임' 카테고리)을 분석하고 시각화하는 Flutter 프로젝트입니다. 사용자는 트렌드 순위를 확인하고, 동영상 제목에 포함된 키워드와 감성 분석 결과를 차트를 통해 직관적으로 파악할 수 있습니다.

**주요 기능:**
- YouTube 인기 동영상 및 검색 기반 트렌드 조회
- 동영상 제목에서 키워드 추출 및 감성/감정 분석 (Hugging Face API 활용)
- 분석 결과를 테이블, 파이 차트, 네트워크 그래프 등 다양한 형태로 시각화
- 플랫폼(Native/Web)에 맞는 로컬 데이터베이스(Drift/IndexedDB) 연동

## 2. `lib` 디렉토리 파일 구조 및 기능

`lib` 디렉토리는 애플리케이션의 핵심 로직을 담고 있으며, 다음과 같은 구조로 구성되어 있습니다.

```
lib/
├── config/
│   └── api_keys.dart           # 외부 API 키 관리
├── main.dart                   # 앱 진입점 (Entry Point)
├── models/
│   ├── api_response.dart       # API 응답 래퍼 모델
│   ├── database.dart           # Drift 데이터베이스 및 테이블 정의
│   ├── database.g.dart         # Drift 자동 생성 파일
│   ├── keyword_sentiment.dart  # 키워드 감성 분석 모델
│   ├── video_analysis_result.dart # 최종 비디오 분석 결과 모델
│   └── youtube_data.dart       # YouTube 비디오 데이터 모델
│   └── database/
│       └── connection/         # 플랫폼별 Drift DB 연결 로직
├── screens/
│   └── trends_screen.dart      # 메인 화면 UI 및 상태 관리
├── services/
│   ├── api_service.dart        # YouTube API 연동 서비스
│   ├── database_helper.dart    # (구) IndexedDB 직접 제어 헬퍼
│   ├── migration_service.dart  # DB 마이그레이션 서비스
│   └── nlp_service.dart        # 텍스트 분석 오케스트레이션 서비스
├── utils/
│   └── text_analyzer.dart      # 핵심 NLP(키워드/감성) 분석 유틸리티
└── widgets/
    ├── app_theme.dart          # 앱 전체 테마 (색상, 폰트)
    ├── pagination_controls.dart# 데이터 테이블 페이지네이션 위젯
    └── charts/
        ├── keyword_network_graph.dart # 키워드 관계 네트워크 그래프 위젯
        ├── keyword_typography.dart   # 키워드 태그 클라우드 위젯
        └── trends_pie_chart.dart     # 트렌드 파이 차트 위젯
```

### 상세 파일 설명

- **`main.dart`**: 앱의 시작점. `MaterialApp`을 설정하고, 테마, 라우팅 및 데이터베이스 초기화를 수행합니다.
- **`config/api_keys.dart`**: YouTube, Hugging Face 등 외부 API 연동에 필요한 키를 상수로 관리합니다.
- **`models/`**: 앱에서 사용하는 데이터 모델을 정의합니다.
    - `youtube_data.dart`: 유튜브 동영상 정보를 담는 핵심 모델.
    - `video_analysis_result.dart`: 동영상 정보와 NLP 분석 결과를 결합한 모델.
    - `database.dart`: `Drift` 패키지를 사용한 데이터베이스 테이블(스키마) 및 DAO(Data Access Object)를 정의합니다.
- **`screens/trends_screen.dart`**: 앱의 메인 UI. 탭, 검색 바, 데이터 테이블, 차트 등 대부분의 화면 요소를 포함하며 상태를 관리합니다.
- **`services/`**: 외부 서비스 연동, 데이터베이스 관리 등 백그라운드 로직을 처리합니다.
    - `api_service.dart`: YouTube API와 통신하여 트렌드 데이터를 가져옵니다.
    - `database_helper.dart`: `Drift`와 별개로 `IndexedDB`를 직접 제어하는 레거시 데이터베이스 헬퍼로 보입니다.
    - `migration_service.dart`: `IndexedDB`의 데이터를 `Drift` 데이터베이스로 이전하는 로직을 담고 있습니다.
    - `nlp_service.dart`: `TextAnalyzer`를 호출하여 동영상 제목 분석을 오케스트레이션합니다.
- **`utils/text_analyzer.dart`**: 실제 NLP 로직이 수행되는 곳. 정규식과 Hugging Face API를 통해 키워드를 추출하고 감정을 분석합니다.
- **`widgets/`**: 재사용 가능한 UI 컴포넌트를 정의합니다.
    - `app_theme.dart`: 앱의 색상, 폰트, 전체적인 디자인 시스템을 정의합니다.
    - `charts/`: 다양한 시각화 차트 위젯을 포함합니다.
        - `keyword_network_graph.dart`: 키워드 간의 동시 발생 관계를 네트워크 그래프로 시각화하는 매우 복잡한 위젯.
        - `trends_pie_chart.dart`: `fl_chart`를 사용하여 상위 트렌드를 파이 차트로 보여줍니다.

---

## 3. 코드 문제점 및 개선 제안

현재 코드베이스는 기능적으로 동작하지만, 유지보수성, 확장성, 성능 및 안정성 측면에서 여러 개선점을 가지고 있습니다.

### 3.1. 아키텍처 및 코드 구조 (Architecture & Code Structure)

- **문제점**: `screens/trends_screen.dart`와 `widgets/charts/keyword_network_graph.dart` 파일이 너무 많은 책임(상태 관리, 비즈니스 로직, UI 렌더링)을 가지고 있습니다. 이는 **Massive View Controller** (또는 God Object) 안티패턴으로, 코드를 이해하고 수정하기 어렵게 만듭니다.
- **제안**:
    1. **상태 관리 솔루션 도입**: `setState` 기반의 상태 관리에서 벗어나 `Riverpod`, `Provider`, `BLoC` 등의 전문 상태 관리 라이브러리를 도입하여 UI와 비즈니스 로직을 분리해야 합니다. 이를 통해 `TrendsScreen`의 복잡도를 크게 낮출 수 있습니다.
    2. **역할 분리 (Repository Pattern)**: `ApiService`, `DatabaseHelper` 등을 직접 호출하는 대신, 중간에 **Repository** 계층을 두어 데이터 소스(API, DB)를 추상화합니다. 예를 들어, `TrendRepository`는 UI에 필요한 데이터를 API에서 가져올지, 로컬 DB에서 가져올지 결정하고 가공하여 제공합니다.
    3. **로직 추출**: 위젯 내에 있는 비즈니스 로직(데이터 필터링, 정렬, 가공)을 별도의 `ViewModel` 또는 `Controller` 클래스로 추출합니다. 위젯은 오직 상태를 받아 화면에 그리는 역할에만 집중해야 합니다.

### 3.2. 데이터베이스 (Database)

- **문제점**: 프로젝트 내에 **두 개의 독립적인 데이터베이스 구현**이 존재합니다.
    1. `drift` 기반의 최신 구현 (`lib/models/database.dart`)
    2. `idb_shim`을 직접 사용하는 레거시 IndexedDB 구현 (`lib/services/database_helper.dart`)
    이는 데이터 불일치, 중복 코드, 혼란을 야기하는 가장 심각한 구조적 문제입니다. 또한, `migration_service.dart`가 참조하는 DB 이름(`youtube_trends_db`)과 `database_helper.dart`의 DB 이름(`youtube_trends.db`)이 달라 마이그레이션이 실패할 가능성이 높습니다.
- **제안**:
    1. **`Drift`로 통일**: `Drift`는 타입 안정성, 크로스플랫폼 지원 등 장점이 많으므로, 데이터베이스 구현을 `Drift`로 완전히 통일해야 합니다. `DatabaseHelper`는 즉시 제거하고, 모든 DB 관련 로직이 `AppDatabase`를 통해 이루어지도록 리팩토링해야 합니다.
    2. **마이그레이션 수정 및 완료**: `MigrationService`의 DB 이름을 `youtube_trends.db`로 수정하여 기존 데이터를 `Drift`로 올바르게 이전시키고, 마이그레이션이 한 번만 실행되도록 `SharedPreferences` 등을 사용하여 플래그 관리를 해야 합니다. 마이그레이션 완료 후에는 관련 코드를 제거하는 것을 고려할 수 있습니다.
    3. **잘못된 비즈니스 로직 수정**: `DatabaseHelper`의 평균 조회수/좋아요 수 계산 로직은 잘못되었습니다. `(기존평균 * 기존개수 + 새값) / (기존개수 + 1)` 공식을 사용하여 올바르게 수정해야 합니다. (이 로직은 `Drift`로 통합하면서 재작성 필요)

### 3.3. NLP 및 텍스트 분석 (NLP & Text Analysis)

- **문제점**: `utils/text_analyzer.dart`의 감정 분석 기능에 치명적인 결함이 있습니다. **영어 전용 감정 분석 모델**(`j-hartmann/emotion-english-distilroberta-base`)에 **한국어 텍스트**를 입력하고 있어, 분석 결과가 무의미합니다. 또한, 키워드 추출 로직이 매우 복잡하고 특정 API 응답 형식에 강하게 의존적입니다.
- **제안**:
    1. **한국어 감정 분석 모델 사용**: Hugging Face Hub에서 `ko-emotion`, `korean-sentiment` 등으로 검색하여 **한국어를 지원하는 감정/감성 분석 모델**로 교체해야 합니다. (예: `matthew-parker/ko-emotion-classifier`)
    2. **로직 단순화 및 분리**: `TextAnalyzer`의 복잡한 로직을 더 작은 함수로 분리하고, 특히 거대한 `stopWords` 목록은 별도의 `asset` 파일(.txt, .json)로 분리하여 코드 가독성을 높여야 합니다.
    3. **성능 개선**: `NlpService`에서 `await`를 사용하는 `for` 루프는 API 요청을 순차적으로 보내 비효율적입니다. `Future.wait()`를 사용하여 여러 분석 요청을 병렬로 처리하면 성능을 크게 향상시킬 수 있습니다.

### 3.4. API 및 서비스 (API & Services)

- **문제점**: `ApiService`가 API 통신 외에 키워드 추출을 트리거하고 데이터베이스에 직접 저장하는 등 너무 많은 역할을 수행합니다 (단일 책임 원칙 위반). 또한 에러 처리가 `print()`로 끝나 UI에 피드백을 주지 못하고, API 키가 코드에 하드코딩되어 보안에 취약합니다.
- **제안**:
    1. **역할 분리**: `ApiService`는 순수하게 네트워크 통신과 JSON 파싱만 담당하도록 수정합니다. 데이터 저장 및 추가 분석은 위에서 제안한 `Repository`나 `ViewModel`에서 오케스트레이션하도록 변경합니다.
    2. **체계적인 에러 처리**: `print()` 대신, `Exception`을 발생시키거나 `Result` 타입(성공/실패 객체)을 반환하여 UI 레이어에서 로딩 실패, 네트워크 오류 등 다양한 상태를 사용자에게 명확히 보여줄 수 있도록 개선해야 합니다.
    3. **API 키 보안**: `const String`으로 키를 저장하는 대신, **`--dart-define-from-file`**을 사용하여 컴파일 타임에 환경 변수로 주입하는 방식을 사용하는 것이 훨씬 안전합니다. 이렇게 하면 키가 Git 리포지토리에 포함되지 않습니다.

### 3.5. UI 및 테마 (UI & Theme)

- **문제점**: `AppTheme`에서 `lightTheme` 변수가 실제로는 어두운 테마로 설정되어 있어 이름과 실제 기능이 일치하지 않아 혼란을 줍니다. 또한 Material 2와 Material 3 테마가 혼재되어 일관성이 부족합니다.
- **제안**:
    1. **테마 명칭 수정**: `lightTheme`의 이름을 `darkTheme` 또는 `appTheme` 등으로 명확하게 변경하고, 하나의 디자인 시스템(가급적 최신 Material 3)으로 통일하여 일관성을 확보하는 것이 좋습니다.
    2. **위젯 리팩토링**: `KeywordTypography`와 `TrendsPieChart` 위젯 내에 있는 데이터 가공 로직을 외부로 분리해야 합니다. 위젯은 미리 계산된 데이터를 받아 렌더링만 담당하도록 하여 재사용성과 테스트 용이성을 높여야 합니다.

---

이 문서를 바탕으로 프로젝트를 체계적으로 리팩토링하고 발전시켜 나가시길 바랍니다. 