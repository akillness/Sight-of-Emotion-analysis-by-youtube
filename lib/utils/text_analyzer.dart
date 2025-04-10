/// 텍스트 분석 유틸리티 클래스 - 향상된 키워드 추출
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http; // http 패키지 다시 사용
import 'package:flutter/foundation.dart';
import 'dart:collection'; // Import for LinkedHashMap
import '../config/api_keys.dart'; // Import API keys

class TextAnalyzer {
  // 키워드 추출 API 엔드포인트 (기존)
  static const String _keywordApiUrl = 'https://api-inference.huggingface.co/models/klue/roberta-base';
  // 감정 분석 API 엔드포인트 (새 모델)
  static const String _emotionApiUrl = 'https://api-inference.huggingface.co/models/j-hartmann/emotion-english-distilroberta-base';
  
  // HuggingFace API 키 (설정 파일에서 가져옴)
  static const String _apiKey = huggingFaceApiKey;
  
  // API 호출 타임아웃
  static const Duration _keywordApiTimeout = Duration(seconds: 5);
  static const Duration _emotionApiTimeout = Duration(seconds: 5); // 감정 분석 타임아웃 추가

  /// 텍스트에서 키워드 추출 (API 시도 후 로컬 폴백)
  static Future<Map<String, double>> extractKeywords(String text) async {
    if (kDebugMode) {
      print('TextAnalyzer: Extracting keywords START for text (length: ${text.length})');
      if (text.length < 100) { 
        print('TextAnalyzer: Input text: "$text"');
      }
    }
    
    final normalizedText = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalizedText.isEmpty) {
      if (kDebugMode) {
          print('TextAnalyzer: Normalized text is empty, returning empty keywords.');
      }
      return {};
    }

    // 미리 텍스트 분할 (최적화)
    final wordsInText = normalizedText.split(' ');

    final candidates = _extractCandidateKeywords(normalizedText);
    if (kDebugMode) {
        print('TextAnalyzer: Found ${candidates.length} candidate keywords: ${candidates.take(10).join(', ')}...');
    }
    
    if (candidates.isEmpty) {
        if (kDebugMode) {
            print('TextAnalyzer: No candidates found.');
        }
        return {};
    }

    // Transformer 모델 API를 사용하여 순위 매기기 시도 (빠른 폴백 포함)
    final rankedScores = await _rankKeywordsWithTransformer(candidates, normalizedText, wordsInText);

