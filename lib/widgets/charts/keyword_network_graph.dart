import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import '../../models/video_analysis_result.dart';

import '../../widgets/app_theme.dart';

// Helper class for BFS
class Pair<T1, T2> {
  final T1 first;
  final T2 second;
  Pair(this.first, this.second);
}

class KeywordNetworkGraph extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;

  const KeywordNetworkGraph({super.key, required this.analysisResults});

  @override
  State<KeywordNetworkGraph> createState() => _KeywordNetworkGraphState();
}

class _KeywordNetworkGraphState extends State<KeywordNetworkGraph> {
  // Configuration
  static const int maxNodes = 30;
  static const int minKeywordFreq = 2;

  // Graph data
  Map<String, int> keywordFrequency = {};
  Map<String, Set<String>> coOccurrences = {};
  Map<String, double> keywordScores = {};
  Map<String, int> connectionCounts = {};
  Map<String, Map<String, int>> coOccurrenceCounts = {};
  String? _centralNode;
  List<String> topKeywords = [];
  Map<String, int> nodeDistances = {}; // Distance from central node

  // State for interaction and layout
  bool _isGraphInitialized = false;
  final TransformationController _transformationController = TransformationController();
  Map<String, Offset> nodePositions = {}; // Node positions managed by state
  String? _draggedKeyword;
  Offset _dragOffset = Offset.zero;
  bool _isDraggingNode = false;
  double _lastCalculatedMaxConnections = 1.0; // Cache max connections

  @override
  void initState() {
    super.initState();
    _buildGraph();
  }

