import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/video_analysis_result.dart';
import '../app_theme.dart';

class EmotionWaveWidget extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;
  final double height;
  final Color? waveColor;
  final Duration animationDuration;

  const EmotionWaveWidget({
    super.key,
    required this.analysisResults,
    this.height = 200.0,
    this.waveColor,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<EmotionWaveWidget> createState() => _EmotionWaveWidgetState();
}

class _EmotionWaveWidgetState extends State<EmotionWaveWidget>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _intensityController;
  late Animation<double> _waveAnimation;
  late Animation<double> _intensityAnimation;
  
  Map<String, double> emotionIntensities = {};
  List<EmotionWaveData> waveData = [];

  @override
  void initState() {
    super.initState();
    
    _waveController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _intensityController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _waveController,
      curve: Curves.linear,
    ));
    
    _intensityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _intensityController,
      curve: Curves.easeInOut,
    ));
    
    _processEmotionData();
    _waveController.repeat();
    _intensityController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _intensityController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EmotionWaveWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults) {
      _processEmotionData();
      _intensityController.reset();
      _intensityController.forward();
    }
  }

  void _processEmotionData() {
    emotionIntensities.clear();
    waveData.clear();

    if (widget.analysisResults.isEmpty) return;

    // Calculate emotion frequencies and intensities
    Map<String, int> emotionCounts = {};
    for (var result in widget.analysisResults) {
      final emotion = result.overallEmotion;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }

    // Convert to intensities (normalized)
    final maxCount = emotionCounts.values.isNotEmpty 
        ? emotionCounts.values.reduce(math.max) 
        : 1;
    
    for (var entry in emotionCounts.entries) {
      final intensity = entry.value / maxCount;
      emotionIntensities[entry.key] = intensity;
      
      waveData.add(EmotionWaveData(
        emotion: entry.key,
        intensity: intensity,
        frequency: _getEmotionFrequency(entry.key),
        amplitude: _getEmotionAmplitude(intensity),
        phase: _getEmotionPhase(entry.key),
      ));
    }

    // Sort by intensity for layering
    waveData.sort((a, b) => a.intensity.compareTo(b.intensity));
  }

  double _getEmotionFrequency(String emotion) {
    // Different emotions have different wave frequencies
    switch (emotion.toLowerCase()) {
      case 'excitement':
      case 'anger':
        return 2.5; // High frequency for intense emotions
      case 'joy':
      case 'happiness':
        return 2.0; // Medium-high frequency
      case 'surprise':
        return 1.8;
      case 'neutral':
        return 1.0; // Steady frequency
      case 'calm':
        return 0.8; // Low frequency for calm emotions
      case 'sadness':
        return 0.6; // Lower frequency
      case 'fear':
      case 'disgust':
        return 1.2; // Irregular frequency
      default:
        return 1.0;
    }
  }

  double _getEmotionAmplitude(double intensity) {
    return 20.0 + (intensity * 30.0); // Scale amplitude based on intensity
  }

  double _getEmotionPhase(String emotion) {
    // Different phase offsets for emotion layering
    return emotion.hashCode % 628 / 100.0; // Convert to radians
  }

  @override
  Widget build(BuildContext context) {
    if (waveData.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.waves,
              size: 48,
              color: AppTheme.getBasicEmotionColor('neutral').withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No emotion waves to display',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.getBasicEmotionColor('neutral').withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Emotion Flow Waves',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_waveAnimation, _intensityAnimation]),
              builder: (context, child) {
                return CustomPaint(
                  painter: EmotionWavePainter(
                    waveData: waveData,
                    wavePhase: _waveAnimation.value,
                    intensityProgress: _intensityAnimation.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _buildEmotionLegend(),
        ],
      ),
    );
  }

  Widget _buildEmotionLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: waveData.map((data) {
        final color = AppTheme.getEmotionColor(data.emotion, data.intensity);
        final icon = AppTheme.getEmotionIcon(data.emotion);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                data.emotion.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class EmotionWaveData {
  final String emotion;
  final double intensity;
  final double frequency;
  final double amplitude;
  final double phase;

  EmotionWaveData({
    required this.emotion,
    required this.intensity,
    required this.frequency,
    required this.amplitude,
    required this.phase,
  });
}

class EmotionWavePainter extends CustomPainter {
  final List<EmotionWaveData> waveData;
  final double wavePhase;
  final double intensityProgress;

  EmotionWavePainter({
    required this.waveData,
    required this.wavePhase,
    required this.intensityProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    
    for (int i = 0; i < waveData.length; i++) {
      final data = waveData[i];
      final color = AppTheme.getEmotionColor(data.emotion, data.intensity);
      
      _drawWave(
        canvas,
        size,
        data,
        color,
        centerY,
        intensityProgress,
      );
    }
  }

  void _drawWave(
    Canvas canvas,
    Size size,
    EmotionWaveData data,
    Color color,
    double centerY,
    double progress,
  ) {
    final paint = Paint()
      ..color = color.withOpacity(0.6 * progress)
      ..strokeWidth = 2.0 + (data.intensity * 2.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1 * progress)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    // Start from the left edge
    double startY = centerY + data.amplitude * progress * 
        math.sin(data.phase + wavePhase * data.frequency);
    
    path.moveTo(0, startY);
    fillPath.moveTo(0, centerY);
    fillPath.lineTo(0, startY);

    // Generate wave points
    for (double x = 0; x <= size.width; x += 2) {
      final normalizedX = x / size.width;
      final waveValue = data.amplitude * progress * 
          math.sin(data.phase + (wavePhase + normalizedX * 4 * math.pi) * data.frequency);
      final y = centerY + waveValue;
      
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Close fill path
    fillPath.lineTo(size.width, centerY);
    fillPath.close();

    // Draw fill first, then stroke
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Add glow effect for high intensity emotions
    if (data.intensity > 0.7) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3 * progress)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant EmotionWavePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
           oldDelegate.intensityProgress != intensityProgress ||
           oldDelegate.waveData.length != waveData.length;
  }
} 