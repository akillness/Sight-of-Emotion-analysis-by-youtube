enum Sentiment {
  positive,
  negative,
  neutral
}

class KeywordSentiment {
  final String keyword;
  final Sentiment sentiment;
  final double score; // A general score combining sentiment/emotion for visualization

  KeywordSentiment({
    required this.keyword,
    required this.sentiment,
    required this.score,
  });
} 