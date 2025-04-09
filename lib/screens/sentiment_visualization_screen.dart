import 'package:flutter/material.dart';
import 'dart:math' as math; // For random rotation
import '../models/video_analysis_result.dart';
import '../models/keyword_sentiment.dart';
import '../services/youtube_service.dart';
import '../services/nlp_service.dart';

class SentimentVisualizationScreen extends StatefulWidget {
  const SentimentVisualizationScreen({super.key});

  @override
  State<SentimentVisualizationScreen> createState() =>
      _SentimentVisualizationScreenState();
}

class _SentimentVisualizationScreenState extends State<SentimentVisualizationScreen> {
  late Future<List<VideoAnalysisResult>> _analysisFuture;
  final YoutubeService _youtubeService = YoutubeService();
  final NlpService _nlpService = NlpService();
  final math.Random _random = math.Random(); // For subtle rotation

  @override
  void initState() {
    super.initState();
    _analysisFuture = _fetchAndAnalyzeVideos();
  }

  Future<List<VideoAnalysisResult>> _fetchAndAnalyzeVideos() async {
    final videos = await _youtubeService.fetchGamingVideos();
    final analysisResults = await _nlpService.analyzeVideos(videos);
    analysisResults.forEach((result) {
       result.keywords.sort((a, b) => b.score.compareTo(a.score));
    });
    return analysisResults;
  }

  // --- Styling Helper Functions (Figma-Inspired Aesthetics) ---

