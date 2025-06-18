import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:collection';
import '../config/api_keys.dart';

class TextAnalyzer {
  static const String _keywordApiUrl =
      'https://api-inference.huggingface.co/models/klue/roberta-base';
  static const String _emotionApiUrl = 
      'https://api-inference.huggingface.co/models/j-hartmann/emotion-english-distilroberta-base';

  static final String _apiKey = huggingFaceApiKey;

  static const Duration _keywordApiTimeout = Duration(seconds: 15);
  static const Duration _emotionApiTimeout = Duration(seconds: 15);

  static Future<List<String>> extractKeywords(String text) async {
    if (text.trim().isEmpty) {
      return [];
    }
    if (kDebugMode) {
      print('TextAnalyzer: Extracting keywords START for text (length: ${text.length})');
      if (text.length < 100) {
        print('TextAnalyzer: Input text: "$text"');
      }
    }
    List<String> candidateKeywords = _extractCandidateKeywords(text);
    if (kDebugMode) {
      print('TextAnalyzer: Found ${candidateKeywords.length} candidate keywords: ${candidateKeywords.take(5).join(', ')}...');
    }

    if (_apiKey.isNotEmpty && !_apiKey.contains('YOUR')) {
      try {
        if (kDebugMode) {
          print('TextAnalyzer: Attempting API batch ranking for top ${candidateKeywords.length} candidates using $_keywordApiUrl');
        }
        final response = await http.post(
          Uri.parse(_keywordApiUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'inputs': {
              'text': text,
              'candidate_labels': candidateKeywords,
            },
            'parameters': {'multi_label': true},
          }),
        ).timeout(_keywordApiTimeout);

        if (response.statusCode == 200) {
          final results = jsonDecode(response.body);
          if (results is Map && results.containsKey('labels') && results.containsKey('scores')) {
            List<String> labels = List<String>.from(results['labels']);
            List<double> scores = List<double>.from(results['scores']);
            Map<String, double> scoredKeywords = Map.fromIterables(labels, scores);
            var sortedKeywords = scoredKeywords.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            List<String> topKeywords = sortedKeywords.map((e) => e.key).take(5).toList();
             if (kDebugMode) {
              print('TextAnalyzer: Extracting keywords END. Top 5: ${topKeywords.join(', ')}');
            }
            return topKeywords;
          }
        } else {
           if (kDebugMode) {
            print('TextAnalyzer: Keyword API batch request failed with status ${response.statusCode}.');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('TextAnalyzer: Keyword API call failed or skipped. Calculating all scores using local rules.');
        }
      }
    }

    var wordScores = <String, int>{};
    for (var keyword in candidateKeywords) {
      wordScores[keyword] = text.split(keyword).length - 1;
    }
    var sortedEntries = wordScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    List<String> topKeywords = sortedEntries.map((e) => e.key).take(5).toList();
    if (kDebugMode) {
      print('TextAnalyzer: Extracting keywords END. Top 5: ${topKeywords.join(', ')}');
    }
    return topKeywords;
  }

  static List<String> _extractCandidateKeywords(String text) {
    RegExp koreanRegex = RegExp(r'[가-힣]+');
    List<String> words = koreanRegex.allMatches(text).map((m) => m.group(0)!).toList();
    return words.where((word) => word.length > 1).toSet().toList();
  }
  
  static Future<String> analyzeEmotion(String text) async {
    if (kDebugMode) {
      print('TextAnalyzer: Analyzing emotion for text (length: ${text.length})');
    }

    if (text.trim().isEmpty) {
      return 'neutral';
    }

    // API 요청을 위해 텍스트 길이 제한 및 정규화
    String normalizedText = text.replaceAll(RegExp(r'\\s+'), ' ').trim();
    
    var encoded = utf8.encode(normalizedText);
    if (encoded.length > 512) { 
      var end = 500;
      while (end > 0 && (encoded[end] & 0xC0) == 0x80) {
        end--;
      }
      normalizedText = utf8.decode(encoded.sublist(0, end), allowMalformed: true);
    }
    
    final truncatedText = normalizedText;
    if (kDebugMode) {
        print('TextAnalyzer: Truncated text for API (length: ${truncatedText.length}, bytes: ${utf8.encode(truncatedText).length}): "$truncatedText"');
    }

    if (_apiKey.isNotEmpty && !_apiKey.contains('YOUR')) {
      try {
        final response = await http.post(
          Uri.parse(_emotionApiUrl),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'inputs': truncatedText,
            'options': {'wait_for_model': true}
          }),
        ).timeout(_emotionApiTimeout);

        if (response.statusCode == 200) {
          final results = jsonDecode(response.body);
          if (results is List && results.isNotEmpty && results[0] is List && results[0].isNotEmpty) {
            final topResult = results[0][0];
            if (topResult is Map && topResult.containsKey('label')) {
              final label = topResult['label'] as String;
              if (kDebugMode) {
                print('TextAnalyzer: Emotion analysis successful. Top emotion: $label');
              }
              return label;
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
          return _analyzeEmotionFromKeywords(text);
        }
      } catch (e) {
        if (kDebugMode) {
          if (e is TimeoutException) {
             print('TextAnalyzer: Emotion API request timed out after $_emotionApiTimeout.');
          } else {
             print('TextAnalyzer: Emotion API request error: $e');
          }
        }
        return _analyzeEmotionFromKeywords(text);
      }
    } else {
        return _analyzeEmotionFromKeywords(text);
    }
  }

  static String _analyzeEmotionFromKeywords(String text) {
    if (kDebugMode) {
      print('TextAnalyzer: Falling back to keyword-based emotion analysis.');
    }
    final Map<String, List<String>> emotionKeywords = {
      'joy': ['기쁨', '행복', '즐거움', '최고', 'ㅋㅋㅋ', '웃음', '신남', '재미'],
      'sadness': ['슬픔', '눈물', '우울', '안타까움', 'ㅠㅠ', '그리움'],
      'anger': ['분노', '화남', '짜증', '역겹', '혐오'],
      'fear': ['공포', '무서움', '두려움', '소름', '귀신'],
      'surprise': ['놀람', '깜짝', '대박', '헐', '충격'],
      'love': ['사랑', '설렘', '감동'],
    };

    Map<String, int> emotionCounts = {
      for (var key in emotionKeywords.keys) key: 0
    };

    String lowerCaseText = text.toLowerCase();

    emotionKeywords.forEach((emotion, keywords) {
      for (var keyword in keywords) {
        if (lowerCaseText.contains(keyword)) {
          emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
        }
      }
    });

    // 가장 많이 발견된 감정 반환
    var sortedEmotions = emotionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEmotions.isNotEmpty && sortedEmotions.first.value > 0) {
      if (kDebugMode) {
        print('TextAnalyzer: Keyword-based emotion found: ${sortedEmotions.first.key}');
      }
      return sortedEmotions.first.key;
    }

    if (kDebugMode) {
      print('TextAnalyzer: No specific emotion keywords found. Defaulting to neutral.');
    }
    return 'neutral';
  }
}