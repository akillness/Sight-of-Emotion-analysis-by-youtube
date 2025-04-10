import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/youtube_data.dart';
import 'package:intl/intl.dart';
import '../../widgets/app_theme.dart';

class TrendsPieChart extends StatefulWidget {
  final List<YoutubeData> trends;
  final int itemCount;

  const TrendsPieChart({
    super.key,
    required this.trends,
    this.itemCount = 5,
  });

  @override
  State<TrendsPieChart> createState() => _TrendsPieChartState();
}

class _TrendsPieChartState extends State<TrendsPieChart> with SingleTickerProviderStateMixin {
  int? touchedIndex;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 모던한 차트 색상 팔레트
  static const List<Color> chartColors = [
    Color(0xFF4A6FFF), // 파란색
    Color(0xFFFF6B6B), // 빨간색
    Color(0xFF25C685), // 녹색
    Color(0xFFFFA94D), // 주황색
    Color(0xFF845EF7), // 보라색
    Color(0xFF22B8CF), // 청록색
    Color(0xFFFF8ED4), // 분홍색
    Color(0xFF5C7CFA), // 인디고
    Color(0xFFFFD43B), // 노란색
    Color(0xFF3BC9DB), // 하늘색
  ];

  @override
  Widget build(BuildContext context) {
    final topItems = widget.trends.take(widget.itemCount).toList();
    final total = topItems.fold<int>(0, (sum, item) => sum + item.views);
    
    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 16.0),
              child: Text(
                '인기 트렌드 분석',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: touchedIndex != null ? _scaleAnimation.value : 1.0,
                        child: MouseRegion(
                          onEnter: (_) => _controller.forward(),
                          onExit: (_) {
                            _controller.reverse();
                            setState(() => touchedIndex = null);
                          },
                          child: PieChart(
                            PieChartData(
                              sections: topItems.asMap().entries.map((entry) {
                                final percentage = (entry.value.views / total) * 100;
                                final isTouched = entry.key == touchedIndex;
                                final double radius = isTouched ? 110 : 100;
                                
                                return PieChartSectionData(
                                  value: entry.value.views.toDouble(),
                                  title: '${percentage.toStringAsFixed(1)}%',
                                  radius: radius,
                                  titleStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 2,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  color: chartColors[entry.key % chartColors.length],
                                  borderSide: isTouched
                                      ? const BorderSide(color: Colors.white, width: 2)
                                      : BorderSide.none,
                                  titlePositionPercentageOffset: 0.55,
                                  badgeWidget: isTouched ? _buildBadge(entry.value) : null,
                                  badgePositionPercentageOffset: 1.2,
                                );
                              }).toList(),
                              sectionsSpace: 3,
                              centerSpaceRadius: 50,
                              centerSpaceColor: Colors.white,
                              pieTouchData: PieTouchData(
                                enabled: true,
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (event is FlPointerHoverEvent || event is FlTapUpEvent) {
                                      touchedIndex = pieTouchResponse?.touchedSection?.touchedSectionIndex;
                                    }
                                  });
                                },
                              ),
                            ),
                            swapAnimationDuration: const Duration(milliseconds: 300),
                            swapAnimationCurve: Curves.easeInOutCubic,
                          ),
                        ),
                      );
                    },
                  ),
                  if (topItems.isEmpty)
                    const Center(
                      child: Text(
                        '데이터가 없습니다',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade200, thickness: 1),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: topItems.asMap().entries.map((entry) {
                    final isTouched = entry.key == touchedIndex;
                    final itemColor = chartColors[entry.key % chartColors.length];
                    
                    return MouseRegion(
                      onEnter: (_) {
                        setState(() => touchedIndex = entry.key);
                        _controller.forward();
                      },
                      onExit: (_) {
                        setState(() => touchedIndex = null);
                        _controller.reverse();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: isTouched ? itemColor.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isTouched
                              ? Border.all(color: itemColor, width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isTouched ? 20 : 16,
                              height: isTouched ? 20 : 16,
                              decoration: BoxDecoration(
                                color: itemColor,
                                shape: BoxShape.circle,
                                boxShadow: isTouched
                                    ? [
                                        BoxShadow(
                                          color: itemColor.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.value.title,
                                    style: TextStyle(
                                      fontSize: isTouched ? 15 : 14,
                                      fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
                                      color: const Color(0xFF2C3E50),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        NumberFormat.compact().format(entry.value.views),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.thumb_up_outlined,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        NumberFormat.compact().format(entry.value.likes),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isTouched && entry.value.keywords.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: entry.value.keywords.take(3).map((keyword) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: itemColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: itemColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            keyword,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: itemColor.withOpacity(0.8),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildBadge(YoutubeData data) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 14,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                NumberFormat.compact().format(data.views),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.thumb_up_outlined,
                size: 14,
                color: Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 4),
              Text(
                NumberFormat.compact().format(data.likes),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 