  @override
  void didUpdateWidget(KeywordNetworkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults) {
      // Clear positions and rebuild graph when data changes
      nodePositions.clear();
      _buildGraph();
    }
  }

  // Calculates node radius based on connections (consistent with painter)
  double _calculateNodeRadius(String keyword) {
    final connections = connectionCounts[keyword] ?? 0;
    final maxConn = _lastCalculatedMaxConnections > 0 ? _lastCalculatedMaxConnections : 1.0;
    // Adjusted scaling for better visibility
    return 8.0 + (connections / maxConn) * 15.0;
  }

  // Calculates distances (hops) from the central node using BFS
  void _calculateNodeDistances() {
    nodeDistances.clear();
    if (_centralNode == null || !topKeywords.contains(_centralNode!)) return;

    Queue<Pair<String, int>> queue = Queue();
    Set<String> visited = {};

    nodeDistances[_centralNode!] = 0;
    queue.add(Pair(_centralNode!, 0));
    visited.add(_centralNode!);

    while (queue.isNotEmpty) {
      Pair<String, int> current = queue.removeFirst();
      String currentKeyword = current.first;
      int currentDistance = current.second;

      // Consider only neighbors present in topKeywords
      final neighbors = (coOccurrences[currentKeyword] ?? {})
          .where((neighbor) => topKeywords.contains(neighbor));

      for (String neighbor in neighbors) {
        if (!visited.contains(neighbor)) {
          visited.add(neighbor);
          nodeDistances[neighbor] = currentDistance + 1;
          queue.add(Pair(neighbor, currentDistance + 1));
        }
      }
    }
    // Assign default distance to unreached nodes
    for (var keyword in topKeywords) {
      nodeDistances.putIfAbsent(keyword, () => -1);
    }
  }

  // Build the graph data structure
  void _buildGraph() {
    // Reset graph data
    keywordFrequency = {};
    coOccurrences = {};
    keywordScores = {};
    connectionCounts = {};
    _centralNode = null;
    topKeywords = [];
    coOccurrenceCounts = {};
    nodeDistances = {}; // Reset distances

    if (widget.analysisResults.isEmpty) {
      setState(() => _isGraphInitialized = false);
      return;
    }

    // Step 1: Collect keywords, scores, frequencies
    for (var result in widget.analysisResults) {
      Set<String> keywordsInVideo = {};
      for (var ks in result.keywords) {
        final keyword = ks.keyword;
        keywordsInVideo.add(keyword);
        keywordScores[keyword] = (keywordScores[keyword] ?? 0.0) + ks.score;
        keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
      }
    }

    // Filter infrequent keywords
    final filteredKeywords = keywordFrequency.entries
        .where((entry) => entry.value >= minKeywordFreq)
        .map((e) => e.key)
        .toSet(); // Use Set for faster lookups

    // Step 2: Track co-occurrences and counts (only for filtered keywords)
     for (var result in widget.analysisResults) {
       // Filter keywords in this video based on the frequency filter
       List<String> keywordsList = result.keywords
           .map((ks) => ks.keyword)
           .where((kw) => filteredKeywords.contains(kw))
           .toList(); // Convert to list for indexing

       for (int i = 0; i < keywordsList.length; i++) {
         for (int j = i + 1; j < keywordsList.length; j++) {
           String kw1 = keywordsList[i];
           String kw2 = keywordsList[j];

           // Add co-occurrence relationship
           coOccurrences.putIfAbsent(kw1, () => {}).add(kw2);
           coOccurrences.putIfAbsent(kw2, () => {}).add(kw1);

           // Increment co-occurrence count
            coOccurrenceCounts.putIfAbsent(kw1, () => {})[kw2] =
               (coOccurrenceCounts.putIfAbsent(kw1, () => {})[kw2] ?? 0) + 1;
            coOccurrenceCounts.putIfAbsent(kw2, () => {})[kw1] =
               (coOccurrenceCounts.putIfAbsent(kw2, () => {})[kw1] ?? 0) + 1;
         }
       }
     }

    // Step 3: Calculate connection counts (only among filtered keywords)
    for (var keyword in filteredKeywords) {
      Set<String> connected = coOccurrences[keyword] ?? {};
      // Count connections only to other *filtered* keywords
      connectionCounts[keyword] = connected.where((k) => filteredKeywords.contains(k)).length;
    }

    // Step 4: Find central node and top keywords
    final validKeywords = connectionCounts.entries
        .where((e) => e.value > 0) // Consider only nodes with connections
        .map((e) => e.key)
        .toList();

    if (validKeywords.isNotEmpty) {
        // Find central node among valid keywords
         _centralNode = connectionCounts.entries
             .where((entry) => validKeywords.contains(entry.key)) // Ensure central node is valid
             .reduce((a, b) => a.value > b.value ? a : b)
             .key;

        // Sort valid keywords by connection count
        var keywordEntries = connectionCounts.entries
            .where((entry) => validKeywords.contains(entry.key)) // Filter again for sorting
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Limit to maxNodes
        topKeywords = keywordEntries
            .take(maxNodes)
            .map((e) => e.key)
            .toList();

        // Cache max connections
         _lastCalculatedMaxConnections = connectionCounts.values.isNotEmpty
            ? connectionCounts.values.reduce(max).toDouble()
            : 1.0;

        // Calculate distances from the central node
        _calculateNodeDistances();
    } else {
        // Handle case with no valid connections
        _centralNode = null;
        topKeywords = [];
        _lastCalculatedMaxConnections = 1.0;
    }


    _isGraphInitialized = true;
    // Trigger rebuild only if mounted
    if (mounted) setState(() {});
  }

  // --- Drag and Drop Handlers ---
  void _onPanStart(DragStartDetails details) {
    final Offset localPosition = _transformationController.toScene(details.localPosition);
    _isDraggingNode = false; // Reset flag

    // Check if drag started on a node (check from top)
    for (var keyword in topKeywords.reversed) {
      final nodePos = nodePositions[keyword];
      if (nodePos != null) {
        final nodeRadius = _calculateNodeRadius(keyword);
        // Add buffer for easier grabbing
        if ((localPosition - nodePos).distance <= nodeRadius + 15.0) { // Increased buffer slightly
          setState(() {
            _draggedKeyword = keyword;
            // Calculate offset relative to the node's center
            _dragOffset = nodePos - localPosition;
            _isDraggingNode = true; // Set flag
          });
          return; // Stop after finding the first node
        }
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_draggedKeyword != null && nodePositions.containsKey(_draggedKeyword)) {
       final Offset localPosition = _transformationController.toScene(details.localPosition);
       setState(() {
         // Update position using the calculated offset
         nodePositions[_draggedKeyword!] = localPosition + _dragOffset;
       });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_draggedKeyword != null) {
      setState(() {
        _draggedKeyword = null;
        _isDraggingNode = false; // Reset flag
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGraphInitialized || topKeywords.isEmpty) {
      // Display message when no graph can be built
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bubble_chart_outlined, // Changed icon
              size: 64,
              color: AppTheme.textColor.withAlpha(100), // Adjusted color
            ),
            const SizedBox(height: 16),
            const Text(
              "표시할 키워드 네트워크가 없습니다.\n(연결된 키워드 부족)", // Fixed Korean string literal
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppTheme.textColor),
            ),
          ],
        ),
      );
    }

    // Use cached max connections
    final maxConnections = _lastCalculatedMaxConnections;

    return Card(
      elevation: 2, // Reduced elevation
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "키워드 연결망",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _centralNode != null
                ? "중심 키워드: '$_centralNode' (${topKeywords.length} 노드)"
                : "네트워크 (${topKeywords.length} 노드)", // Handle no central node case
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textColor.withAlpha(204),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Wrap with GestureDetector for drag handling
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent, // Ensure hit testing works
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity), // Allow panning beyond content
                      minScale: 0.1,
                      maxScale: 4.0,
                      // Disable InteractiveViewer's pan/scale when dragging a node
                      panEnabled: !_isDraggingNode,
                      scaleEnabled: !_isDraggingNode,
                      // Ensure the container is large enough for drawing and panning
                      child: Container(
                         // Use constraints to define initial canvas size, but allow larger drawing area
                        width: max(constraints.maxWidth, 600), // Ensure minimum width
                        height: max(constraints.maxHeight, 600), // Ensure minimum height
                        decoration: BoxDecoration(
                          // Optional: Add subtle background pattern or color
                          color: AppTheme.backgroundColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          // border: Border.all(color: AppTheme.textColor.withOpacity(0.1))
                        ),
                        child: CustomPaint(
                          // Ensure painter uses the state's node positions
                          painter: KeywordNetworkPainter(
                            keywords: topKeywords,
                            centralNode: _centralNode,
                            connectionCounts: connectionCounts,
                            coOccurrences: coOccurrences,
                            coOccurrenceCounts: coOccurrenceCounts,
                            maxConnections: maxConnections,
                            nodePositions: nodePositions, // Pass state positions
                            nodeDistances: nodeDistances, // Pass calculated distances
                          ),
                           // Size is determined by parent Container
                          size: Size(
                            max(constraints.maxWidth, 600),
                            max(constraints.maxHeight, 600)
                          ),
                          // child: Container(), // No need for a child here
                        ),
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


// --- KeywordNetworkPainter ---
class KeywordNetworkPainter extends CustomPainter {
  final List<String> keywords;
  final String? centralNode;
  final Map<String, int> connectionCounts;
  final Map<String, Set<String>> coOccurrences;
  final Map<String, Map<String, int>> coOccurrenceCounts;
  final double maxConnections;
  final Map<String, Offset> nodePositions; // Received from state
  final Map<String, int> nodeDistances;   // Received from state

  KeywordNetworkPainter({
    required this.keywords,
    required this.centralNode,
    required this.connectionCounts,
    required this.coOccurrences,
    required this.coOccurrenceCounts,
    required this.maxConnections,
    required this.nodePositions,
    required this.nodeDistances,
  });

  // Consistent node radius calculation
  double _calculateNodeRadius(String keyword) {
    final connections = connectionCounts[keyword] ?? 0;
    final maxConn = maxConnections > 0 ? maxConnections : 1.0;
    return 8.0 + (connections / maxConn) * 15.0;
  }

  // Node color based on distance from central node
  Color _getColorForDistance(String keyword) {
    final distance = nodeDistances[keyword] ?? -1;
    final connections = connectionCounts[keyword] ?? 0;
    // Normalize connections for color interpolation (0.0 to 1.0)
    final double normalizedConnections = maxConnections > 0 ? (connections / maxConnections).clamp(0.0, 1.0) : 0.0;

    if (keyword == centralNode) {
      return Colors.redAccent.shade400; // Brighter red for central node
    }

    switch (distance) {
      case 0: // Should be central node, but as fallback
        return Colors.redAccent.shade400;
      case 1: // 1 hop: Green spectrum
        return Color.lerp(Colors.lightGreen.shade300, Colors.green.shade700, normalizedConnections) ?? Colors.green;
      case 2: // 2 hops: Blue spectrum
        return Color.lerp(Colors.lightBlue.shade300, Colors.blue.shade700, normalizedConnections) ?? Colors.blue;
      case 3: // 3 hops: Purple spectrum
         return Color.lerp(Colors.purple.shade200, Colors.purple.shade600, normalizedConnections) ?? Colors.purple;
      default: // 4+ hops or disconnected: Orange/Yellow spectrum
        return Color.lerp(Colors.amber.shade300, Colors.deepOrange.shade400, normalizedConnections) ?? Colors.orange;
    }
  }

   @override
  void paint(Canvas canvas, Size size) {
    if (keywords.isEmpty) return;

    // Initialize positions if they are missing (first paint or data change)
    if (nodePositions.length != keywords.length) {
      _initializeNodePositions(keywords, size);
    }

    // --- Draw Edges ---
    final edgePaint = Paint()
      ..color = AppTheme.textColor.withOpacity(0.2) // Subtler edge color
      ..strokeWidth = 0.8 // Thinner edges
      ..style = PaintingStyle.stroke;

    final drawnEdges = <String>{}; // Prevent drawing duplicate edges

    for (var keyword1 in keywords) {
      final pos1 = nodePositions[keyword1];
      if (pos1 == null) continue;

      final neighbors = coOccurrences[keyword1] ?? {};
      for (var keyword2 in neighbors) {
        // Only draw edge if neighbor is also in topKeywords and position exists
        if (keywords.contains(keyword2)) {
            final pos2 = nodePositions[keyword2];
            if (pos2 == null) continue;

            // Create unique key for the edge pair to avoid duplicates
            final edgeKey = [keyword1, keyword2]..sort();
            final edgeId = edgeKey.join('-');

            if (!drawnEdges.contains(edgeId)) {
              // Optional: Adjust stroke width based on co-occurrence count
              // final count = coOccurrenceCounts[keyword1]?[keyword2] ?? 1;
              // edgePaint.strokeWidth = (0.5 + (count / 10.0) * 1.5).clamp(0.5, 2.0);
              canvas.drawLine(pos1, pos2, edgePaint);
              drawnEdges.add(edgeId);
            }
        }
      }
    }


    // --- Draw Nodes ---
    // Draw non-central nodes first, then central node on top
    final nonCentralKeywords = keywords.where((k) => k != centralNode).toList();
    final centralKeywordList = (centralNode != null && keywords.contains(centralNode!)) ? [centralNode!] : <String>[];

    for (var keyword in nonCentralKeywords.followedBy(centralKeywordList)) {
      final nodePos = nodePositions[keyword];
      if (nodePos == null) continue; // Skip if position somehow doesn't exist

      final isCentral = keyword == centralNode;
      final nodeRadius = _calculateNodeRadius(keyword);
      final nodeColor = _getColorForDistance(keyword);

      // Node Fill
      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      // Optional: Add slight shadow to nodes
       canvas.drawCircle(nodePos.translate(1, 1), nodeRadius, Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawCircle(nodePos, nodeRadius, nodePaint);


      // Node Border
      final borderPaint = Paint()
        ..color = isCentral ? Colors.white.withOpacity(0.9) : nodeColor.withOpacity(0.8).withAlpha(150) // Adjusted border
        ..style = PaintingStyle.stroke
        ..strokeWidth = isCentral ? 1.5 : 1.0;
      canvas.drawCircle(nodePos, nodeRadius, borderPaint);

      // Keyword Text
       // Adjust font size based on node radius for better fit
      final baseFontSize = isCentral ? 10.0 : 9.0;
      final fontSize = (baseFontSize * (nodeRadius / 15.0)).clamp(6.0, baseFontSize + 2); // Clamp font size

      final textStyle = TextStyle(
        fontSize: fontSize,
        fontWeight: isCentral ? FontWeight.bold : FontWeight.normal,
        color: Colors.white.withOpacity(0.95), // Brighter text
        shadows: [ // Subtle shadow for readability
          Shadow(
            offset: Offset(1.0, 1.0),
            blurRadius: 1.5,
            color: Colors.black.withOpacity(0.6),
          ),
        ],
      );

      final textSpan = TextSpan(text: keyword, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      textPainter.layout(maxWidth: nodeRadius * 1.8); // Ensure text fits roughly within node

      // Center text inside the node
      final textOffset = Offset(
        nodePos.dx - textPainter.width / 2,
        nodePos.dy - textPainter.height / 2,
      );

      // Clip text drawing to the node circle (optional, can be complex)
      // canvas.save();
      // canvas.clipPath(Path()..addOval(Rect.fromCircle(center: nodePos, radius: nodeRadius)));
      textPainter.paint(canvas, textOffset);
      // canvas.restore();
    }
  }

   // Initializes node positions if missing (randomly + force simulation)
   void _initializeNodePositions(List<String> keywordsToPosition, Size size) {
     final random = Random(42); // Consistent randomness
     final center = Offset(size.width / 2, size.height / 2);
     // Use the smaller dimension for radius calculation, adjust multiplier
     final radius = min(size.width, size.height) * 0.35;

     // Position central node first if it exists and needs positioning
     if (centralNode != null &&
         keywordsToPosition.contains(centralNode!) &&
         nodePositions[centralNode!] == null) {
       nodePositions[centralNode!] = center;
     }

     // Position remaining nodes randomly if they don't have a position
     final nodesToPlace = keywordsToPosition
         .where((k) => nodePositions[k] == null)
         .toList();

     for (var keyword in nodesToPlace) {
       // Spread nodes out more initially
       final angle = random.nextDouble() * 2 * pi;
       final distance = radius * (0.5 + random.nextDouble() * 0.7); // Wider initial spread
       final x = center.dx + distance * cos(angle);
       final y = center.dy + distance * sin(angle);
       // Clamp positions within the canvas bounds initially
       nodePositions[keyword] = Offset(
           x.clamp(30.0, size.width - 30.0),
           y.clamp(30.0, size.height - 30.0)
       );
     }

     // Run force simulation to stabilize initial layout
     _runForceSimulation(keywordsToPosition, size);
   }


   // Runs a simple force-directed layout simulation
   void _runForceSimulation(List<String> keywordsToSimulate, Size size) {
     const iterations = 100; // More iterations for potentially better layout
     // Adjusted force constants
     const double repulsionConstant = 50.0;    // Increased repulsion
     const double attractionBaseConstant = 0.01; // Fine-tuned attraction
     const double centerAttraction = 0.005;   // Gentle pull towards center

     final center = Offset(size.width / 2, size.height / 2);

     for (var i = 0; i < iterations; i++) {
       final forces = <String, Offset>{
         for (var keyword in keywordsToSimulate) keyword: Offset.zero
       };

       // --- Calculate Repulsive Forces ---
        for (var j = 0; j < keywordsToSimulate.length; j++) {
          final keyword1 = keywordsToSimulate[j];
          final pos1 = nodePositions[keyword1];
          if (pos1 == null) continue;

          for (var k = j + 1; k < keywordsToSimulate.length; k++) {
            final keyword2 = keywordsToSimulate[k];
            final pos2 = nodePositions[keyword2];
            if (pos2 == null) continue;

            final delta = pos2 - pos1;
            final distance = delta.distance;

            if (distance < 1.0) continue; // Avoid extreme forces at close distance

            // Repulsion force (stronger when closer)
            final repulsiveForceMagnitude = repulsionConstant / (distance * distance); // Inverse square
            final repulsiveForce = (delta / distance) * repulsiveForceMagnitude;

            forces[keyword1] = forces[keyword1]! - repulsiveForce;
            forces[keyword2] = forces[keyword2]! + repulsiveForce;
          }
        }

       // --- Calculate Attractive Forces (based on co-occurrence) ---
        for (var j = 0; j < keywordsToSimulate.length; j++) {
          final keyword1 = keywordsToSimulate[j];
          final pos1 = nodePositions[keyword1];
          if (pos1 == null) continue;

          // Iterate through neighbors defined by coOccurrences
           final neighbors = coOccurrences[keyword1] ?? {};
           for (var keyword2 in neighbors) {
             // Only apply attraction if neighbor is also in the simulation list and has position
             if (!keywordsToSimulate.contains(keyword2) || nodePositions[keyword2] == null) continue;

             // Avoid duplicate calculations (only process j < k equivalent)
              if (keywordsToSimulate.indexOf(keyword1) >= keywordsToSimulate.indexOf(keyword2)) continue;


             final pos2 = nodePositions[keyword2]!;
             final delta = pos2 - pos1;
             final distance = delta.distance;

             if (distance < 1.0) continue;

             final count = coOccurrenceCounts[keyword1]?[keyword2] ?? 1;
             // Attraction force (stronger for closer nodes, slightly influenced by count)
             final attractionMagnitude = attractionBaseConstant * distance * (1 + count * 0.1); // Linear attraction + count boost
             final attractiveForce = (delta / distance) * attractionMagnitude;

             forces[keyword1] = forces[keyword1]! + attractiveForce;
             forces[keyword2] = forces[keyword2]! - attractiveForce;
           }
        }


       // --- Apply Force towards Center ---
       for (var keyword in keywordsToSimulate) {
         if (keyword == centralNode) continue; // Don't pull the central node
         final pos = nodePositions[keyword];
         if (pos == null) continue;
         final deltaToCenter = center - pos;
         forces[keyword] = forces[keyword]! + deltaToCenter * centerAttraction;
       }

       // --- Update Positions ---
       for (var keyword in keywordsToSimulate) {
          // Central node position is fixed during simulation
         if (keyword == centralNode) continue;

         final pos = nodePositions[keyword];
         final force = forces[keyword];
         if (pos == null || force == null) continue;

         // Apply force with damping (reduces over iterations)
         final damping = 0.5 * (1.0 - (i / iterations)); // Adjusted damping
         var newPos = pos + force * damping;

         // Keep nodes within bounds (add padding)
         double padding = 30.0;
         newPos = Offset(
           newPos.dx.clamp(padding, size.width - padding),
           newPos.dy.clamp(padding, size.height - padding),
         );

         nodePositions[keyword] = newPos;
       }
     }
   }

  @override
  bool shouldRepaint(covariant KeywordNetworkPainter oldDelegate) {
    // Repaint only if necessary data changes
    return oldDelegate.nodePositions != nodePositions ||
           oldDelegate.nodeDistances != nodeDistances ||
           !listEquals(oldDelegate.keywords, keywords) || // Use listEquals for list comparison
           oldDelegate.maxConnections != maxConnections ||
           oldDelegate.centralNode != centralNode;
  }
}

// Helper function for list comparison in shouldRepaint
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
} 