# YouTube 감성 분석 앱 개선 TODO

이 문서는 현재 프로젝트의 성능 문제 해결과 감성 분석 시각화 개선을 위한 체계적인 작업 계획입니다. 제공된 심층 분석 보고서의 내용을 반영하여 업데이트되었습니다.

## 🎯 우선순위별 작업 계획

### Phase 1: 성능 최적화 및 안정화 (고우선순위)
**목표**: NLP 처리 부하 및 오류 해결, UI 응답성 개선

#### 1.1 NLP 처리 부하 해결
- [x] **비동기 처리 개선 (계획 확정)**
  - `NlpService`의 순차 처리(`for` + `await`)를 `Future.wait()`로 병렬 처리 변경
  - 키워드 추출과 감성 분석을 백그라운드 `Isolate`에서 처리 (`compute()` 함수 활용)
  - **(신규 제안)** 대규모 댓글 수집은 `Workmanager` 또는 `flutter_background_service`를 활용하여 앱이 백그라운드에 있을 때도 처리하는 방안 검토

- [x] **캐싱 시스템 구현 (계획 확정)**
  - 동일한 제목의 분석 결과를 로컬 캐시에 저장
  - **(개선)** 단순 캐싱을 넘어, 데이터 신선도와 응답성 모두를 고려한 'local-first' 캐싱 전략 도입 (캐시된 데이터를 먼저 보여주고, 백그라운드에서 API 업데이트)

- [x] **한국어 감성 분석 모델 교체 및 수정 (오류 해결 필요)**
  - **(현재 문제)** `klue/roberta-base` 모델 호출 시 404 "Not Found" 오류가 발생하는 것을 재확인함. API 엔드포인트 또는 모델 지원 중단 여부 확인 필요.
  - **(개선 제안)** 보고서에서 제안된 대로, 더 높은 정확도와 안정성을 위해 `Google Cloud Natural Language API`와 같은 클라우드 기반 서비스로 교체하는 것을 적극 권장.
  - API 응답 파싱 로직 수정

- [ ] **고급 감성 지표 도출 (신규)**
  - 단순 긍정/부정을 넘어, 감성의 `점수(score)`와 `강도(magnitude)`를 모두 활용하여 "논란 지수(Controversy Score)"와 같은 심층적인 지표를 계산하고 시각화에 활용

#### 1.2 UI 성능 최적화
- [ ] **위젯 리빌드 최적화**
  - `TrendsScreen`에서 `setState()` 사용 최소화
  - `const` 생성자 적극 활용
  - `RepaintBoundary`로 차트 영역 격리

- [ ] **애니메이션 성능 개선**
  - `AnimatedBuilder` 사용으로 불필요한 리빌드 방지
  - `CustomPaint`와 `CustomPainter`로 복잡한 애니메이션 최적화

### Phase 2: 감성 분석 시각화 개선 (중우선순위)
**목표**: 색상 심리학 및 모바일 UX 기반 직관적 데이터 시각화

#### 2.1 색상 심리학 기반 팔레트 구현
- [ ] **감정별 색상 매핑 시스템** (`joy`: Gold, `sadness`: Blue, `anger`: Red 등)
- [ ] **동적 색상 강도 시스템** (감정 강도에 따른 채도 조절)

#### 2.2 인터랙티브 시각화 요소
- [ ] **감정 변화 애니메이션** (색상/형태 전환 애니메이션)
- [ ] **터치 인터랙션 강화** (차트 요소 터치 시 상세 정보 표시, 햅틱 피드백)

#### 2.3 새로운 시각화 컴포넌트
- [ ] **감정 파동 시각화 (Emotion Wave)**
- [ ] **감정 날씨 시각화 (Emotion Weather)**
- [ ] **상관관계 산점도 (Correlation Scatter Plot) (신규)**
  - '조회수'와 '평균 감성 점수' 또는 '논란 지수'를 축으로 하여 인기도와 감성의 상관관계를 시각적으로 분석

