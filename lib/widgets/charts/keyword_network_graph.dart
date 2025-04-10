import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/video_analysis_result.dart';

import '../../widgets/app_theme.dart';

class KeywordNetworkGraph extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;

  const KeywordNetworkGraph({super.key, required this.analysisResults});

  @override
  State<KeywordNetworkGraph> createState() => _KeywordNetworkGraphState();
}

class _KeywordNetworkGraphState extends State<KeywordNetworkGraph> {
  // Maximum number of nodes to display to prevent memory issues
  static const int maxNodes = 30;
  static const int minKeywordFreq = 2; // Minimum frequency required to display a keyword

  // 키워드에 관련된 맵
  Map<String, int> keywordFrequency = {};
  Map<String, Set<String>> coOccurrences = {};
  Map<String, double> keywordScores = {};
  Map<String, int> connectionCounts = {};
  
  // 가장 많은 연결을 가진 중심 노드
  String? _centralNode;
  bool _isGraphInitialized = false;
  
  // Most important keywords
  List<String> topKeywords = [];

  // 동시 출현 횟수 저장 (강도 계산용)
  Map<String, Map<String, int>> coOccurrenceCounts = {};

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(KeywordNetworkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults) {
      _buildGraph();
    }
  }

  void _buildGraph() {
    if (widget.analysisResults.isEmpty) {
      setState(() {
        _isGraphInitialized = false;
        topKeywords = [];
      });
      return;
    }

    // 기존 데이터 초기화
    keywordFrequency = {};
    coOccurrences = {};
    keywordScores = {};
    connectionCounts = {};
    _centralNode = null;
    topKeywords = [];
    coOccurrenceCounts = {}; // 동시 출현 횟수 맵 초기화

    // Step 1: 키워드, 점수, 빈도 수집 및 필터링
    for (var result in widget.analysisResults) {
      Set<String> keywordsInVideo = {};
      for (var ks in result.keywords) {
        final keyword = ks.keyword; 
        keywordsInVideo.add(keyword);
        
        // 점수 저장 (나중에 평균 계산)
        keywordScores[keyword] = (keywordScores[keyword] ?? 0.0) + ks.score; 
        keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
      }
    }

    // 빈도가 낮은 키워드 필터링 (메모리 사용량 감소)
    final filteredKeywords = keywordFrequency.entries
        .where((entry) => entry.value >= minKeywordFreq)
        .map((e) => e.key)
        .toList();

    // Step 2: 동시 출현(co-occurrence) 및 가중치(횟수) 추적
    for (var result in widget.analysisResults) {
      Set<String> keywordsInVideo = result.keywords
          .map((ks) => ks.keyword)
          .where((kw) => filteredKeywords.contains(kw))
          .toSet();
      
      List<String> keywordsList = keywordsInVideo.toList();
      for (int i = 0; i < keywordsList.length; i++) {
        for (int j = i + 1; j < keywordsList.length; j++) {
          String kw1 = keywordsList[i];
          String kw2 = keywordsList[j];
          
          // 동시 출현 관계 추가
          coOccurrences.putIfAbsent(kw1, () => {}).add(kw2);
          coOccurrences.putIfAbsent(kw2, () => {}).add(kw1);

          // 동시 출현 횟수 증가
          coOccurrenceCounts.putIfAbsent(kw1, () => {})[kw2] = 
              (coOccurrenceCounts[kw1]![kw2] ?? 0) + 1;
          coOccurrenceCounts.putIfAbsent(kw2, () => {})[kw1] = 
              (coOccurrenceCounts[kw2]![kw1] ?? 0) + 1;
        }
      }
    }

    // Step 3: 각 키워드의 연결 수 계산 (필터링된 키워드만)
    for (var keyword in filteredKeywords) {
      Set<String> connectedKeywords = coOccurrences[keyword] ?? {};
      // 필터링된 키워드에 있는 연결만 카운트
      connectionCounts[keyword] = connectedKeywords.where((k) => filteredKeywords.contains(k)).length;
    }

    // Step 4: 가장 많은 연결을 가진 중심 노드 찾기
    if (connectionCounts.isNotEmpty) {
      _centralNode = connectionCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
          
      // Get top connected keywords (based on connection count)
      var keywordEntries = connectionCounts.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      
      // Limit to MAX_NODES
      topKeywords = keywordEntries
          .take(maxNodes)
          .map((e) => e.key)
          .toList();
    }

    _isGraphInitialized = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGraphInitialized || topKeywords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bubble_chart,
              size: 64,
              color: AppTheme.primaryColor.withAlpha(128),
            ),
            const SizedBox(height: 16),
            const Text(
              "키워드가 부족하거나 연결된 키워드가 없어\n네트워크를 생성할 수 없습니다.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
      );
    }
    
    // Find max connection count for scaling
    final maxConnections = connectionCounts.values.reduce((a, b) => a > b ? a : b).toDouble();

    return Card(
      elevation: 4,
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "키워드 연결망",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "주요 키워드: '${_centralNode ?? '-'}' (${topKeywords.length}개 노드)",
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textColor.withAlpha(204),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InteractiveViewer(
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 2.0,
                    child: Container(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomPaint(
                        painter: KeywordNetworkPainter(
                          keywords: topKeywords,
                          centralNode: _centralNode,
                          connectionCounts: connectionCounts,
                          coOccurrences: coOccurrences,
                          coOccurrenceCounts: coOccurrenceCounts,
                          maxConnections: maxConnections,
                        ),
                        child: Container(), // Empty container for CustomPaint to fill
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KeywordNetworkPainter extends CustomPainter {
  final List<String> keywords;
  final String? centralNode;
  final Map<String, int> connectionCounts;
  final Map<String, Set<String>> coOccurrences;
  final Map<String, Map<String, int>> coOccurrenceCounts;
  final double maxConnections;
  
  // Cache for node positions
  final Map<String, Offset> nodePositions = {};
  
  KeywordNetworkPainter({
    required this.keywords,
    required this.centralNode,
    required this.connectionCounts,
    required this.coOccurrences,
    required this.coOccurrenceCounts,
    required this.maxConnections,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (keywords.isEmpty) return;
    
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width * 0.4 : size.height * 0.4;
    
    // Position central node at center
    if (centralNode != null) {
      nodePositions[centralNode!] = center;
    }
    
    // Calculate positions for other nodes in a spiral pattern
    final otherKeywords = keywords.where((k) => k != centralNode).toList();
    
    // Position nodes in a force-directed-like layout
    _positionNodesInLayout(otherKeywords, center, radius, size);
    
    // Draw edges
    final edgePaint = Paint()
      ..color = Colors.grey.withAlpha(77)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw edges between nodes
    for (var i = 0; i < keywords.length; i++) {
      final keyword1 = keywords[i];
      final pos1 = nodePositions[keyword1];
      if (pos1 == null) continue;
      
      for (var j = i + 1; j < keywords.length; j++) {
        final keyword2 = keywords[j];
        final pos2 = nodePositions[keyword2];
        if (pos2 == null) continue;
        
        // Check if there's a connection between these keywords
        if (coOccurrences[keyword1]?.contains(keyword2) == true) {
          canvas.drawLine(pos1, pos2, edgePaint);
        }
      }
    }
    
    // Draw nodes
    for (var keyword in keywords) {
      final nodePos = nodePositions[keyword];
      if (nodePos == null) continue;
      
      final connections = connectionCounts[keyword] ?? 0;
      final isCentral = keyword == centralNode;
      
      // Calculate node size based on connections
      final nodeRadius = 10.0 + (connections / maxConnections) * 20.0;
      
      // Node color based on connections
      final nodeColor = isCentral 
          ? Colors.red 
          : Color.lerp(
              AppTheme.primaryColor.withAlpha(102),
              AppTheme.primaryColor,
              connections / maxConnections
            ) ?? AppTheme.primaryColor;
      
      // Draw node
      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(nodePos, nodeRadius, nodePaint);
      
      // Draw node border
      final borderPaint = Paint()
        ..color = isCentral ? Colors.white : nodeColor.withAlpha(204)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCentral ? 2.0 : 1.0;
      
      canvas.drawCircle(nodePos, nodeRadius, borderPaint);
      
      // Draw keyword text
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: isCentral ? 14.0 : 12.0,
        fontWeight: isCentral ? FontWeight.bold : FontWeight.normal,
      );
      
      final textSpan = TextSpan(
        text: keyword,
        style: textStyle,
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Position text in center of node
      final textOffset = Offset(
        nodePos.dx - textPainter.width / 2,
        nodePos.dy - textPainter.height / 2,
      );
      
      textPainter.paint(canvas, textOffset);
    }
  }
  
  void _positionNodesInLayout(List<String> otherKeywords, Offset center, double radius, Size size) {
    // Use a simple physics-based layout for positioning
    final random = Random(42); // Fixed seed for reproducibility
    
    // Initial random positions for non-central nodes
    for (var keyword in otherKeywords) {
      // Random angle
      final angle = random.nextDouble() * 2 * pi;
      // Random distance from center (within radius)
      final distance = random.nextDouble() * radius;
      
      // Convert polar to Cartesian coordinates
      final x = center.dx + distance * cos(angle);
      final y = center.dy + distance * sin(angle);
      
      nodePositions[keyword] = Offset(x, y);
    }
    
    // Simple force-directed algorithm
    const iterations = 50; // Number of iterations for force simulation
    const double repulsionConstant = 30.0; // 반발력 상수
    const double attractionBaseConstant = 0.01; // 기본 인력 상수 (조정 필요)
    const double attractionDistanceFactor = 10.0; // 거리에 따른 인력 약화/강화 계수 (조정 필요)

    for (var i = 0; i < iterations; i++) {
      final forces = <String, Offset>{};
      for (var keyword in keywords) { forces[keyword] = Offset.zero; }

      // Repulsive forces
      for (var j = 0; j < keywords.length; j++) {
        final keyword1 = keywords[j];
        final pos1 = nodePositions[keyword1];
        if (pos1 == null) continue;
        
        for (var k = j + 1; k < keywords.length; k++) {
          final keyword2 = keywords[k];
          final pos2 = nodePositions[keyword2];
          if (pos2 == null) continue;
          
          final delta = pos2 - pos1;
          final distance = delta.distance;
          
          if (distance < 0.1) continue; // Avoid division by zero
          
          // Repulsive force (inverse square law)
          final repulsiveForce = delta / distance * (repulsionConstant / distance);
          
          forces[keyword1] = (forces[keyword1] ?? Offset.zero) - repulsiveForce;
          forces[keyword2] = (forces[keyword2] ?? Offset.zero) + repulsiveForce;
        }
      }
      
      // Attractive forces (modified based on coOccurrenceCounts)
      for (var j = 0; j < keywords.length; j++) {
        final keyword1 = keywords[j];
        final pos1 = nodePositions[keyword1];
        if (pos1 == null) continue;
        
        for (var k = j + 1; k < keywords.length; k++) {
          final keyword2 = keywords[k];
          final pos2 = nodePositions[keyword2];
          if (pos2 == null) continue;
          
          if (coOccurrences[keyword1]?.contains(keyword2) == true) {
            final delta = pos2 - pos1;
            final distance = delta.distance;
            if (distance < 0.1) continue; 

            // 동시 출현 횟수 가져오기 (기본값 1)
            final count = coOccurrenceCounts[keyword1]?[keyword2] ?? 1;
            
            // 인력 계산: 거리가 멀수록 강해지고, 횟수(count)가 클수록 약해짐
            // (거리에 비례, 횟수에 반비례. 상수를 조절하여 효과 조절)
            final attractionMagnitude = attractionBaseConstant * (distance / attractionDistanceFactor) / count;
            final attractiveForce = delta / distance * attractionMagnitude;
            
            forces[keyword1] = (forces[keyword1] ?? Offset.zero) + attractiveForce;
            forces[keyword2] = (forces[keyword2] ?? Offset.zero) - attractiveForce;
          }
        }
      }
      
      // Update positions based on forces
      for (var keyword in keywords) {
        if (keyword == centralNode) continue; // Keep central node fixed
        
        final pos = nodePositions[keyword];
        final force = forces[keyword];
        if (pos == null || force == null) continue;
        
        // Apply force with damping
        final damping = 1.0 - (i / iterations); // Reduce movement over iterations
        var newPos = pos + force * damping;
        
        // Keep nodes within bounds
        newPos = Offset(
          newPos.dx.clamp(20.0, size.width - 20.0),
          newPos.dy.clamp(20.0, size.height - 20.0),
        );
        
        nodePositions[keyword] = newPos;
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 