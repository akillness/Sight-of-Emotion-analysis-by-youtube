import 'dart:math';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/youtube_data.dart';
import '../models/keyword_sentiment.dart';
import '../models/video_analysis_result.dart';
import '../utils/text_analyzer.dart';

class NlpService {
  final Random _random = Random();
  
  // Maximum number of keywords to analyze per video
  static const int MAX_KEYWORDS_PER_VIDEO = 5;
  static const int BATCH_SIZE = 10;

  // Default constructor (no DatabaseService)
  NlpService(); 

  // 성능 최적화: 병렬 처리와 배치 처리를 사용하여 NLP 분석 수행
  Future<List<VideoAnalysisResult>> analyzeVideoTitles(List<YoutubeData> youtubeItems) async {
    if (kDebugMode) {
      print('NlpService: Starting optimized analysis for ${youtubeItems.length} items.');
    }
    
    // Limit items to analyze to prevent memory issues
    final itemsToAnalyze = youtubeItems.length > 50 
        ? youtubeItems.sublist(0, 50) 
        : youtubeItems;
    
    // 배치 처리로 API 호출 최소화
    final batches = _createBatches(itemsToAnalyze, BATCH_SIZE);
    
    if (kDebugMode) {
      print('NlpService: Processing ${batches.length} batches of max ${BATCH_SIZE} items each.');
    }
    
    // 배치들을 병렬로 처리
    final results = await Future.wait(
      batches.map((batch) => _processBatch(batch)),
    );
    
    // 결과 평탄화
    final flatResults = results.expand((x) => x).toList();
    
    if (kDebugMode) {
      print('NlpService: Optimized analysis finished. Generated ${flatResults.length} results.');
    }
    
    return flatResults;
  }
  