- [x] **📊 데이터 분포 분석 대시보드 (신규 - 구현 완료 ✅)**
  - **감정 분포 히스토그램**: 각 감정(joy, sadness, anger 등)의 빈도수와 비율을 막대그래프로 시각화 ✅
  - **키워드 빈도 분포 테이블**: 상위 키워드들의 출현 빈도, TF-IDF 점수, 동시 출현율을 데이터 테이블로 제공 ✅
  - **조회수/좋아요 통계 분포**: 조회수와 좋아요 수의 평균, 중앙값, 표준편차, 분위수를 통계 카드로 표시 ✅
  - **감성 점수 분산 분석**: 분석 요약 카드로 총 동영상 수, 감정 종류, 키워드 수, 주요 감정을 표시 ✅

- [x] **📈 다차원 감성 비교 테이블 (신규 - 구현 완료 ✅)**
  - **다중 키워드 감성 비교 매트릭스**: 여러 키워드 검색 결과를 행렬 형태로 동시 비교하여 감성 패턴의 차이점 분석 ✅
  - **시간대별 감성 트렌드 비교**: 월별 감성 변화를 데이터 테이블과 색상 막대로 비교 ✅
  - **채널별 감성 프로파일링**: 비디오 ID 기반 채널 구분으로 감성 패턴을 색상 막대 차트로 시각화 ✅
  - **카테고리/장르별 감성 세분화**: 3가지 비교 모드(키워드별/채널별/시간별)를 선택형 버튼으로 제공 ✅

#### 2.4 모바일 최적화 UI/UX 원칙 적용 (신규)
- [ ] 차트를 작은 화면에 맞게 단순화하고, 반응형으로 설계
- [ ] 터치 상호작용(확대/축소, 탭)에 최적화
- [ ] 명확한 정보 계층과 접근성(고대비 색상 등) 보장

### Phase 3: 아키텍처 개선 (중우선순위)
**목표**: 코드 구조 개선 및 유지보수성 향상

#### 3.1 상태 관리 및 아키텍처 패턴 도입
- [x] **Riverpod 도입 (계획 확정)**
  - `StateNotifierProvider` 등을 활용하여 UI와 비즈니스 로직을 명확히 분리
  
- [x] **Repository 패턴 구현 (계획 확정)**
  - `TrendRepository`: API와 로컬 DB를 추상화하여 데이터 소스를 통합 관리
  - `ApiService`에서 데이터 저장 로직을 분리하여 `Repository`로 이전

- [ ] **견고한 에러 처리 (신규)**
  - `try-catch`를 넘어, `Result`/`Either` 패턴을 도입하여 API 및 데이터 처리 실패 케이스를 명시적으로 관리하고, 사용자에게 명확한 피드백 제공

#### 3.2 데이터베이스 통합
- [x] **Drift로 완전 통합 (계획 확정)**
  - **(완료된 1단계)** `ApiService`에서 웹 전용 `DatabaseHelper` 호출 로직 제거 완료.
  - **(추가 조치)** 네이티브 플랫폼(macOS)에서 `main.dart`가 웹 전용 `MigrationService`를 호출하여 발생하는 `UnimplementedError`를 해결하기 위해, 관련 로직을 임시로 주석 처리함. 향후 마이그레이션 로직은 플랫폼을 올바르게 분기하여 처리해야 함.
  - `Drift`의 `AppDatabase`를 사용하도록 전체 데이터베이스 로직 리팩토링.
  - 감정 분석 결과 저장을 위한 새 테이블 추가.

### Phase 4: 고급 시각화 기능 (저우선순위)
**목표**: 차별화된 감성 분석 경험 제공

#### 4.1 3D 감정 공간 시각화
- [ ] 3차원 감정 좌표계 (Valence, Arousal, Dominance) 활용

#### 4.2 실시간 감정 흐름 시각화
- [ ] 감정 강 (Emotion River) 구현

## 🔧 기술적 구현 세부사항

