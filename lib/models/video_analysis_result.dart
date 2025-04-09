import '../models/youtube_data.dart';
import 'keyword_sentiment.dart';

class VideoAnalysisResult {
  final YoutubeData youtubeData;
  final List<KeywordSentiment> keywords;

  VideoAnalysisResult({required this.youtubeData, required this.keywords});
} 