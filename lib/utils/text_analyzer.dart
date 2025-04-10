/// 텍스트 분석 유틸리티 클래스 - 향상된 키워드 추출
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TextAnalyzer {
  // API 엔드포인트 URL
  static const String _apiUrl = 'https://api-inference.huggingface.co/models/beomi/KcELECTRA-base-v2022';
  
  // 여기에 HuggingFace API 키를 입력 (없으면 폴백 방식 사용)
  static const String _apiKey = '';
  
  /// 텍스트에서 키워드 추출
  static Future<List<String>> extractKeywords(String text) async {
    try {
      // API 키가 없으면 기존 방식 사용
      if (_apiKey.isEmpty) {
        return _extractKeywordsWithPatternMatching(text);
      }
      
      // 1. 기본 전처리
      final normalizedText = text.toLowerCase()
          .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ') // 특수문자 제거
          .replaceAll(RegExp(r'\s+'), ' ') // 연속된 공백 제거
          .trim();
          
      // 2. 우선 기존 패턴 매칭 방식으로 후보 키워드 추출
      final candidates = _extractCandidateKeywords(normalizedText);
      
      // 3. 모델 기반 키워드 중요도 계산
      final keywords = await _rankKeywordsWithTransformer(candidates, normalizedText);
      
      return keywords.take(5).toList();
    } catch (e) {
      // API 오류 발생 시 기존 방식으로 폴백
      if (kDebugMode) {
        print('Transformer API error: $e, falling back to pattern matching');
      }
      return _extractKeywordsWithPatternMatching(text);
    }
  }
  
  /// Transformer 모델을 사용해 키워드 중요도 계산
  static Future<List<String>> _rankKeywordsWithTransformer(
    List<String> candidates, 
    String originalText
  ) async {
    final scores = <String, double>{};
    
    try {
      // API 호출 횟수를 줄이기 위해 일괄 처리
      final batchPrompts = candidates.map((keyword) => 
          '$originalText [MASK]는 $keyword입니다.').toList();
      
      // API 호출 (최대 5개 키워드만 처리)
      final topCandidates = candidates.take(5).toList();
      for (final keyword in topCandidates) {
        try {
          final response = await http.post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': '$originalText [MASK]는 $keyword입니다.',
              'options': {'wait_for_model': true}
            }),
          );
          
          if (response.statusCode == 200) {
            final result = jsonDecode(response.body);
            if (result is List && result.isNotEmpty) {
              final firstResult = result.first;
              double score = firstResult['score'] ?? 0.0;
              
              // 키워드 길이와 복합성도 고려
              score += keyword.length * 0.05;
              if (keyword.contains(RegExp(r'[가-힣]')) && keyword.contains(RegExp(r'[a-zA-Z]'))) {
                score += 0.5;
              }
              
              scores[keyword] = score;
            }
          }
        } catch (e) {
          // 개별 API 호출 실패 시 기본 점수 할당
          scores[keyword] = keyword.length * 0.2;
        }
        
        // API 호출 사이 짧은 딜레이
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // 점수가 없는 나머지 키워드에 대해 기본 점수 계산
      for (final keyword in candidates) {
        if (!scores.containsKey(keyword)) {
          scores[keyword] = _calculateBasicScore(keyword, originalText);
        }
      }
      
      // 점수 기준 정렬
      final sortedKeywords = scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return sortedKeywords.map((e) => e.key).toList();
    } catch (e) {
      // 에러 시 기존 방식으로 계산한 점수로 정렬
      return _calculateFallbackScores(candidates, originalText);
    }
  }
  
  /// 기본 점수 계산 (API 호출 없이)
  static double _calculateBasicScore(String keyword, String text) {
    double score = 0;
    
    // 길이 점수
    score += keyword.length * 0.2;
    
    // 위치 점수
    if (text.startsWith(keyword)) score += 3;
    if (text.endsWith(keyword)) score += 2;
    
    // 빈도 점수
    final frequency = text.split(' ').where((w) => w.contains(keyword)).length;
    score += frequency * 0.8;
    
    // 복합어 점수
    if (keyword.contains(RegExp(r'[가-힣]')) && keyword.contains(RegExp(r'[a-zA-Z]'))) {
      score += 2.0;
    }
    
    return score;
  }
  
  /// 후보 키워드 추출 (기존 패턴 매칭 방식)
  static List<String> _extractCandidateKeywords(String text) {
    // 1. 한국어 키워드 추출 (2글자 이상)
    final koreanKeywords = RegExp(r'[가-힣]{2,}')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((word) => !_isStopWord(word))
        .toList();

    // 2. 영어 키워드 추출 (3글자 이상)
    final englishKeywords = RegExp(r'\b[a-zA-Z]{3,}\b')
        .allMatches(text)
        .map((m) => m.group(0)!.toLowerCase())
        .where((word) => !_isStopWord(word))
        .toList();

    // 3. 복합 키워드 추출 (한글 + 영어)
    final compoundKeywords = _extractCompoundKeywords(text);

    return [...koreanKeywords, ...englishKeywords, ...compoundKeywords];
  }
  
  /// 기존 방식으로 키워드 추출 (폴백용)
  static List<String> _extractKeywordsWithPatternMatching(String text) {
    // 1. 기본 전처리
    final normalizedText = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ') // 특수문자 제거
        .replaceAll(RegExp(r'\s+'), ' ') // 연속된 공백 제거
        .trim();

    // 2. 한국어 키워드 추출 (2글자 이상)
    final koreanKeywords = RegExp(r'[가-힣]{2,}')
        .allMatches(normalizedText)
        .map((m) => m.group(0)!)
        .where((word) => !_isStopWord(word))
        .toList();

    // 3. 영어 키워드 추출 (3글자 이상)
    final englishKeywords = RegExp(r'\b[a-zA-Z]{3,}\b')
        .allMatches(normalizedText)
        .map((m) => m.group(0)!.toLowerCase())
        .where((word) => !_isStopWord(word))
        .toList();

    // 4. 복합 키워드 추출 (한글 + 영어)
    final compoundKeywords = _extractCompoundKeywords(normalizedText);

    // 5. 키워드 중요도 점수 계산 및 정렬
    final allKeywords = [...koreanKeywords, ...englishKeywords, ...compoundKeywords];
    final keywordScores = _calculateKeywordScores(allKeywords, normalizedText);
    
    final sortedEntries = keywordScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries
        .take(5)
        .map((e) => e.key)
        .toList();
  }
  
  /// 폴백용 키워드 점수 계산
  static List<String> _calculateFallbackScores(List<String> keywords, String text) {
    final scores = _calculateKeywordScores(keywords, text);
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEntries.map((e) => e.key).toList();
  }

  /// 불용어 목록을 사용하여 키워드가 불용어인지 확인합니다.
  static bool _isStopWord(String word) {
    final stopWords = {
      // 영어 불용어
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'of', 'with', 'by', 'from', 'up', 'about', 'into', 'over', 'after',
      'before', 'during', 'through', 'throughout', 'within', 'without',
      'above', 'below', 'under', 'again', 'further', 'then', 'once',
      'here', 'there', 'when', 'where', 'why', 'how', 'all', 'any',
      'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such',
      'no', 'nor', 'not', 'only', 'own', 'same', 'so', 'than', 'too',
      'very', 'can', 'will', 'just', 'should', 'now',
      
      // 한국어 불용어
      '이', '그', '저', '것', '등', '들', '및', '에서', '으로', '에게', '에게서',
      '으로서', '으로써', '으로부터', '으로', '에서', '에게', '에게서',
      '이런', '저런', '그런', '어떤', '무슨', '어느', '이것', '저것', '그것',
      '여기', '저기', '거기', '언제', '어디', '누구', '무엇', '어떻게',
      '왜', '어째서', '어찌', '어째', '어찌나', '어찌하여', '어찌해서',
      '이렇게', '저렇게', '그렇게', '어떻게', '이리', '저리', '그리',
      '이만큼', '저만큼', '그만큼', '얼마나', '얼마', '몇', '몇 개',
      '몇 명', '몇 번', '몇 번째', '몇 시', '몇 분', '몇 초',
      '오늘', '어제', '내일', '모레', '글피', '작년', '작작년', '내년',
      '아침', '점심', '저녁', '새벽', '낮', '밤', '주말', '평일',
      '월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일',
      '1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월',
      '봄', '여름', '가을', '겨울',
    };
    return stopWords.contains(word.toLowerCase());
  }

  /// 복합 키워드(한글+영어 조합)를 추출합니다.
  static List<String> _extractCompoundKeywords(String text) {
    final compoundPattern = RegExp(r'[가-힣]+[a-zA-Z]+|[a-zA-Z]+[가-힣]+');
    return compoundPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((word) => word.length >= 4)
        .toList();
  }

  /// 키워드 중요도 점수를 계산합니다.
  static Map<String, double> _calculateKeywordScores(List<String> keywords, String title) {
    final scores = <String, double>{};
    final words = title.split(' ');
    final titleLength = title.length;
    
    for (final keyword in keywords) {
      double score = 0;
      
      // 1. 길이 점수 (키워드가 길수록 더 중요)
      score += keyword.length * 0.2;
      
      // 2. 위치 점수
      if (title.startsWith(keyword)) score += 3; // 제목 시작
      if (title.endsWith(keyword)) score += 2;   // 제목 끝
      
      // 3. 빈도 점수 (키워드가 자주 등장할수록 더 중요)
      final frequency = words.where((w) => w.contains(keyword)).length;
      score += frequency * 0.8;
      
      // 4. 복합어 점수 (한글+영어 조합은 더 중요)
      if (keyword.contains(RegExp(r'[가-힣]')) && keyword.contains(RegExp(r'[a-zA-Z]'))) {
        score += 2.0;
      }
      
      // 5. 제목 내 비중 점수 (전체 제목에서 차지하는 비중)
      final keywordRatio = keyword.length / titleLength;
      score += keywordRatio * 5;
      
      // 6. 대문자 포함 점수 (영문 키워드의 경우)
      if (keyword.contains(RegExp(r'[A-Z]'))) {
        score += 1.5;
      }
      
      // 7. 숫자 포함 점수 (숫자가 포함된 키워드는 더 중요할 수 있음)
      if (keyword.contains(RegExp(r'[0-9]'))) {
        score += 1.0;
      }
      
      scores[keyword] = score;
    }
    
    return scores;
  }
} 