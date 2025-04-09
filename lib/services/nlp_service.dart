import 'dart:math';
import '../models/video_info.dart';
import '../models/keyword_sentiment.dart';
import '../models/video_analysis_result.dart';

class NlpService {
  final Random _random = Random();

  // Simulates NLP analysis (keyword extraction and sentiment)
  Future<List<VideoAnalysisResult>> analyzeVideos(List<VideoInfo> videos) async {
    List<VideoAnalysisResult> results = [];
    for (var video in videos) {
      // Very basic keyword extraction: split title by spaces and common punctuation
      List<String> potentialKeywords = video.title
          .replaceAll(RegExp(r'[?!,.:]'), '') // Remove basic punctuation
          .split(' ')
          .where((word) => word.isNotEmpty && word.length > 1) // Filter out empty strings and single chars
          .toList();

      // Simulate sentiment/emotion analysis for each keyword
      List<KeywordSentiment> keywords = potentialKeywords.map((keyword) {
        Sentiment sentiment = Sentiment.values[_random.nextInt(Sentiment.values.length)];
        Emotion emotion = Emotion.values[_random.nextInt(Emotion.values.length)];
        double score = (_random.nextDouble() * 2) - 1; // Random score between -1.0 and 1.0

        // Make score slightly biased by simulated sentiment for better visualization
        if (sentiment == Sentiment.positive) score = score.abs(); // More positive
        if (sentiment == Sentiment.negative) score = -score.abs(); // More negative

        return KeywordSentiment(
          keyword: keyword,
          sentiment: sentiment,
          emotion: emotion,
          score: score, // Use score for size/intensity
        );
      }).toList();

      results.add(VideoAnalysisResult(videoInfo: video, keywords: keywords));
    }
    return results;
  }
} 