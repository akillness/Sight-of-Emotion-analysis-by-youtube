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

  // Use colors derived from AppTheme
  List<Color> getChartColors(BuildContext context) {
    // Generate variations or use a predefined palette fitting the theme
    return [
      AppTheme.primaryColor,
      AppTheme.primaryColor.withOpacity(0.7),
      AppTheme.secondaryColor,
      AppTheme.secondaryColor.withOpacity(0.7),
      AppTheme.accentColor.withOpacity(0.8),
      AppTheme.accentColor.withOpacity(0.5),
      Colors.blueGrey, // Add more theme-consistent colors if needed
      Colors.teal,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final topItems = widget.trends.take(widget.itemCount).toList();
    final total = topItems.fold<int>(0, (sum, item) => sum + item.views);
    final currentChartColors = getChartColors(context); // Get theme-based colors
    
    return Card(
      // Use AppTheme card styling
      color: AppTheme.cardColor,
      elevation: Theme.of(context).cardTheme.elevation ?? 4, 
      shadowColor: Colors.black.withOpacity(0.5), // Darker shadow for dark theme
      shape: Theme.of(context).cardTheme.shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Consistent rounding
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                '인기 트렌드 분석',
                // Use AppTheme text style
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppTheme.textColor),
              ),
            ),
            Expanded(
              flex: 3, // Give more space to the chart
              child: Stack(
                alignment: Alignment.center, // Center the chart
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
                                final double radius = isTouched ? 65 : 60; // Adjusted radius for dark theme
                                final double fontSize = isTouched ? 14 : 12; // Adjusted font size

                                return PieChartSectionData(
                                  value: entry.value.views.toDouble(),
                                  title: '${percentage.toStringAsFixed(0)}%', // Simpler percentage
                                  radius: radius,
                                  titleStyle: TextStyle( // Use AppTheme text color
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentColor, // White text on colored sections
                                    shadows: const [
                                      Shadow(color: Colors.black54, blurRadius: 2)
                                    ],
                                  ),
                                  // Use theme-based colors
                                  color: currentChartColors[entry.key % currentChartColors.length],
                                  borderSide: isTouched
                                      // Use AppTheme primary color for border
                                      ? const BorderSide(color: AppTheme.primaryColor, width: 2)
                                      : BorderSide(color: AppTheme.backgroundColor.withOpacity(0.5), width: 1), // Subtle border for non-touched
                                  titlePositionPercentageOffset: 0.6, // Adjust position
                                  badgeWidget: isTouched ? _buildBadge(entry.value, currentChartColors[entry.key % currentChartColors.length]) : null, // Pass color to badge
                                  badgePositionPercentageOffset: 1.15, // Adjust badge position
                                );
                              }).toList(),
                              sectionsSpace: 2, // Reduced space
                              centerSpaceRadius: 40, // Smaller center space
                              centerSpaceColor: AppTheme.cardColor, // Match card background
                              pieTouchData: PieTouchData(
                                enabled: true,
                                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                  setState(() {
                                    if (!event.isInterestedForInteractions ||
                                        pieTouchResponse == null ||
                                        pieTouchResponse.touchedSection == null) {
                                      touchedIndex = -1;
                                      if (_controller.isCompleted) _controller.reverse();
                                      return;
                                    }
                                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    _controller.forward(); // Animate on touch
                                  });
                                },
                              ),
                            ),
                            swapAnimationDuration: const Duration(milliseconds: 250), // Faster animation
                            swapAnimationCurve: Curves.easeInOut,
                          ),
                        ),
                      );
                    },
                  ),
                  if (topItems.isEmpty)
                     Center(
                      child: Text(
                        '데이터가 없습니다',
                        style: TextStyle( // Use AppTheme subtitle color
                          fontSize: 16,
                          color: AppTheme.subtitleColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Use AppTheme divider color
            // Access DividerThemeData from the context's theme
            Divider(color: Theme.of(context).dividerTheme.color ?? AppTheme.secondaryColor.withOpacity(0.3), thickness: 1),
            const SizedBox(height: 8),
            Expanded(
              flex: 2, // Give less space to legend if needed
              child: SingleChildScrollView(
                child: Column(
                  children: topItems.asMap().entries.map((entry) {
                    final isTouched = entry.key == touchedIndex;
                    // Use theme-based colors
                    final itemColor = currentChartColors[entry.key % currentChartColors.length];

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
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0), // Adjust padding
                        decoration: BoxDecoration(
                          // Use AppTheme card color for background on touch
                          color: isTouched ? itemColor.withOpacity(0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isTouched
                              // Use AppTheme primary color for border
                              ? Border.all(color: itemColor.withOpacity(0.8), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isTouched ? 18 : 14, // Adjusted size
                              height: isTouched ? 18 : 14,
                              decoration: BoxDecoration(
                                color: itemColor,
                                // Use circle or rounded square
                                borderRadius: BorderRadius.circular(4), // Softer edges
                                boxShadow: isTouched
                                    ? [
                                        BoxShadow(
                                          color: itemColor.withOpacity(0.5), // Darker shadow
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
                                    style: TextStyle( // Use AppTheme text color
                                      fontSize: 14,
                                      fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                                      color: AppTheme.textColor,
                                    ),
                                    maxLines: 1, // Ensure single line
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_outlined,
                                        size: 14, // Slightly larger icon
                                        // Use AppTheme subtitle color
                                        color: AppTheme.subtitleColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        NumberFormat.compact().format(entry.value.views),
                                        style: TextStyle( // Use AppTheme subtitle color
                                          fontSize: 12,
                                          color: AppTheme.subtitleColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.thumb_up_outlined,
                                        size: 14, // Slightly larger icon
                                        // Use AppTheme subtitle color
                                        color: AppTheme.subtitleColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        NumberFormat.compact().format(entry.value.likes),
                                        style: TextStyle( // Use AppTheme subtitle color
                                          fontSize: 12,
                                          color: AppTheme.subtitleColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Optional: Add percentage text to legend
                             Text(
                              '${(entry.value.views / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isTouched ? itemColor : AppTheme.subtitleColor,
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

  // Updated badge to use theme colors
  Widget _buildBadge(YoutubeData item, Color bgColor) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: touchedIndex != null ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withOpacity(0.9), // Use card color for badge background
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
          border: Border.all(color: bgColor, width: 1), // Use section color for border
        ),
        child: Text(
          item.title.length > 15 ? '${item.title.substring(0, 12)}...' : item.title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor, // Use theme text color
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} 