import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/video_analysis_result.dart';
import '../../models/keyword_sentiment.dart';
import '../app_theme.dart';
import 'dart:math' as math;

class SentimentComparisonTable extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;

  const SentimentComparisonTable({
    super.key,
    required this.analysisResults,
  });

  @override
  State<SentimentComparisonTable> createState() => _SentimentComparisonTableState();
}

class _SentimentComparisonTableState extends State<SentimentComparisonTable>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String selectedComparison = 'keyword'; // keyword, channel, time

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Map<String, Map<String, double>> _getKeywordSentimentComparison() {
    final keywordEmotions = <String, Map<String, int>>{};
    
    for (final result in widget.analysisResults) {
      for (final keywordSentiment in result.keywords) {
        final keyword = keywordSentiment.keyword;
        final emotion = result.overallEmotion;
        
        keywordEmotions.putIfAbsent(keyword, () => <String, int>{});
        keywordEmotions[keyword]![emotion] = (keywordEmotions[keyword]![emotion] ?? 0) + 1;
      }
    }
    
    // 상위 8개 키워드만 선택하고 비율로 변환
    final sortedKeywords = keywordEmotions.entries.toList()
      ..sort((a, b) => b.value.values.reduce((x, y) => x + y).compareTo(a.value.values.reduce((x, y) => x + y)));
    
    final result = <String, Map<String, double>>{};
    for (final entry in sortedKeywords.take(8)) {
      final total = entry.value.values.reduce((a, b) => a + b);
      result[entry.key] = entry.value.map((emotion, count) => MapEntry(emotion, count / total * 100));
    }
    
    return result;
  }

  Map<String, Map<String, double>> _getChannelSentimentComparison() {
    final channelEmotions = <String, Map<String, int>>{};
    
    for (final result in widget.analysisResults) {
      // YoutubeData에 channelTitle이 없으므로 videoId를 기반으로 채널 구분
      final channel = result.youtubeData.videoId.substring(0, math.min(8, result.youtubeData.videoId.length));
      final emotion = result.overallEmotion;
      
      channelEmotions.putIfAbsent(channel, () => <String, int>{});
      channelEmotions[channel]![emotion] = (channelEmotions[channel]![emotion] ?? 0) + 1;
    }
    
    // 상위 6개 채널만 선택하고 비율로 변환
    final sortedChannels = channelEmotions.entries.toList()
      ..sort((a, b) => b.value.values.reduce((x, y) => x + y).compareTo(a.value.values.reduce((x, y) => x + y)));
    
    final result = <String, Map<String, double>>{};
    for (final entry in sortedChannels.take(6)) {
      final total = entry.value.values.reduce((a, b) => a + b);
      result[entry.key] = entry.value.map((emotion, count) => MapEntry(emotion, count / total * 100));
    }
    
    return result;
  }

  List<Map<String, dynamic>> _getTimeTrendData() {
    // 간단한 시간대별 분석 (실제로는 더 정교한 시간 파싱이 필요)
    final timeEmotions = <String, Map<String, int>>{};
    
    for (final result in widget.analysisResults) {
      try {
        final publishedDate = DateTime.parse(result.youtubeData.timestamp);
        final timeKey = '${publishedDate.year}-${publishedDate.month.toString().padLeft(2, '0')}';
        final emotion = result.overallEmotion;
        
        timeEmotions.putIfAbsent(timeKey, () => <String, int>{});
        timeEmotions[timeKey]![emotion] = (timeEmotions[timeKey]![emotion] ?? 0) + 1;
      } catch (e) {
        // 날짜 파싱 실패 시 스킵
      }
    }
    
    // 시간순 정렬
    final sortedTimes = timeEmotions.keys.toList()..sort();
    
    return sortedTimes.map((timeKey) {
      final emotions = timeEmotions[timeKey]!;
      final total = emotions.values.reduce((a, b) => a + b);
      final dominantEmotion = emotions.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      
      return {
        'period': timeKey,
        'totalVideos': total,
        'dominantEmotion': dominantEmotion,
        'emotions': emotions.map((emotion, count) => MapEntry(emotion, count / total * 100)),
      };
    }).toList();
  }

  Widget _buildComparisonSelector() {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              '비교 유형: ',
              style: TextStyle(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  _buildSelectorButton('keyword', '키워드별', Icons.tag),
                  const SizedBox(width: 8),
                  _buildSelectorButton('channel', '채널별', Icons.person),
                  const SizedBox(width: 8),
                  _buildSelectorButton('time', '시간별', Icons.timeline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorButton(String value, String label, IconData icon) {
    final isSelected = selectedComparison == value;
    return Expanded(
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          setState(() {
            selectedComparison = value;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.primaryColor : AppTheme.secondaryColor,
          foregroundColor: AppTheme.textColor,
          elevation: isSelected ? 4 : 1,
        ),
      ),
    );
  }

  Widget _buildKeywordComparisonMatrix() {
    final comparisonData = _getKeywordSentimentComparison();
    if (comparisonData.isEmpty) {
      return const Center(child: Text('키워드 데이터가 없습니다.', style: TextStyle(color: AppTheme.textColor)));
    }

    final allEmotions = <String>{};
    for (final emotionMap in comparisonData.values) {
      allEmotions.addAll(emotionMap.keys);
    }
    final emotions = allEmotions.toList()..sort();

    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔍 키워드별 감성 비교 매트릭스',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppTheme.secondaryColor),
                    columns: [
                      const DataColumn(
                        label: Text(
                          '키워드',
                          style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...emotions.map((emotion) => DataColumn(
                        label: Text(
                          emotion,
                          style: TextStyle(
                            color: AppTheme.getBasicEmotionColor(emotion),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )),
                    ],
                    rows: comparisonData.entries.map((entry) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.key.length > 10 ? '${entry.key.substring(0, 10)}...' : entry.key,
                                style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                          ...emotions.map((emotion) {
                            final percentage = entry.value[emotion] ?? 0.0;
                            return DataCell(
                              Container(
                                width: 60,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppTheme.getBasicEmotionColor(emotion).withOpacity(percentage / 100),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      color: percentage > 50 ? Colors.white : AppTheme.textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelComparisonRadar() {
    final comparisonData = _getChannelSentimentComparison();
    if (comparisonData.isEmpty) {
      return const Center(child: Text('채널 데이터가 없습니다.', style: TextStyle(color: AppTheme.textColor)));
    }

    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👤 채널별 감성 프로파일링',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: comparisonData.length,
                itemBuilder: (context, index) {
                  final entry = comparisonData.entries.elementAt(index);
                  final channelName = entry.key;
                  final emotions = entry.value;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    color: AppTheme.secondaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            channelName.length > 30 ? '${channelName.substring(0, 30)}...' : channelName,
                            style: const TextStyle(
                              color: AppTheme.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: emotions.entries.map((emotionEntry) {
                              final flex = emotionEntry.value.round();
                              if (flex <= 0) return Container();
                              return Expanded(
                                flex: flex,
                                child: Container(
                                  height: 20,
                                  color: AppTheme.getBasicEmotionColor(emotionEntry.key),
                                  child: Center(
                                    child: Text(
                                      emotionEntry.value > 5 ? '${emotionEntry.value.toStringAsFixed(0)}%' : '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
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

  Widget _buildTimeComparisonChart() {
    final timeData = _getTimeTrendData();
    if (timeData.isEmpty) {
      return const Center(child: Text('시간 데이터가 없습니다.', style: TextStyle(color: AppTheme.textColor)));
    }

    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⏰ 시간대별 감성 트렌드',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppTheme.secondaryColor),
                  columns: const [
                    DataColumn(
                      label: Text(
                        '기간',
                        style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '총 동영상',
                        style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '주요 감정',
                        style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        '감정 분포',
                        style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: timeData.map((data) {
                    return DataRow(
                      cells: [
                        DataCell(Text(data['period'], style: const TextStyle(color: AppTheme.textColor))),
                        DataCell(Text(data['totalVideos'].toString(), style: const TextStyle(color: AppTheme.textColor))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.getBasicEmotionColor(data['dominantEmotion']).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              data['dominantEmotion'],
                              style: TextStyle(
                                color: AppTheme.getBasicEmotionColor(data['dominantEmotion']),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 200,
                            height: 20,
                            child: Row(
                              children: (data['emotions'] as Map<String, double>).entries.map((emotionEntry) {
                                final flex = emotionEntry.value.round();
                                if (flex <= 0) return Container();
                                return Expanded(
                                  flex: flex,
                                  child: Container(
                                    height: 20,
                                    color: AppTheme.getBasicEmotionColor(emotionEntry.key),
                                    child: Center(
                                      child: Text(
                                        emotionEntry.value > 10 ? '${emotionEntry.value.toStringAsFixed(0)}%' : '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentComparison() {
    switch (selectedComparison) {
      case 'keyword':
        return _buildKeywordComparisonMatrix();
      case 'channel':
        return _buildChannelComparisonRadar();
      case 'time':
        return _buildTimeComparisonChart();
      default:
        return _buildKeywordComparisonMatrix();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysisResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.compare_arrows, size: 64, color: AppTheme.textColor),
            SizedBox(height: 16),
            Text(
              '비교할 데이터가 없습니다.',
              style: TextStyle(fontSize: 18, color: AppTheme.textColor),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildComparisonSelector(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCurrentComparison(),
            ),
          ],
        ),
      ),
    );
  }
} 