### 성능 최적화 구현
```dart
// 1. 병렬 처리 개선
class OptimizedNlpService {
  Future<List<VideoAnalysisResult>> analyzeVideoTitles(List<YoutubeData> videos) async {
    // 배치 처리로 API 호출 최소화
    final batches = _createBatches(videos, batchSize: 10);
    final results = await Future.wait(
      batches.map((batch) => _processBatch(batch)),
    );
    return results.expand((x) => x).toList();
  }
  
  Future<List<VideoAnalysisResult>> _processBatch(List<YoutubeData> batch) async {
    return await compute(_analyzeInIsolate, batch);
  }
}

// 2. 캐싱 시스템
class EmotionCacheService {
  static const String _cacheKey = 'emotion_analysis_cache';
  final Box<String> _cache = Hive.box<String>(_cacheKey);
  
  Future<VideoAnalysisResult?> getCachedResult(String videoTitle) async {
    final cached = _cache.get(_generateKey(videoTitle));
    return cached != null ? VideoAnalysisResult.fromJson(jsonDecode(cached)) : null;
  }
  
  Future<void> cacheResult(String videoTitle, VideoAnalysisResult result) async {
    await _cache.put(_generateKey(videoTitle), jsonEncode(result.toJson()));
  }
}
```

### 감정 시각화 구현
```dart
// 감정 색상 시스템
class EmotionColorSystem {
  static Color getEmotionColor(String emotion, double intensity) {
    final baseColor = _emotionBaseColors[emotion] ?? Colors.grey;
    return HSLColor.fromColor(baseColor)
        .withLightness((1.0 - intensity * 0.3).clamp(0.0, 1.0))
        .withSaturation((0.7 + intensity * 0.3).clamp(0.0, 1.0))
        .toColor();
  }
  
  static List<Color> getEmotionGradient(String emotion) {
    final base = _emotionBaseColors[emotion] ?? Colors.grey;
    return [
      base.withOpacity(0.3),
      base,
      base.withOpacity(0.8),
    ];
  }
}

// 데이터 분포 분석 구현
class DataDistributionAnalyzer {
  static Map<String, dynamic> analyzeEmotionDistribution(List<VideoAnalysisResult> results) {
    final emotionCounts = <String, int>{};
    for (final result in results) {
      final emotion = result.primaryEmotion;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }
    
    return {
      'distribution': emotionCounts,
      'total': results.length,
      'percentages': emotionCounts.map((k, v) => MapEntry(k, (v / results.length * 100).toStringAsFixed(1))),
      'entropy': _calculateEntropy(emotionCounts.values.toList()),
    };
  }
  
  static Map<String, dynamic> analyzeKeywordFrequency(List<VideoAnalysisResult> results) {
    final keywordFreq = <String, int>{};
    final coOccurrence = <String, Set<String>>{};
    
    for (final result in results) {
      final keywords = result.keywords;
      for (int i = 0; i < keywords.length; i++) {
        final keyword = keywords[i];
        keywordFreq[keyword] = (keywordFreq[keyword] ?? 0) + 1;
        
        // 동시 출현 분석
        for (int j = i + 1; j < keywords.length; j++) {
          coOccurrence.putIfAbsent(keyword, () => <String>{}).add(keywords[j]);
          coOccurrence.putIfAbsent(keywords[j], () => <String>{}).add(keyword);
        }
      }
    }
    
    return {
      'frequency': keywordFreq,
      'coOccurrence': coOccurrence.map((k, v) => MapEntry(k, v.length)),
      'tfIdf': _calculateTfIdf(keywordFreq, results.length),
    };
  }
}

// 감성 비교 분석 구현
class SentimentComparisonAnalyzer {
  static Map<String, Map<String, double>> compareMultipleKeywords(
    Map<String, List<VideoAnalysisResult>> keywordResults
  ) {
    final comparison = <String, Map<String, double>>{};
    
    keywordResults.forEach((keyword, results) => {
      comparison[keyword] = {
        'positiveRatio': results.where((r) => r.sentimentScore > 0.5).length / results.length,
        'averageSentiment': results.map((r) => r.sentimentScore).reduce((a, b) => a + b) / results.length,
        'emotionalVariance': _calculateVariance(results.map((r) => r.sentimentScore).toList()),
        'controversyIndex': _calculateControversyIndex(results),
      }
    });
    
    return comparison;
  }
  
  static List<Map<String, dynamic>> analyzeTrendByTimeframe(
    List<VideoAnalysisResult> results, 
    String timeframe // 'daily', 'weekly', 'monthly'
  ) {
    final groupedData = <String, List<VideoAnalysisResult>>{};
    
    for (final result in results) {
      final timeKey = _getTimeKey(result.publishedAt, timeframe);
      groupedData.putIfAbsent(timeKey, () => []).add(result);
    }
    
    return groupedData.entries.map((entry) => {
      'period': entry.key,
      'averageSentiment': entry.value.map((r) => r.sentimentScore).reduce((a, b) => a + b) / entry.value.length,
      'totalVideos': entry.value.length,
      'dominantEmotion': _getDominantEmotion(entry.value),
    }).toList();
  }
}

// 애니메이션 최적화
class OptimizedEmotionChart extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: EmotionChartPainter(
          emotions: emotions,
          animation: animation,
        ),
        child: Container(), // 정적 콘텐츠
      ),
    );
  }
}
```

