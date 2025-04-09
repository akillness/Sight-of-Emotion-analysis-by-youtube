import 'video_info.dart';
import 'keyword_sentiment.dart';

class VideoAnalysisResult {
  final VideoInfo videoInfo;
  final List<KeywordSentiment> keywords;

  VideoAnalysisResult({required this.videoInfo, required this.keywords});
} 