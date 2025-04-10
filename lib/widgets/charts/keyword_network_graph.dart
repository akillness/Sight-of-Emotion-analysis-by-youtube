import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import '../../models/video_analysis_result.dart';
import '../../models/keyword_sentiment.dart';
import 'dart:math';
import '../../widgets/app_theme.dart';

class KeywordNetworkGraph extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;

  const KeywordNetworkGraph({super.key, required this.analysisResults});

  @override
  State<KeywordNetworkGraph> createState() => _KeywordNetworkGraphState();
}

class _KeywordNetworkGraphState extends State<KeywordNetworkGraph> {
  final Graph graph = Graph();
  late Algorithm builder;

  // 키워드에 관련된 맵
  final Map<String, Node> keywordNodes = {};
  final Map<String, double> keywordScores = {};
  final Map<String, int> keywordFrequency = {};
  final Map<String, Set<String>> coOccurrences = {};
  final Map<String, int> edgeWeights = {};
  final Map<Edge, double> edgeScores = {};
  final Map<String, int> connectionCounts = {};
  
  // 가장 많은 연결을 가진 중심 노드
  String? _centralNode;
  bool _isGraphInitialized = false;

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

  // 엣지 스코어에 따른 거리 계산 함수
  double _getDistanceByScore(double score) {
    // 점수가 높을수록 거리가 가깝게 (작게)
    score = score.abs().clamp(0.1, 1.0);
    // 기본 거리 계산: 점수가 높을수록 거리가 가깝게 (반비례)
    return 300 / score; 
  }

  // 연결 수에 따른 노드 색상 계산
  Color _getNodeColor(int connections) {
    // 연결이 많을수록 더 진한 색상으로
    final maxConnectionCount = connectionCounts.values.isEmpty 
        ? 1 
        : connectionCounts.values.reduce(max);
    
    // 연결 수가 많을수록 1에 가까워지는 비율 계산
    final ratio = connections / maxConnectionCount;
    
    // AppTheme.primaryColor를 기본 색상으로 사용하고 연결이 적을수록 옅어짐
    return Color.lerp(
      AppTheme.primaryColor.withOpacity(0.3),
      AppTheme.primaryColor,
      ratio
    ) ?? AppTheme.primaryColor;
  }