  // 배치 생성 헬퍼 메서드
  List<List<YoutubeData>> _createBatches(List<YoutubeData> items, int batchSize) {
    final batches = <List<YoutubeData>>[];
    for (int i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }
  
  // 배치 처리 - compute()를 사용하여 isolate에서 실행
  Future<List<VideoAnalysisResult>> _processBatch(List<YoutubeData> batch) async {
    try {
      // 큰 배치는 isolate에서 처리하여 UI 블록 방지
      if (batch.length >= 5) {
        return await compute(_analyzeInIsolate, batch);
      } else {
        // 작은 배치는 메인 스레드에서 처리 (오버헤드 방지)
        return await _analyzeInMain(batch);
      }
    } catch (e) {
      if (kDebugMode) {
        print('NlpService: Error processing batch: $e');
      }
      // 에러 발생 시 메인 스레드에서 재시도
      return await _analyzeInMain(batch);
    }
  }
  
  // isolate에서 실행되는 분석 함수 (최상위 또는 정적 함수여야 함)
  static Future<List<VideoAnalysisResult>> _analyzeInIsolate(List<YoutubeData> batch) async {
    final results = <VideoAnalysisResult>[];
    
    // 배치 내에서도 병렬 처리
    final futures = batch.map((item) async {
      try {
        // 키워드 추출과 감정 분석을 병렬로 수행
        final futures = await Future.wait([
          TextAnalyzer.extractKeywords(item.title),
          TextAnalyzer.analyzeEmotion(item.title).then((emotion) => {'emotion': emotion}),
        ]);
        
        final extractedData = futures[0] as Map<String, double>;
        final emotionData = futures[1] as Map<String, String>;
        final analyzedEmotion = emotionData['emotion'] ?? 'neutral';
        
        // Create KeywordSentiment objects directly from the extracted data
        List<KeywordSentiment> keywords = extractedData.entries.map((entry) {
          String keyword = entry.key;
          double score = entry.value;
          String keywordLower = keyword.toLowerCase();

          Sentiment sentiment = _calculateSentimentStatic(keywordLower);
          
          return KeywordSentiment(
            keyword: keyword,
            sentiment: sentiment,
            score: score,
          );
        }).toList();

        // Update the item's keywords list
        item.keywords = extractedData.keys.toList();

        return VideoAnalysisResult(
          youtubeData: item, 
          keywords: keywords,
          overallEmotion: analyzedEmotion,
        );
      } catch (e) {
        // 에러 시 기본값 반환
        return VideoAnalysisResult(
          youtubeData: item, 
          keywords: [],
          overallEmotion: 'neutral',
        );
      }
    });
    
    results.addAll(await Future.wait(futures));
    return results;
  }
  
  // 메인 스레드에서 실행되는 분석 함수
  Future<List<VideoAnalysisResult>> _analyzeInMain(List<YoutubeData> batch) async {
    final results = <VideoAnalysisResult>[];
    
    // 배치 내에서도 병렬 처리
    final futures = batch.map((item) async {
      try {
        // 키워드 추출과 감정 분석을 병렬로 수행
        final analysisResults = await Future.wait([
          TextAnalyzer.extractKeywords(item.title),
          TextAnalyzer.analyzeEmotion(item.title),
        ]);
        
        final extractedData = analysisResults[0] as Map<String, double>;
        final analyzedEmotion = analysisResults[1] as String;

        // Create KeywordSentiment objects directly from the extracted data
        List<KeywordSentiment> keywords = extractedData.entries.map((entry) {
          String keyword = entry.key;
          double score = entry.value;
          String keywordLower = keyword.toLowerCase();

          Sentiment sentiment = _calculateSentiment(keywordLower);
          
          return KeywordSentiment(
            keyword: keyword,
            sentiment: sentiment,
            score: score,
          );
        }).toList();

        // Update the item's keywords list
        item.keywords = extractedData.keys.toList();

        return VideoAnalysisResult(
          youtubeData: item, 
          keywords: keywords,
          overallEmotion: analyzedEmotion,
        );
      } catch (e) {
        if (kDebugMode) {
          print('NlpService: Error analyzing item "${item.title}": $e');
        }
        // 에러 시 기본값 반환
        return VideoAnalysisResult(
          youtubeData: item, 
          keywords: [],
          overallEmotion: 'neutral',
        );
      }
    });
    
    results.addAll(await Future.wait(futures));
    return results;
  }

  // --- Sentiment Analysis Methods ---

  Sentiment _calculateSentiment(String keyword) {
    return _calculateSentimentStatic(keyword);
  }
  
  // isolate에서 사용 가능한 정적 감정 분석 메서드
  static Sentiment _calculateSentimentStatic(String keyword) {
    // Simple placeholder sentiment analysis using keyword matching
    // In a real application, you would use a more sophisticated sentiment model
    final positiveWords = {
      // English
      'good', 'great', 'awesome', 'excellent', 'amazing', 'love', 'best', 'beautiful', 'happy',
      'wonderful', 'fantastic', 'perfect', 'fun', 'joy', 'exciting', 'positive', 'recommend',
      'like', 'enjoy', 'win', 'won', 'winning', 'success', 'successful',
      // Korean
      '좋은', '훌륭한', '멋진', '최고', '아름다운', '행복한', '즐거운', '재밌는', '재미있는', '긍정적인',
      '추천', '성공', '좋아', '좋아요', '승리', '이긴', '좋다', '최상', '기쁜', '행복', '재미'
    };
    
    final negativeWords = {
      // English
      'bad', 'awful', 'terrible', 'horrible', 'hate', 'worst', 'poor', 'sad', 'disaster',
      'disappointing', 'negative', 'boring', 'fail', 'failed', 'failure', 'lose', 'lost',
      'losing', 'problem', 'issue', 'difficult', 'hard', 'angry', 'mad', 'upset', 'scared',
      // Korean
      '나쁜', '끔찍한', '형편없는', '싫은', '최악', '실망', '부정적인', '지루한', '실패', '잃은',
      '문제', '이슈', '어려운', '힘든', '화난', '화가', '화', '슬픈', '무서운', '걱정', '불안'
    };
    
    for (var word in positiveWords) {
      if (keyword.contains(word)) {
        return Sentiment.positive;
      }
    }
    
    for (var word in negativeWords) {
      if (keyword.contains(word)) {
        return Sentiment.negative;
      }
    }
    
    return Sentiment.neutral;
  }
  
  // Optional: Method to slightly adjust score for visual purposes (e.g., randomness)
  // If you want the score *exactly* as from the transformer, remove this call
  /*
  double _adjustScoreVisually(double originalScore, Sentiment sentiment) {
    double adjustedScore = originalScore;
    // Example: Add minor adjustment based on sentiment
    if (sentiment == Sentiment.positive) adjustedScore += 0.05;
    if (sentiment == Sentiment.negative) adjustedScore -= 0.05;
    // Add slight randomness
    adjustedScore += (_random.nextDouble() * 0.1) - 0.05;
    return adjustedScore.clamp(-1.0, 1.0); // Clamp to valid range
  }
  */

  // REMOVED faulty analyzeVideos method
} 