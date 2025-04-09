import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/video_analysis_result.dart';
import '../../models/keyword_sentiment.dart';
import 'dart:math';

class KeywordNetworkGraph extends StatelessWidget {
  final List<VideoAnalysisResult> analysisResults;
  final Graph graph = Graph();
  late Algorithm builder;

  final Map<String, Node> keywordNodes = {};
  final Map<String, double> keywordScores = {}; // Keep scores even if not used for edge color
  final Map<String, int> keywordFrequency = {}; // Keep frequency for potential future use
  final Map<String, Set<String>> coOccurrences = {};
  final Map<String, int> edgeWeights = {}; // Keep weights for potential future use

  KeywordNetworkGraph({super.key, required this.analysisResults}) {
    _buildGraph();
    builder = FruchtermanReingoldAlgorithm(); // Use default settings
  }

  // Color function (kept in case needed elsewhere, but not used for graph)
  /*
  Color _getColorForScore(double score) {
    score = score.clamp(-1.0, 1.0);
    if (score < 0) {
      return Color.lerp(Colors.yellow.shade600, Colors.red.shade400, -score)!;
    } else {
      return Color.lerp(Colors.yellow.shade600, Colors.green.shade400, score)!;
    }
  }
  */

  void _buildGraph() {
    keywordNodes.clear();
    keywordScores.clear();
    keywordFrequency.clear();
    coOccurrences.clear();
    edgeWeights.clear(); 

    // Step 1: Collect keywords, scores, frequencies
    for (var result in analysisResults) {
      Set<String> keywordsInVideo = {};
      for (var ks in result.keywords) {
        final keyword = ks.keyword.toLowerCase(); 
        keywordsInVideo.add(keyword);
        keywordNodes.putIfAbsent(keyword, () => Node.Id(keyword));
        
        // Store score (average later)
        keywordScores[keyword] = (keywordScores[keyword] ?? 0.0) + ks.score; 
        keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
      }

      // Step 2: Track co-occurrences and weights
      List<String> keywordsList = keywordsInVideo.toList();
      for (int i = 0; i < keywordsList.length; i++) {
        for (int j = i + 1; j < keywordsList.length; j++) {
          String kw1 = keywordsList[i];
          String kw2 = keywordsList[j];
          List<String> edgePair = [kw1, kw2];
          edgePair.sort(); 
          String edgeKey = edgePair.join('--'); 
          
          coOccurrences.putIfAbsent(kw1, () => {}).add(kw2);
          coOccurrences.putIfAbsent(kw2, () => {}).add(kw1);
          
          edgeWeights[edgeKey] = (edgeWeights[edgeKey] ?? 0) + 1; 
        }
      }
    }

    // Step 1.5: Calculate average scores
    keywordScores.forEach((key, value) {
      int freq = keywordFrequency[key] ?? 1;
      keywordScores[key] = (freq == 0) ? 0.0 : value / freq;
    });

    // Step 3: Add nodes and edges, filtering orphans
    Set<String> nodesWithEdges = {};
    edgeWeights.forEach((key, weight) {
       List<String> pair = key.split('--');
       if (pair.length == 2) {
         nodesWithEdges.add(pair[0]);
         nodesWithEdges.add(pair[1]);
       }
    });

    nodesWithEdges.forEach((keyword) {
      if (keywordNodes.containsKey(keyword)) {
        graph.addNode(keywordNodes[keyword]!);
      }
    });

    // Add edges ONCE
    edgeWeights.forEach((key, weight) { 
      List<String> pair = key.split('--');
      if (pair.length == 2) {
        String keyword1 = pair[0];
        String keyword2 = pair[1];

        if (nodesWithEdges.contains(keyword1) && nodesWithEdges.contains(keyword2)) {
          Node? node1 = keywordNodes[keyword1]; 
          Node? node2 = keywordNodes[keyword2];

          if (node1 != null && node2 != null) {
            if (node1 != node2) { 
              graph.addEdge(node1, node2);
            }
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (graph.nodes.isEmpty) {
      return const Center(child: Text("키워드가 부족하거나 연결된 키워드가 없어 네트워크를 생성할 수 없습니다."));
    }

    return InteractiveViewer(
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100), 
      minScale: 0.01,
      maxScale: 2.0,
      trackpadScrollCausesScale: true,
      child: GraphView(
        graph: graph,
        algorithm: builder,
        // Use default paint for all edges
        paint: Paint()
          ..color = Colors.grey.shade400 // Neutral edge color
          ..strokeWidth = 1.0,
        builder: (Node node) {
          String keyword = node.key?.value as String? ?? '';
          // Node size based on keyword length
          double nodeRadius = 8 + (keyword.length * 1.2); // Adjust base and multiplier
          
          return Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade100, // Use a neutral node color
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.blueGrey.shade300, width: 1.5)
            ),
            width: nodeRadius * 2,
            height: nodeRadius * 2,
            child: Center(
              child: Text(
                keyword,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black87,
                  // Adjust font size based on node radius, clamping it
                  fontSize: (nodeRadius * 0.5).clamp(6.0, 14.0),
                  fontWeight: FontWeight.w500,
                ),
                 overflow: TextOverflow.fade,
                 softWrap: false,
              ),
            ),
          );
        },
      ),
    );
  }
} 