import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/video_analysis_result.dart';
import '../app_theme.dart';
import 'dart:math' as math;

class DataDistributionDashboard extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;

  const DataDistributionDashboard({
    super.key,
    required this.analysisResults,
  });

  @override
  State<DataDistributionDashboard> createState() => _DataDistributionDashboardState();
}

class _DataDistributionDashboardState extends State<DataDistributionDashboard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

  Map<String, int> _getEmotionDistribution() {
    final emotionCounts = <String, int>{};
    for (final result in widget.analysisResults) {
      final emotion = result.overallEmotion;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }
    return emotionCounts;
  }

  Map<String, int> _getKeywordFrequency() {
    final keywordCounts = <String, int>{};
    for (final result in widget.analysisResults) {
      for (final keywordSentiment in result.keywords) {
        final keyword = keywordSentiment.keyword;
        keywordCounts[keyword] = (keywordCounts[keyword] ?? 0) + 1;
      }
    }
    // 상위 10개만 반환
    final sorted = keywordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(10));
  }

  Map<String, double> _getViewsStatistics() {
    if (widget.analysisResults.isEmpty) return {};
    
    final views = widget.analysisResults.map((r) => r.youtubeData.views.toDouble()).toList();
    views.sort();
    
    final mean = views.reduce((a, b) => a + b) / views.length;
    final median = views.length % 2 == 0
        ? (views[views.length ~/ 2 - 1] + views[views.length ~/ 2]) / 2
        : views[views.length ~/ 2];
    
    final variance = views.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / views.length;
    final stdDev = math.sqrt(variance);
    
    return {
      '평균': mean,
      '중앙값': median,
      '표준편차': stdDev,
      '최소값': views.first,
      '최대값': views.last,
    };
  }

  Widget _buildEmotionHistogram() {
    final emotionData = _getEmotionDistribution();
    if (emotionData.isEmpty) {
      return const Center(child: Text('감정 데이터가 없습니다.', style: TextStyle(color: AppTheme.textColor)));
    }

    final maxCount = emotionData.values.reduce(math.max);
    
    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 감정 분포 히스토그램',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount.toDouble() * 1.2,
                                     barTouchData: BarTouchData(
                     touchTooltipData: BarTouchTooltipData(
                       getTooltipColor: (group) => AppTheme.secondaryColor,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final emotion = emotionData.keys.elementAt(groupIndex);
                        final count = emotionData[emotion]!;
                        final percentage = (count / widget.analysisResults.length * 100).toStringAsFixed(1);
                        return BarTooltipItem(
                          '$emotion\n$count개 ($percentage%)',
                          const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxCount / 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.textColor.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: emotionData.entries.map((entry) {
                    final index = emotionData.keys.toList().indexOf(entry.key);
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: AppTheme.getBasicEmotionColor(entry.key),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(color: AppTheme.textColor, fontSize: 12),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final emotions = emotionData.keys.toList();
                          if (value.toInt() < emotions.length) {
                            return Transform.rotate(
                              angle: -math.pi / 4,
                              child: Text(
                                emotions[value.toInt()],
                                style: const TextStyle(color: AppTheme.textColor, fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordFrequencyTable() {
    final keywordData = _getKeywordFrequency();
    
    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔤 키워드 빈도 분포',
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
                    DataColumn(label: Text('키워드', style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('빈도', style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('비율(%)', style: TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold))),
                  ],
                  rows: keywordData.entries.map((entry) {
                    final percentage = (entry.value / widget.analysisResults.length * 100).toStringAsFixed(1);
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
                              entry.key,
                              style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        DataCell(Text(entry.value.toString(), style: const TextStyle(color: AppTheme.textColor))),
                        DataCell(Text('$percentage%', style: const TextStyle(color: AppTheme.textColor))),
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

  Widget _buildStatisticsCard() {
    final stats = _getViewsStatistics();
    
    return Card(
      color: AppTheme.cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 조회수 통계 분포',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Column(
                children: stats.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppTheme.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatNumber(entry.value),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.analysisResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: AppTheme.textColor),
            SizedBox(height: 16),
            Text(
              '분석할 데이터가 없습니다.',
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
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildEmotionHistogram(),
            _buildKeywordFrequencyTable(),
            _buildStatisticsCard(),
            Card(
              color: AppTheme.cardColor,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 분석 요약',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryItem('총 동영상 수', widget.analysisResults.length.toString()),
                          _buildSummaryItem('분석된 감정 종류', _getEmotionDistribution().length.toString()),
                          _buildSummaryItem('추출된 키워드 수', _getKeywordFrequency().length.toString()),
                          _buildSummaryItem('주요 감정', _getDominantEmotion()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textColor),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getDominantEmotion() {
    final emotionData = _getEmotionDistribution();
    if (emotionData.isEmpty) return 'N/A';
    
    final sortedEmotions = emotionData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedEmotions.first.key;
  }
} 