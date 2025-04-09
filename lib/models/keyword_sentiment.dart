import 'package:flutter/material.dart';

enum Sentiment {
  positive,
  negative,
  neutral
}

enum Emotion {
  happiness,
  sadness,
  anger,
  surprise,
  neutral
}

class KeywordSentiment {
  final String keyword;
  final Sentiment sentiment;
  final Emotion emotion;
  final double score; // A general score combining sentiment/emotion for visualization

  KeywordSentiment({
    required this.keyword,
    required this.sentiment,
    required this.emotion,
    required this.score,
  });
} 