  void _buildGraph() {
    if (widget.analysisResults.isEmpty) {
      _isGraphInitialized = false;
      return;
    }

    // 기존 데이터 초기화
    graph.nodes.clear();
    graph.edges.clear();
    keywordNodes.clear();
    keywordScores.clear();
    keywordFrequency.clear();
    coOccurrences.clear();
    edgeWeights.clear();
    edgeScores.clear();
    connectionCounts.clear();

    // Step 1: 키워드, 점수, 빈도 수집
    for (var result in widget.analysisResults) {
      Set<String> keywordsInVideo = {};
      for (var ks in result.keywords) {
        final keyword = ks.keyword; // 소문자로 변환하지 않고 원래 형태 유지
        keywordsInVideo.add(keyword);
        keywordNodes.putIfAbsent(keyword, () => Node.Id(keyword));
        
        // 점수 저장 (나중에 평균 계산)
        keywordScores[keyword] = (keywordScores[keyword] ?? 0.0) + ks.score; 
        keywordFrequency[keyword] = (keywordFrequency[keyword] ?? 0) + 1;
      }

      // Step 2: 동시 출현(co-occurrence) 및 가중치 추적
      List<String> keywordsList = keywordsInVideo.toList();
      for (int i = 0; i < keywordsList.length; i++) {
        for (int j = i + 1; j < keywordsList.length; j++) {
          String kw1 = keywordsList[i];
          String kw2 = keywordsList[j];
          List<String> edgePair = [kw1, kw2];
          edgePair.sort(); 
          String edgeKey = edgePair.join('--'); 
          
          // 동시 출현 관계 추가
          coOccurrences.putIfAbsent(kw1, () => {}).add(kw2);
          coOccurrences.putIfAbsent(kw2, () => {}).add(kw1);
          
          // 엣지 가중치 증가
          edgeWeights[edgeKey] = (edgeWeights[edgeKey] ?? 0) + 1; 
        }
      }
    }

    // Step 3: 평균 점수 계산
    keywordScores.forEach((key, value) {
      int freq = keywordFrequency[key] ?? 1;
      keywordScores[key] = (freq == 0) ? 0.0 : value / freq;
    });

    // Step 4: 각 키워드의 연결 수 계산
    coOccurrences.forEach((keyword, connectedKeywords) {
      connectionCounts[keyword] = connectedKeywords.length;
    });

    // Step 5: 가장 많은 연결을 가진 중심 노드 찾기
    if (connectionCounts.isNotEmpty) {
      _centralNode = connectionCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Step 6: 중심 노드가 있는 경우 해당 노드와 연결된 노드만 그래프에 추가
    if (_centralNode != null) {
      // 중심 노드 추가
      final centralNodeObj = keywordNodes[_centralNode]!;
      graph.addNode(centralNodeObj);
      
      // 중심 노드와 연결된 노드들만 추가
      final connectedKeywords = coOccurrences[_centralNode] ?? {};
      for (var connectedKeyword in connectedKeywords) {
        if (keywordNodes.containsKey(connectedKeyword)) {
          graph.addNode(keywordNodes[connectedKeyword]!);
          
          // 엣지 추가
          List<String> pair = [_centralNode!, connectedKeyword];
          pair.sort();
          String edgeKey = pair.join('--');
          
          Edge edge = graph.addEdge(
            centralNodeObj, 
            keywordNodes[connectedKeyword]!
          );
          
          // 엣지 점수 계산 (두 키워드의 평균 점수)
          double edgeScore = (keywordScores[_centralNode]! + keywordScores[connectedKeyword]!) / 2;
          edgeScores[edge] = edgeScore;
        }
      }
      
      // 추가된 노드들 간의 상호 연결 추가
      for (var keywordA in connectedKeywords) {
        if (!keywordNodes.containsKey(keywordA)) continue;
        
        for (var keywordB in connectedKeywords) {
          if (keywordA == keywordB || !keywordNodes.containsKey(keywordB)) continue;
          
          // 두 키워드가 동시 출현하는지 확인
          if (coOccurrences[keywordA]?.contains(keywordB) == true) {
            List<String> pair = [keywordA, keywordB];
            pair.sort();
            String edgeKey = pair.join('--');
            
            // 이미 추가된 엣지는 건너뛰기
            if (edgeScores.values.length >= 
                graph.nodes.length * (graph.nodes.length - 1) / 2) {
              continue;
            }
            
            // 엣지 추가
            Edge edge = graph.addEdge(
              keywordNodes[keywordA]!, 
              keywordNodes[keywordB]!
            );
            
            // 엣지 점수 계산
            double edgeScore = (keywordScores[keywordA]! + keywordScores[keywordB]!) / 2;
            edgeScores[edge] = edgeScore;
          }
        }
      }
    }

    // Step 7: 그래프 레이아웃 알고리즘 설정
    // FruchtermanReingoldAlgorithm을 사용하되 적절한 매개변수 사용
    builder = FruchtermanReingoldAlgorithm(
      iterations: 1000,
    );

    _isGraphInitialized = true;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_isGraphInitialized || graph.nodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bubble_chart,
              size: 64,
              color: AppTheme.primaryColor.withOpacity(0.5),
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

    return Card(
      elevation: 4,
      color: AppTheme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.hub,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '키워드 네트워크 분석',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(100),
                minScale: 0.1,
                maxScale: 2.0,
                child: GraphView(
                  graph: graph,
                  algorithm: builder,
                  paint: Paint()
                    ..color = AppTheme.primaryColor.withOpacity(0.7)
                    ..strokeWidth = 1.5,
                  builder: (Node node) {
                    String keyword = node.key?.value as String? ?? '';
                    final connections = connectionCounts[keyword] ?? 0;
                    
                    // 연결 수에 따라 노드 크기 결정 (최소 사이즈 보장)
                    final nodeRadius = 20.0 + (connections * 3.0);
                    final Color nodeColor = _getNodeColor(connections);
                    
                    // 중심 노드인지 확인
                    final isCentralNode = keyword == _centralNode;
                    
                    return Container(
                      width: nodeRadius * 2,
                      height: nodeRadius * 2,
                      decoration: BoxDecoration(
                        color: nodeColor.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: nodeColor.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: isCentralNode 
                            ? Colors.white 
                            : nodeColor,
                          width: isCentralNode ? 2.0 : 1.0,
                        ),
                      ),
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 텍스트
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  keyword,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: isCentralNode 
                                      ? FontWeight.bold 
                                      : FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 1),
                                        blurRadius: 3,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // 연결 수를 표시하는 작은 배지 (오른쪽 상단)
                            if (connections > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1),
                                  ),
                                  child: Text(
                                    connections.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 