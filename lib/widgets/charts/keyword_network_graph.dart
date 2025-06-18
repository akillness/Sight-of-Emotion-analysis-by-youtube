import 'dart:math';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'; // Import for DragStartBehavior
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

class _KeywordNetworkGraphState extends State<KeywordNetworkGraph>
    with TickerProviderStateMixin {
  // Configuration
  static const int maxNodes = 30;
  static const int minKeywordFreq = 2;

  // Graph data
  Map<String, int> keywordFrequency = {};
  Map<String, Set<String>> coOccurrences = {};
  Map<String, double> keywordScores = {};
  Map<String, int> connectionCounts = {};
  Map<String, Map<String, int>> coOccurrenceCounts = {};
  Map<String, String> keywordEmotions = {}; // New: emotion mapping for keywords
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
  bool _needsPositionInitialization = true; // Flag to initialize positions
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  String? _hoveredKeyword;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
    
    _buildGraph();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(KeywordNetworkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults) {
      // Clear positions and rebuild graph when data changes
      nodePositions.clear();
      _buildGraph();
      _needsPositionInitialization = true; // Mark for re-initialization
    }
  }

  // Calculates node radius based on connections (consistent with painter)
  double _calculateNodeRadius(String keyword) {
    final connections = connectionCounts[keyword] ?? 0;
    final maxConn = _lastCalculatedMaxConnections > 0 ? _lastCalculatedMaxConnections : 1.0;
    // Adjusted scaling for better visibility
    return 8.0 + (connections / maxConn) * 15.0;
  }

  // Get emotion-based color for keyword
  Color _getKeywordColor(String keyword, {double opacity = 1.0}) {
    final emotion = keywordEmotions[keyword] ?? 'neutral';
    final intensity = (keywordScores[keyword] ?? 0.0) / 100.0; // Normalize score
    return AppTheme.getEmotionColor(emotion, intensity.clamp(0.0, 1.0)).withOpacity(opacity);
  }

  // Calculates distances (hops) from the central node using BFS
  void _calculateNodeDistances() {
    nodeDistances.clear();
    if (_centralNode == null || !topKeywords.contains(_centralNode!)) return;

    Queue<Pair<String, int>> queue = Queue();
    Set<String> visited = {};

    nodeDistances[_centralNode!] = 0;
    queue.add(Pair(_centralNode!, 0));
    visited.add(_centralNode!); // Mark central node as visited immediately

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
    // Assign default distance to unreached nodes (including those filtered out)
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
    keywordEmotions = {}; // Reset emotion mapping
    _centralNode = null;
    topKeywords = [];
    coOccurrenceCounts = {};
    nodeDistances = {}; // Reset distances

    if (widget.analysisResults.isEmpty) {
      setState(() => _isGraphInitialized = false);
      return;
    }

    // Step 1: Collect keywords, scores, frequencies, and emotions
    for (var result in widget.analysisResults) {
      final videoEmotion = result.overallEmotion;
      
      // Use a Set to track unique keywords within this video efficiently
      Set<String> keywordsInVideo = {};
      for (var ks in result.keywords) {
        final keyword = ks.keyword;
        keywordsInVideo.add(keyword);
        keywordScores[keyword] = (keywordScores[keyword] ?? 0.0) + ks.score;
        keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
        
        // Map keyword to the video's overall emotion (could be enhanced with keyword-specific emotion analysis)
        keywordEmotions[keyword] = videoEmotion;
      }
    }

    // Filter infrequent keywords BEFORE calculating co-occurrences
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
    // Consider only filtered keywords that have at least one connection to another filtered keyword
    final validKeywords = connectionCounts.entries
        .where((e) => filteredKeywords.contains(e.key) && e.value > 0)
        .map((e) => e.key)
        .toList();

    if (validKeywords.isNotEmpty) {
        // Find central node among valid keywords based on highest connection count
         _centralNode = connectionCounts.entries
             .where((entry) => validKeywords.contains(entry.key)) // Ensure central node is valid
             .reduce((a, b) => a.value > b.value ? a : b)
             .key;

        // Sort valid keywords by connection count (descending)
        var keywordEntries = connectionCounts.entries
            .where((entry) => validKeywords.contains(entry.key)) // Filter again for sorting
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Limit to maxNodes
        topKeywords = keywordEntries
            .take(maxNodes)
            .map((e) => e.key)
            .toList();

        // Update max connections for consistency
        _lastCalculatedMaxConnections = keywordEntries.isNotEmpty 
            ? keywordEntries.first.value.toDouble() 
            : 1.0;

        // Calculate distances from central node
        _calculateNodeDistances();

        setState(() => _isGraphInitialized = true);
    } else {
        setState(() => _isGraphInitialized = false);
    }
  }

  void _onKeywordHover(String? keyword) {
    setState(() {
      _hoveredKeyword = keyword;
    });
    
    if (keyword != null) {
      // Haptic feedback
      HapticFeedback.selectionClick();
      
      // Trigger pulse animation
      _pulseController.reset();
      _pulseController.forward();
    }
  }

  void _onKeywordTap(String keyword) {
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    // Trigger ripple animation
    _rippleController.reset();
    _rippleController.forward();
    
    // You could add more interaction logic here
    // For example, filtering by keyword, showing details, etc.
  }

  // --- Pointer Event Handlers using Listener ---
  void _handlePointerDown(PointerDownEvent event) {
    // Only handle mouse clicks or touch taps for dragging nodes
    if (event.kind != PointerDeviceKind.mouse && event.kind != PointerDeviceKind.touch) return;

    final Offset localPosition = _transformationController.toScene(event.localPosition);
    _isDraggingNode = false; // Reset flag initially

    // Check if drag started on a node (check from top keywords)
    for (var keyword in topKeywords.reversed) {
      final nodePos = nodePositions[keyword];
      if (nodePos != null) {
        final nodeRadius = _calculateNodeRadius(keyword);
        final distance = (localPosition - nodePos).distance;
        // Add buffer for easier grabbing
        if (distance <= nodeRadius + 15.0) { // Use buffer
          setState(() {
            _draggedKeyword = keyword;
            _dragOffset = nodePos - localPosition;
            _isDraggingNode = true; // Set flag: We are dragging a node
          });
          // Consider capturing the pointer ID if needed for multi-touch, but likely okay for web mouse/trackpad
          return; // Stop after finding the first node
        }
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Only handle mouse or touch movements for dragging
    if (event.kind != PointerDeviceKind.mouse && event.kind != PointerDeviceKind.touch) return;

    if (_isDraggingNode && _draggedKeyword != null && nodePositions.containsKey(_draggedKeyword)) {
      final Offset localPosition = _transformationController.toScene(event.localPosition);
      final newPosition = localPosition + _dragOffset;
      setState(() {
        // Update position using the calculated offset
        nodePositions[_draggedKeyword!] = newPosition;
      });
    }
  }

  void _handlePointerUpOrCancel(PointerEvent event) { // Handles both Up and Cancel
    // Only handle mouse or touch release/cancel
    if (event.kind != PointerDeviceKind.mouse && event.kind != PointerDeviceKind.touch) return;

    if (_isDraggingNode) {
      setState(() {
        _draggedKeyword = null;
        _isDraggingNode = false; // Reset flag
      });
    }
  }

  // Initializes node positions if missing (randomly + force simulation)
  void _initializeNodePositions(Size size) {
    if (topKeywords.isEmpty) return;
    final random = Random(42); // Consistent randomness
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;

    // Position central node first if it exists and needs positioning
    if (_centralNode != null && nodePositions[_centralNode!] == null) {
      nodePositions[_centralNode!] = center;
    }

    // Position remaining nodes randomly only if they don\'t have a position yet
    final nodesToPlace = topKeywords.where((k) => nodePositions[k] == null).toList();

    for (var keyword in nodesToPlace) {
      // Avoid placing central node randomly if it was already placed
      if (keyword == _centralNode) continue;

      final angle = random.nextDouble() * 2 * pi;
      final distance = radius * (0.5 + random.nextDouble() * 0.7);
      final x = center.dx + distance * cos(angle);
      final y = center.dy + distance * sin(angle);
      nodePositions[keyword] = Offset(
        x.clamp(30.0, size.width - 30.0),
        y.clamp(30.0, size.height - 30.0),
      );
    }
  }

  // Runs a simple force-directed layout simulation
  void _runForceSimulation(Size size) {
     if (topKeywords.isEmpty) return;
     const iterations = 100;
     const double repulsionConstant = 50.0;
     const double attractionBaseConstant = 0.01;
     const double centerAttraction = 0.005;
     final center = Offset(size.width / 2, size.height / 2);

     // Only simulate nodes that are in topKeywords and have positions
     final keywordsToSimulate = topKeywords.where((kw) => nodePositions.containsKey(kw)).toList();

     for (var i = 0; i < iterations; i++) {
       final forces = <String, Offset>{ for (var keyword in keywordsToSimulate) keyword: Offset.zero };

       // Calculate Repulsive Forces
       for (var j = 0; j < keywordsToSimulate.length; j++) {
         final keyword1 = keywordsToSimulate[j];
         final pos1 = nodePositions[keyword1]!;
         for (var k = j + 1; k < keywordsToSimulate.length; k++) {
           final keyword2 = keywordsToSimulate[k];
           final pos2 = nodePositions[keyword2]!;
           final delta = pos2 - pos1;
           final distance = delta.distance;
           if (distance < 1.0) continue;
           final repulsiveForceMagnitude = repulsionConstant / (distance * distance);
           final repulsiveForce = (delta / distance) * repulsiveForceMagnitude;
           forces[keyword1] = forces[keyword1]! - repulsiveForce;
           forces[keyword2] = forces[keyword2]! + repulsiveForce;
         }
       }

       // Calculate Attractive Forces
       for (var j = 0; j < keywordsToSimulate.length; j++) {
         final keyword1 = keywordsToSimulate[j];
         final pos1 = nodePositions[keyword1]!;
         final neighbors = coOccurrences[keyword1] ?? {};
         for (var keyword2 in neighbors) {
           if (!keywordsToSimulate.contains(keyword2)) continue;
           if (keywordsToSimulate.indexOf(keyword1) >= keywordsToSimulate.indexOf(keyword2)) continue;
           final pos2 = nodePositions[keyword2]!;
           final delta = pos2 - pos1;
           final distance = delta.distance;
           if (distance < 1.0) continue;
           final count = coOccurrenceCounts[keyword1]?[keyword2] ?? 1;
           final attractionMagnitude = attractionBaseConstant * distance * (1 + count * 0.1);
           final attractiveForce = (delta / distance) * attractionMagnitude;
           forces[keyword1] = forces[keyword1]! + attractiveForce;
           forces[keyword2] = forces[keyword2]! - attractiveForce;
         }
       }

       // Apply Force towards Center
       for (var keyword in keywordsToSimulate) {
         if (keyword == _centralNode) continue;
         final pos = nodePositions[keyword]!;
         final deltaToCenter = center - pos;
         forces[keyword] = forces[keyword]! + deltaToCenter * centerAttraction;
       }

       // Update Positions
       for (var keyword in keywordsToSimulate) {
         if (keyword == _centralNode) continue;
         final pos = nodePositions[keyword]!;
         final force = forces[keyword]!;
         final damping = 0.5 * (1.0 - (i / iterations));
         var newPos = pos + force * damping;
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
                  final Size size = constraints.biggest; // Get available size

                  // Initialize positions after the first layout if needed
                  if (_needsPositionInitialization && size.isFinite && size.width > 0 && size.height > 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _needsPositionInitialization) { // Double check state
                        _initializeNodePositions(size);
                        _runForceSimulation(size);
                        if (mounted) { // Check mounted again before setState
                           setState(() {
                            _needsPositionInitialization = false;
                           });
                        }
                      }
                    });
                  }

                  // Wrap with Listener for direct pointer handling
                  return Listener(
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUpOrCancel,
                    onPointerCancel: _handlePointerUpOrCancel, // Also reset on cancel
                    behavior: HitTestBehavior.translucent, // Ensure hit testing works through the widget
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: const EdgeInsets.all(double.infinity), // Allow panning beyond content
                      minScale: 0.1,
                      maxScale: 4.0,
                      // Disable InteractiveViewer's pan/scale only when dragging a node
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
                          // No explicit child needed as CustomPaint draws directly
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

  // Local state for the painter, initialized once
  late final Map<String, Offset> _internalPositions;
  final bool _positionsInitialized = false;

  KeywordNetworkPainter({
    required this.keywords,
    required this.centralNode,
    required this.connectionCounts,
    required this.coOccurrences,
    required this.coOccurrenceCounts,
    required this.maxConnections,
    required this.nodePositions, // Use positions from state
    required this.nodeDistances,
  });

  // Consistent node radius calculation
  double _calculateNodeRadius(String keyword) {
    final connections = connectionCounts[keyword] ?? 0;
    // Use maxConnections from the provided parameter, ensuring it's > 0
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
      case 0: // Central node
        return Colors.redAccent.shade400;
      case 1: // 1 hop: Green spectrum
        return Color.lerp(Colors.lightGreen.shade300, Colors.green.shade700, normalizedConnections) ?? Colors.green;
      case 2: // 2 hops: Blue spectrum
        return Color.lerp(Colors.lightBlue.shade300, Colors.blue.shade700, normalizedConnections) ?? Colors.blue;
      case 3: // 3 hops: Purple spectrum
         return Color.lerp(Colors.purple.shade200, Colors.purple.shade600, normalizedConnections) ?? Colors.purple;
      default: // 4+ hops or disconnected (-1): Orange/Yellow spectrum
        return Color.lerp(Colors.amber.shade300, Colors.deepOrange.shade400, normalizedConnections) ?? Colors.orange;
    }
  }

   @override
  void paint(Canvas canvas, Size size) {
    if (keywords.isEmpty) return;

    // Use the nodePositions passed from the stateful widget directly
    // No need to initialize or simulate positions within the painter anymore
    // The stateful widget now manages the positions.

    // --- Draw Edges ---
    final edgePaint = Paint()
      ..color = AppTheme.textColor.withOpacity(0.2) // Subtler edge color
      ..strokeWidth = 0.8 // Thinner edges
      ..style = PaintingStyle.stroke;

    final drawnEdges = <String>{}; // Prevent drawing duplicate edges

    for (var keyword1 in keywords) {
      final pos1 = nodePositions[keyword1]; // Use state positions
      if (pos1 == null) continue;

      final neighbors = coOccurrences[keyword1] ?? {};
      for (var keyword2 in neighbors) {
        // Only draw edge if neighbor is also in topKeywords (visible) and has a position
        if (keywords.contains(keyword2)) {
            final pos2 = nodePositions[keyword2]; // Use state positions
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
    // Draw non-central nodes first, then central node on top for better visibility
    final nonCentralKeywords = keywords.where((k) => k != centralNode).toList();
    final centralKeywordList = (centralNode != null && keywords.contains(centralNode!)) ? [centralNode!] : <String>[];

    for (var keyword in nonCentralKeywords.followedBy(centralKeywordList)) {
      final nodePos = nodePositions[keyword]; // Use state positions
      if (nodePos == null) continue; // Skip if position somehow doesn't exist

      final isCentral = keyword == centralNode;
      final nodeRadius = _calculateNodeRadius(keyword);
      final nodeColor = _getColorForDistance(keyword);

      // Node Fill
      final nodePaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      // Optional: Add slight shadow to nodes for depth
       canvas.drawCircle(nodePos.translate(1, 1), nodeRadius, Paint()..color = Colors.black.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawCircle(nodePos, nodeRadius, nodePaint);


      // Node Border
      final borderPaint = Paint()
        ..color = isCentral ? Colors.white.withOpacity(0.9) : nodeColor.withOpacity(0.8).withAlpha(150) // Adjusted border colors
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
        color: Colors.white.withOpacity(0.95), // Brighter text for contrast
        shadows: [ // Subtle shadow for readability against node color
          Shadow(
            offset: const Offset(1.0, 1.0),
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

      textPainter.layout(maxWidth: nodeRadius * 1.8); // Ensure text fits roughly within node diameter

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

   // REMOVED: _initializeNodePositions - Now handled by the stateful widget
   // REMOVED: _runForceSimulation - Now handled by the stateful widget

  @override
  bool shouldRepaint(covariant KeywordNetworkPainter oldDelegate) {
    // Repaint if node positions, distances, keywords, max connections, or central node change.
    // Comparing nodePositions map directly works because we're passing the state's map.
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
  // Check if the lists are identical first (performance)
  if (identical(a, b)) return true;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
} 