  LinearGradient _getBackgroundGradient(KeywordSentiment keyword) {
    Color baseColor;
    switch (keyword.sentiment) {
      case Sentiment.positive:
        baseColor = Colors.green.shade100;
        break;
      case Sentiment.negative:
        baseColor = Colors.red.shade100;
        break;
      case Sentiment.neutral:
      default:
        baseColor = Colors.grey.shade200;
        break;
    }
    // Create a subtle gradient
    return LinearGradient(
      colors: [baseColor.withOpacity(0.8), baseColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getTextColor(KeywordSentiment keyword) {
    // Clear text colors
    switch (keyword.sentiment) {
      case Sentiment.positive:
        return Colors.green.shade900;
      case Sentiment.negative:
        return Colors.red.shade900;
      case Sentiment.neutral:
      default:
        return Colors.grey.shade800;
    }
  }

  Color _getBorderColor(KeywordSentiment keyword) {
    // Subtle border colors matching text/sentiment
     switch (keyword.sentiment) {
      case Sentiment.positive:
        return Colors.green.shade300.withOpacity(0.5);
      case Sentiment.negative:
        return Colors.red.shade300.withOpacity(0.5);
      case Sentiment.neutral:
      default:
        return Colors.grey.shade400.withOpacity(0.5);
    }
  }

  // Font size based on absolute score for prominence
  double _getFontSize(double score) {
    const double minFontSize = 12.0;
    const double maxFontSize = 24.0; // Slightly reduced max for potentially denser layout
    // Normalize absolute score [0, 1] to influence size
    double normalizedAbsScore = score.abs();
    // Apply a curve for more visual difference
    return minFontSize + (maxFontSize - minFontSize) * math.pow(normalizedAbsScore, 1.5);
  }

  FontWeight _getFontWeight(double score) {
    // Bolder for higher absolute scores
    if (score.abs() > 0.6) return FontWeight.w600;
    if (score.abs() > 0.3) return FontWeight.w500;
    return FontWeight.normal;
  }

  double _getElevation(double score) {
    // More elevation for more impactful keywords
     return 1.0 + (score.abs() * 3.0); // Reduced elevation slightly
  }

  BorderRadius _getBorderRadius(double score) {
    // More consistent radius, less variable
    return BorderRadius.circular(12.0);
  }

  EdgeInsets _getPadding(double score) {
    // Padding increases with importance
    double horizontalPadding = 8.0 + (score.abs() * 6.0);
    double verticalPadding = 4.0 + (score.abs() * 3.0);
    return EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding);
  }

  // --- Positioning Logic ---

  // Calculate position for a keyword within the available constraints
  Offset _calculateKeywordPosition(KeywordSentiment keyword, BoxConstraints constraints, int index, int totalKeywords) {
    final score = keyword.score;
    final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
    final maxRadius = math.min(center.dx, center.dy) * 0.85; // Max distance from center

    // Angle based on sentiment (crude mapping)
    double angle;
    switch (keyword.sentiment) {
      case Sentiment.positive:
        angle = math.pi / 4 + (_random.nextDouble() * math.pi / 4); // Top-right quadrant
        break;
      case Sentiment.negative:
        angle = 5 * math.pi / 4 + (_random.nextDouble() * math.pi / 4); // Bottom-left quadrant
        break;
      case Sentiment.neutral:
      default:
        angle = 3 * math.pi / 2 + (_random.nextDouble() * math.pi); // Spread across bottom/top-center
        break;
    }
    // Add variation based on index to spread items
    angle += (index / totalKeywords) * math.pi * 0.1;

    // Radius based on absolute score (higher score = further from center)
    final radius = maxRadius * (0.3 + score.abs() * 0.7);

    // Convert polar to cartesian, relative to center
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);

    // Calculate final offset, ensuring it stays roughly within bounds
    // Note: This doesn't account for widget size, so overlap is possible
    final finalX = (center.dx + dx).clamp(0.0, constraints.maxWidth);
    final finalY = (center.dy + dy).clamp(0.0, constraints.maxHeight);

    return Offset(finalX, finalY);
 }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: const Color(0xFFF8F9FA), // Very light grey background
      body: FutureBuilder<List<VideoAnalysisResult>>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF4A6FFF)));
          } else if (snapshot.hasError) {
            return Center(child: Text('분석 로딩 오류: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('분석 결과가 없습니다.', style: TextStyle(color: Colors.grey)));
          }

          final analysisResults = snapshot.data!;
          List<KeywordSentiment> allKeywords = analysisResults
              .expand((result) => result.keywords)
              .take(50).toList(); // Limit keywords to avoid excessive overlap

          // Use LayoutBuilder to get constraints for positioning
          return LayoutBuilder(
             builder: (context, constraints) {
               // Ensure constraints are valid before proceeding
              if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) {
                 return const Center(child: Text('Layout Error'));
               }

               // Pre-calculate positions to potentially adjust for overlap later (basic)
               final List<Widget> positionedItems = [];
               for (int i = 0; i < allKeywords.length; i++) {
                 final keyword = allKeywords[i];
                 final score = keyword.score;
                 final position = _calculateKeywordPosition(keyword, constraints, i, allKeywords.length);

                  // Basic check - if too close to center for low score, push out slightly
                 double distance = (position - Offset(constraints.maxWidth / 2, constraints.maxHeight / 2)).distance;
                 if (score.abs() < 0.3 && distance < 50) {
                   // Skip or adjust - for now, just skip to reduce clutter
                   // continue;
                 }

                 positionedItems.add(
                   Positioned(
                     left: position.dx - 50, // Approximate half-width for centering
                     top: position.dy - 20, // Approximate half-height
                     child: Material(
                       elevation: _getElevation(score),
                       shadowColor: Colors.black.withOpacity(0.1),
                       borderRadius: _getBorderRadius(score),
                       // Use Container for gradient background
                       child: Container(
                          decoration: BoxDecoration(
                           gradient: _getBackgroundGradient(keyword),
                           borderRadius: _getBorderRadius(score),
                           border: Border.all(color: _getBorderColor(keyword), width: 1.0),
                         ),
                         child: Padding(
                           padding: _getPadding(score),
                           child: Text(
                             keyword.keyword,
                             textAlign: TextAlign.center,
                             style: TextStyle(
                               fontSize: _getFontSize(score),
                               fontWeight: _getFontWeight(score),
                               color: _getTextColor(keyword),
                             ),
                           ),
                         ),
                       ),
                     ),
                   ),
                 );
               }

              // Build the Stack with positioned items
              return Container(
                 width: constraints.maxWidth,
                 height: constraints.maxHeight,
                 child: Stack(
                   children: positionedItems,
                 ),
               );
             },
           );
        },
      ),
    );
  }
} 