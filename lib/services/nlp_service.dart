import 'dart:math';
import '../models/youtube_data.dart';
import '../models/keyword_sentiment.dart';
import '../models/video_analysis_result.dart';
import '../utils/text_analyzer.dart';

class NlpService {
  final Random _random = Random();

  // Method updated to analyze YoutubeData titles
  Future<List<VideoAnalysisResult>> analyzeVideoTitles(List<YoutubeData> youtubeItems) async {
    List<VideoAnalysisResult> results = [];
    for (var item in youtubeItems) {
      // Use the video title for keyword extraction and analysis
      List<String> titleKeywords = TextAnalyzer.extractKeywords(item.title);

      // Use the predefined keywords list from YoutubeData if available and not empty
      List<String> sourceKeywords = item.keywords.isNotEmpty ? item.keywords : titleKeywords;

      List<KeywordSentiment> keywords = sourceKeywords.map((keyword) {
        String keywordLower = keyword.toLowerCase();

        Sentiment sentiment = _calculateSentiment(keywordLower);
        Emotion emotion = _calculateEmotion(keywordLower);
        double score = _calculateScore(keyword, sentiment);

        return KeywordSentiment(
          keyword: keyword, // Keep original casing for display
          sentiment: sentiment,
          emotion: emotion,
          score: score,
        );
      }).toList();

      // Filter out keywords with very low absolute scores if needed
      keywords.removeWhere((k) => k.score.abs() < 0.1);

      results.add(VideoAnalysisResult(youtubeData: item, keywords: keywords)); // Update constructor call
    }
    return results;
  }
  
  // --- Sentiment Analysis Methods ---

  Sentiment _calculateSentiment(String keywordLower) {
    // Simple keyword matching for sentiment
    const List<String> positiveWords = ['좋아요', '최고', 'ㅋㅋ', 'ㅎㅎ', '감사', '추천', '대박', '사랑', '멋져', '재밌', '웃겨'];
    const List<String> negativeWords = ['싫어요', '나빠', '별로', '최악', '노잼', '화나', '슬퍼', '짜증', '욕'];

    if (positiveWords.any((word) => keywordLower.contains(word))) {
      return Sentiment.positive;
    } else if (negativeWords.any((word) => keywordLower.contains(word))) {
      return Sentiment.negative;
    } else {
      return Sentiment.neutral;
    }
  }

  Emotion _calculateEmotion(String keywordLower) {
    // Simple keyword matching for emotion
    if (keywordLower.contains('웃겨') || keywordLower.contains('ㅋㅋ') || keywordLower.contains('ㅎㅎ') || keywordLower.contains('재밌')) return Emotion.happiness;
    if (keywordLower.contains('슬퍼') || keywordLower.contains('ㅜㅜ') || keywordLower.contains('ㅠㅠ')) return Emotion.sadness;
    if (keywordLower.contains('화나') || keywordLower.contains('짜증') || keywordLower.contains('욕')) return Emotion.anger;
    if (keywordLower.contains('놀랍') || keywordLower.contains('대박') || keywordLower.contains('헐')) return Emotion.surprise;
    if (keywordLower.contains('무서') || keywordLower.contains('소름')) return Emotion.fear;
    if (keywordLower.contains('사랑') || keywordLower.contains('좋아') || keywordLower.contains('기대')) return Emotion.anticipation;
    // Add more rules as needed
    return Emotion.neutral; // Default emotion
  }

  double _calculateScore(String keyword, Sentiment sentiment) {
    double score = 0.0;

    // Base score adjustment based on sentiment
    if (sentiment == Sentiment.positive) {
      score += 0.3;
    } else if (sentiment == Sentiment.negative) {
      score -= 0.3;
    }

    // Adjust score by keyword length (longer might be more specific)
    score += keyword.length * 0.02;

    // Adjust score by presence of exclamation marks (intensity)
    score += '!'.allMatches(keyword).length * 0.1;
    score -= '?'.allMatches(keyword).length * 0.05; // Questions might be less assertive

    // Add a small random factor for variety
    score += (_random.nextDouble() - 0.5) * 0.2;

    // Clamp score between -1.0 and 1.0
    return score.clamp(-1.0, 1.0);
  }
} 