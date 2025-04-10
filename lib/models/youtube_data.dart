import '../utils/text_analyzer.dart';

class YoutubeData {
  final String title;
  final String videoId;
  final int likes;
  final int views;
  List<String> keywords;
  final String timestamp;

  YoutubeData({
    required this.title,
    required this.videoId,
    required this.likes,
    required this.views,
    required this.keywords,
    required this.timestamp,
  });

  static YoutubeData fromVideoItem(Map<String, dynamic> item) {
    final snippet = item['snippet'] as Map<String, dynamic>;
    final statistics = item['statistics'] as Map<String, dynamic>;
    final title = snippet['title'] as String;
    final videoId = item['id'] as String;
    
    return YoutubeData(
      title: title,
      videoId: videoId,
      likes: int.tryParse(statistics['likeCount']?.toString() ?? '0') ?? 0,
      views: int.tryParse(statistics['viewCount']?.toString() ?? '0') ?? 0,
      keywords: [], // Initialize with empty list
      timestamp: snippet['publishedAt'] as String,
    );
  }
  
  // Method to extract keywords asynchronously
  Future<void> extractKeywordsFromTitle() async {
    if (keywords.isEmpty) {
      keywords = await TextAnalyzer.extractKeywords(title);
    }
  }
} 