import 'keyword_sentiment.dart';
import 'youtube_data.dart';

class VideoAnalysisResult {
  final YoutubeData youtubeData;
  final List<KeywordSentiment> keywords;
  final String overallEmotion;

  VideoAnalysisResult({
    required this.youtubeData,
    required this.keywords,
    required this.overallEmotion,
  });
} 