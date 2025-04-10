import 'dart:math';
import '../models/youtube_data.dart';
import '../models/keyword_sentiment.dart';
import '../models/video_analysis_result.dart';
import '../utils/text_analyzer.dart';
import 'package:flutter/foundation.dart';

class NlpService {
  final Random _random = Random();
  
  // Maximum number of keywords to analyze per video
  static const int MAX_KEYWORDS_PER_VIDEO = 5;

  // Default constructor (no DatabaseService)
  NlpService(); 

  // Method updated to analyze YoutubeData titles
  Future<List<VideoAnalysisResult>> analyzeVideoTitles(List<YoutubeData> youtubeItems) async {
    if (kDebugMode) {
      print('NlpService: Starting analysis for ${youtubeItems.length} items.');
    }
    
    // Limit items to analyze to prevent memory issues
    final itemsToAnalyze = youtubeItems.length > 50 
        ? youtubeItems.sublist(0, 50) 
        : youtubeItems;
    
    List<VideoAnalysisResult> results = [];
    for (var i = 0; i < itemsToAnalyze.length; i++) {
      var item = itemsToAnalyze[i];
      
      // Always use TextAnalyzer to get keywords and scores for the title
      Map<String, double> extractedData = await TextAnalyzer.extractKeywords(item.title);

      // Analyze overall emotion for the title
      final analyzedEmotion = await TextAnalyzer.analyzeEmotion(item.title);

      // Create KeywordSentiment objects directly from the extracted data
      List<KeywordSentiment> keywords = extractedData.entries.map((entry) {
        String keyword = entry.key;
        double score = entry.value; // Use the score from TextAnalyzer
        String keywordLower = keyword.toLowerCase();

        Sentiment sentiment = _calculateSentiment(keywordLower);
        
        return KeywordSentiment(
          keyword: keyword, // Keep original casing for display
          sentiment: sentiment,
          score: score, // Use the score directly
        );
      }).toList();

      // Update the item's keywords list based on the analysis (optional, but good for consistency)
      item.keywords = extractedData.keys.toList();

      results.add(VideoAnalysisResult(
        youtubeData: item, 
        keywords: keywords,
        overallEmotion: analyzedEmotion, // Pass the analyzed emotion
      )); 
    }
    
    if (kDebugMode) {
      print('NlpService: Analysis finished. Generated ${results.length} results.');
    }
    return results;
  }
  
  // --- Sentiment Analysis Methods ---

  Sentiment _calculateSentiment(String keyword) {
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