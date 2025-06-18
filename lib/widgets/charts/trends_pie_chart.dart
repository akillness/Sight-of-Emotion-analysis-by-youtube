import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:fl_chart/fl_chart.dart';
import '../../models/video_analysis_result.dart';
import '../app_theme.dart';

class TrendsPieChart extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;
  final String? selectedEmotionFilter;

  const TrendsPieChart({
    super.key, 
    required this.analysisResults,
    this.selectedEmotionFilter,
  });

  @override
  State<TrendsPieChart> createState() => _TrendsPieChartState();
}

class _TrendsPieChartState extends State<TrendsPieChart> 
    with TickerProviderStateMixin {
  int touchedIndex = -1;
  Map<String, double> emotionData = {};
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticInOut,
    ));
    
    _processData();
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(TrendsPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults ||
        widget.selectedEmotionFilter != oldWidget.selectedEmotionFilter) {
      _processData();
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _processData() {
    emotionData.clear();
    
    if (widget.analysisResults.isEmpty) return;
    
    for (var result in widget.analysisResults) {
      final emotion = result.overallEmotion;
      final confidence = 1.0; // Default confidence since not available in model
      
      // Apply emotion filter if specified
      if (widget.selectedEmotionFilter != null && 
          widget.selectedEmotionFilter != 'all' &&
          emotion != widget.selectedEmotionFilter) {
        continue;
      }
      
      emotionData[emotion] = (emotionData[emotion] ?? 0.0) + confidence;
    }
    
    // Normalize to percentages
    final total = emotionData.values.fold(0.0, (sum, value) => sum + value);
    if (total > 0) {
      emotionData.updateAll((key, value) => (value / total) * 100);
    }
  }

  void _onSectionTouched(int index) {
    setState(() {
      touchedIndex = index;
    });
    
    // Haptic feedback for emotion intensity
    if (index >= 0 && index < emotionData.length) {
      final emotion = emotionData.keys.elementAt(index);
      final intensity = emotionData[emotion]! / 100.0;
      
      // Provide different haptic feedback based on emotion intensity
      if (intensity > 0.7) {
        HapticFeedback.heavyImpact();
      } else if (intensity > 0.4) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      
      // Trigger pulse animation for touched section
      _pulseController.reset();
      _pulseController.forward();
    }
  }

  List<PieChartSectionData> _generateSections() {
    final sections = <PieChartSectionData>[];
    final emotions = emotionData.keys.toList();
    
    for (int i = 0; i < emotions.length; i++) {
      final emotion = emotions[i];
      final value = emotionData[emotion]!;
      final isTouched = i == touchedIndex;
      
      // Get emotion-based color with intensity
      final intensity = value / 100.0;
      final emotionColor = AppTheme.getEmotionColor(emotion, intensity);
      final gradientColors = AppTheme.getEmotionGradient(emotion);
      final accentColor = gradientColors.isNotEmpty ? gradientColors.last : emotionColor;
      
      sections.add(
        PieChartSectionData(
          color: isTouched ? accentColor : emotionColor,
          value: value,
          title: isTouched ? '${value.toStringAsFixed(1)}%' : '',
          radius: isTouched ? 65.0 : 55.0,
          titleStyle: TextStyle(
            fontSize: isTouched ? 16.0 : 14.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.7),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          badgeWidget: isTouched ? _buildEmotionBadge(emotion, intensity) : null,
          badgePositionPercentageOffset: 1.3,
        ),
      );
    }
    
    return sections;
  }

  Widget _buildEmotionBadge(String emotion, double intensity) {
    final icon = AppTheme.getEmotionIcon(emotion);
    final color = AppTheme.getEmotionColor(emotion, intensity);
    
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: emotionData.entries.map((entry) {
        final emotion = entry.key;
        final value = entry.value;
        final intensity = value / 100.0;
        final color = AppTheme.getEmotionColor(emotion, intensity);
        final icon = AppTheme.getEmotionIcon(emotion);
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                emotion.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (emotionData.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_neutral,
              size: 48,
              color: AppTheme.getBasicEmotionColor('neutral').withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No emotion data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getBasicEmotionColor('neutral').withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Emotion Distribution',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _onSectionTouched(-1);
                        return;
                      }
                      _onSectionTouched(
                        pieTouchResponse.touchedSection!.touchedSectionIndex,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 45,
                  sections: _generateSections(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildLegend(),
          ],
        ),
      ),
    );
  }
} 