    final top5Keywords = Map.fromEntries(rankedScores.entries.take(5));
    if (kDebugMode) {
        print('TextAnalyzer: Extracting keywords END. Top 5: ${top5Keywords.keys.join(', ')}');
    }
    return top5Keywords;
  }
  
  /// Transformer 모델 API를 사용해 키워드 중요도 계산 시도 및 폴백 처리 (최적화)
  static Future<Map<String, double>> _rankKeywordsWithTransformer(
    List<String> candidates, 
    String originalText,
    List<String> wordsInText // 분할된 텍스트 전달 (최적화)
  ) async {
    final scores = <String, double>{};
    final topCandidates = candidates.take(5).toList(); // 상위 5개만 API 시도
    bool apiSuccess = false;

    if (topCandidates.isNotEmpty && _apiKey.isNotEmpty && !_apiKey.contains('YOUR')) { // API 키가 유효할 때만 시도
        if (kDebugMode) {
            print('TextAnalyzer: Attempting API batch ranking for top ${topCandidates.length} candidates using $_keywordApiUrl'); // URL 변수 사용
        }
        try {
            // 배치 입력 생성 (키워드를 [MASK]로 대체)
            final batchInputs = topCandidates.map((keyword) {
                final maskedText = originalText.replaceFirst(keyword, '[MASK]');
                return maskedText != originalText ? maskedText : '$originalText [MASK] $keyword'; // 폴백 형식
            }).toList();
            
            final response = await http.post(
                Uri.parse(_keywordApiUrl), // URL 변수 사용
                headers: {
                'Authorization': 'Bearer $_apiKey',
                'Content-Type': 'application/json',
                },
                body: jsonEncode({
                'inputs': batchInputs,
                'options': {'wait_for_model': true} 
                }),
            ).timeout(_keywordApiTimeout); // 타임아웃 변수 사용

            if (response.statusCode == 200) {
                final results = jsonDecode(response.body);
                if (results is List && results.length == topCandidates.length) {
                    if (kDebugMode) {
                        print('TextAnalyzer: Keyword API batch request successful.');
                    }
                    for (int i = 0; i < results.length; i++) {
                        final keyword = topCandidates[i];
                        final result = results[i];
                        double apiScore = 0.0;
                        // 응답 파싱 (fill-mask 형식 가정)
                        try {
                            if (result is List) {
                                final matchingPrediction = result.firstWhere(
                                    (prediction) => prediction is Map && prediction['token_str'] == keyword,
                                    orElse: () => null,
                                );
                                if (matchingPrediction != null) {
                                    apiScore = (matchingPrediction['score'] as num?)?.toDouble() ?? 0.0;
                                }
                            }
                        } catch (e) {
                            if (kDebugMode) {
                                print('TextAnalyzer: Error parsing API score for "$keyword": $e');
                            }
                        }
                        scores[keyword] = apiScore + _precomputeScore(keyword); // API 점수 + 기본 점수
                    }
                    apiSuccess = true; // API 성공 플래그 설정
                } else {
                    if (kDebugMode) {
                        print('TextAnalyzer: Keyword API batch response format mismatch (Expected List[${topCandidates.length}], Got: ${results.runtimeType}).');
                    }
                }
            } else {
                if (kDebugMode) {
                    print('TextAnalyzer: Keyword API batch request failed with status ${response.statusCode}.');
                }
            }
        } catch (e) {
            if (kDebugMode) {
                if (e is TimeoutException) {
                    print('TextAnalyzer: Keyword API batch request timed out after $_keywordApiTimeout.'); // 타임아웃 변수 사용
                } else {
                    print('TextAnalyzer: Keyword API batch request error: $e'); // 명확화
                }
            }
        }
    } else {
         if (kDebugMode) {
            print('TextAnalyzer: Skipping API call (No candidates, or API key invalid).');
        }
    }

    // API 호출 실패 시 또는 나머지 후보들에 대해 로컬 점수 계산 (최적화)
    if (!apiSuccess) {
        if (kDebugMode) {
            print('TextAnalyzer: Keyword API call failed or skipped. Calculating all scores using local rules.');
        }
        for (final keyword in candidates) {
            scores[keyword] = _calculateBasicScore(keyword, originalText, wordsInText);
        }
    } else {
        if (kDebugMode) {
            print('TextAnalyzer: Keyword API call successful for top ${topCandidates.length}. Calculating remaining scores locally.');
        }
        for (final keyword in candidates) {
            if (!scores.containsKey(keyword)) {
                scores[keyword] = _calculateBasicScore(keyword, originalText, wordsInText);
            }
        }
    }
    
    // 모든 점수를 내림차순으로 정렬
    final sortedEntries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
      
    return LinkedHashMap.fromEntries(sortedEntries);
  }

  /// 키워드의 기본 가중치를 미리 계산 (API 점수와 합산용)
  static double _precomputeScore(String keyword) {
    double score = keyword.length * 0.05; // 길이 가중치
    if (keyword.contains(RegExp(r'[가-힣]')) && keyword.contains(RegExp(r'[a-zA-Z]'))) {
      score += 0.5; // 복합어 가중치
    }
    return score;
  }
  
  /// 후보 키워드 추출
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

    // 중복 제거 및 반환
    return {...koreanKeywords, ...englishKeywords, ...compoundKeywords}.toList();
  }

  /// 불용어 확인
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

  /// 복합 키워드 추출
  static List<String> _extractCompoundKeywords(String text) {
    final compoundPattern = RegExp(r'[가-힣]+[a-zA-Z]+|[a-zA-Z]+[가-힣]+');
    return compoundPattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((word) => word.length >= 4)
        .toList();
  }

  /// 기본 점수 계산 (API 호출 없이) (최적화)
  static double _calculateBasicScore(String keyword, String text, List<String> wordsInText) {
    double score = 0;
    score += keyword.length * 0.2; // 길이
    if (text.startsWith(keyword)) score += 3; // 시작 위치
    if (text.endsWith(keyword)) score += 2; // 끝 위치
    final frequency = wordsInText.where((w) => w.contains(keyword)).length; // 최적화된 방식
    score += frequency * 0.8;
    if (keyword.contains(RegExp(r'[가-힣]')) && keyword.contains(RegExp(r'[a-zA-Z]'))) { // 복합어
      score += 2.0;
    }
    return score;
  }

  /// 텍스트 감정 분석 (영어 레이블 사용)
  static Future<String> analyzeEmotion(String text) async {
    if (text.isEmpty) {
      return 'neutral'; // 빈 텍스트는 중립으로 처리
    }
    
    if (kDebugMode) {
      print('TextAnalyzer: Analyzing emotion for text (length: ${text.length})');
       if (text.length < 100) {
        print('TextAnalyzer: Input text: "$text"');
      }
    }

    if (_apiKey.isEmpty || _apiKey.contains('YOUR')) {
       if (kDebugMode) {
        print('TextAnalyzer: Skipping emotion analysis (API key invalid). Returning neutral.');
      }
      return 'neutral';
    }

    try {
      final response = await http.post(
        Uri.parse(_emotionApiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'inputs': text,
          'options': {'wait_for_model': true}
        }),
      ).timeout(_emotionApiTimeout);

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body);
        // 모델 응답 형식: [[{'label': 'joy', 'score': 0.9}, ...]]
        if (results is List && results.isNotEmpty && results[0] is List && results[0].isNotEmpty) {
          final topResult = results[0][0];
          if (topResult is Map && topResult.containsKey('label')) {
            final label = topResult['label'] as String;
            if (kDebugMode) {
              print('TextAnalyzer: Emotion analysis successful. Top emotion: $label');
            }
            return label; // 영어 레이블 반환
          }
        }
        if (kDebugMode) {
            print('TextAnalyzer: Emotion API response format unexpected: $results');
        }
        return 'neutral'; // 예상치 못한 형식
      } else {
        if (kDebugMode) {
          print('TextAnalyzer: Emotion API request failed with status ${response.statusCode}. Body: ${response.body}');
        }
        return 'neutral'; // API 실패
      }
    } catch (e) {
      if (kDebugMode) {
        if (e is TimeoutException) {
           print('TextAnalyzer: Emotion API request timed out after $_emotionApiTimeout.');
        } else {
           print('TextAnalyzer: Emotion API request error: $e');
        }
      }
      return 'neutral'; // 오류 발생
    }
  }
} 