## 📊 성능 측정 지표

### 개선 전후 비교 목표
- **NLP 처리 시간**: 현재 5-10초 → 목표 1-2초
- **UI 응답성**: 현재 30-60fps → 목표 60fps 유지
- **메모리 사용량**: 현재 150MB → 목표 100MB 이하
- **앱 시작 시간**: 현재 3-5초 → 목표 2초 이하
- **📈 데이터 분석 처리 시간 (신규)**: 1000개 동영상 분석 → 목표 3초 이하
- **🔄 실시간 비교 차트 렌더링 (신규)**: 다중 키워드 비교 → 목표 1초 이하

### 모니터링 도구
- Flutter DevTools Performance 탭
- Firebase Performance Monitoring
- 커스텀 성능 메트릭 수집
- **분포 분석 성능 메트릭 (신규)**: 히스토그램 계산, 통계 연산 시간 측정

## 🎨 UX/UI 개선 사항

### 접근성 고려사항
- 색맹 사용자를 위한 패턴/텍스처 추가
- 고대비 모드 지원
- 스크린 리더 호환성
- 폰트 크기 조절 기능

### 사용자 피드백 수집
- 감정 시각화 선호도 조사
- A/B 테스트를 통한 색상 팔레트 최적화
- 사용성 테스트 결과 반영

## 📅 일정 계획

### Week 1-2: Phase 1 (성능 최적화)
- NLP 처리 부하 해결
- UI 성능 최적화
- 기본 성능 테스트

### Week 3-4: Phase 2 (감성 시각화)
- 색상 심리학 기반 팔레트 구현
- 인터랙티브 요소 추가
- 새로운 시각화 컴포넌트 개발

### Week 5-6: Phase 3 (아키텍처 개선)
- 상태 관리 개선
- 데이터베이스 통합
- 코드 리팩토링

### Week 7-8: Phase 4 (고급 기능)
- 3D 시각화 실험
- 실시간 감정 흐름 구현
- 최종 테스트 및 최적화

## ✅ 완료 체크리스트

각 작업 완료 시 다음 사항들을 확인:
- [x] **데이터 분포 분석 대시보드 계획 수립** ✓
- [x] **다차원 감성 비교 테이블 설계 완료** ✓
- [x] **데이터 분포 분석 대시보드 구현** ✅
- [x] **다차원 감성 비교 테이블 구현** ✅
- [x] **Flutter 웹 앱에 새 탭 2개 추가** ✅
- [x] **UI 컴포넌트 통합 및 테스트** ✅
- [ ] 성능 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] 관련 문서 업데이트
- [ ] 사용자 테스트 피드백 반영
- [ ] 접근성 검증 완료

---

이 TODO는 살아있는 문서입니다. 개발 진행상황에 따라 지속적으로 업데이트하며, 우선순위는 프로젝트 요구사항에 따라 조정될 수 있습니다. 