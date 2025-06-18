import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/video_analysis_result.dart';
import '../app_theme.dart';

class EmotionWeatherWidget extends StatefulWidget {
  final List<VideoAnalysisResult> analysisResults;
  final double height;

  const EmotionWeatherWidget({
    super.key,
    required this.analysisResults,
    this.height = 300.0,
  });

  @override
  State<EmotionWeatherWidget> createState() => _EmotionWeatherWidgetState();
}

class _EmotionWeatherWidgetState extends State<EmotionWeatherWidget>
    with TickerProviderStateMixin {
  late AnimationController _weatherController;
  late AnimationController _particleController;
  late Animation<double> _weatherAnimation;
  late Animation<double> _particleAnimation;
  
  String dominantEmotion = 'neutral';
  double emotionIntensity = 0.0;
  Map<String, double> emotionWeights = {};

  @override
  void initState() {
    super.initState();
    
    _weatherController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _weatherAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _weatherController,
      curve: Curves.easeInOut,
    ));
    
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.linear,
    ));
    
    _processEmotionData();
    _weatherController.repeat(reverse: true);
    _particleController.repeat();
  }

  @override
  void dispose() {
    _weatherController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EmotionWeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.analysisResults != oldWidget.analysisResults) {
      _processEmotionData();
    }
  }

  void _processEmotionData() {
    emotionWeights.clear();
    
    if (widget.analysisResults.isEmpty) {
      dominantEmotion = 'neutral';
      emotionIntensity = 0.0;
      return;
    }

    // Calculate emotion frequencies
    Map<String, int> emotionCounts = {};
    for (var result in widget.analysisResults) {
      final emotion = result.overallEmotion;
      emotionCounts[emotion] = (emotionCounts[emotion] ?? 0) + 1;
    }

    // Find dominant emotion
    if (emotionCounts.isNotEmpty) {
      final totalCount = emotionCounts.values.reduce((a, b) => a + b);
      dominantEmotion = emotionCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      
      // Calculate weights and intensity
      for (var entry in emotionCounts.entries) {
        emotionWeights[entry.key] = entry.value / totalCount;
      }
      
      emotionIntensity = emotionWeights[dominantEmotion] ?? 0.0;
    }
  }

  WeatherData _getWeatherForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy':
      case 'happiness':
        return WeatherData(
          icon: Icons.wb_sunny,
          name: 'Sunny',
          description: 'Bright and cheerful',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.sunRays,
        );
      
      case 'sadness':
        return WeatherData(
          icon: Icons.water_drop,
          name: 'Rainy',
          description: 'Gentle rain',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.raindrops,
        );
      
      case 'anger':
        return WeatherData(
          icon: Icons.flash_on,
          name: 'Stormy',
          description: 'Thunder and lightning',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.lightning,
        );
      
      case 'surprise':
        return WeatherData(
          icon: Icons.stars,
          name: 'Sparkling',
          description: 'Twinkling stars',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.sparkles,
        );
      
      case 'fear':
        return WeatherData(
          icon: Icons.foggy,
          name: 'Foggy',
          description: 'Dense mist',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.mist,
        );
      
      case 'calm':
        return WeatherData(
          icon: Icons.air,
          name: 'Breezy',
          description: 'Gentle breeze',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.leaves,
        );
      
      case 'excitement':
        return WeatherData(
          icon: Icons.local_fire_department,
          name: 'Fiery',
          description: 'Burning bright',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.flames,
        );
      
      case 'disgust':
        return WeatherData(
          icon: Icons.cloud,
          name: 'Overcast',
          description: 'Heavy clouds',
          backgroundGradient: AppTheme.getEmotionGradient(emotion),
          particleType: WeatherParticleType.dust,
        );
      
      case 'neutral':
      default:
        return WeatherData(
          icon: Icons.wb_cloudy,
          name: 'Partly Cloudy',
          description: 'Mild and balanced',
          backgroundGradient: AppTheme.getEmotionGradient('neutral'),
          particleType: WeatherParticleType.clouds,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _getWeatherForEmotion(dominantEmotion);
    
    return Container(
      height: widget.height,
      child: Column(
        children: [
          Text(
            'Emotional Weather',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Background gradient
                  AnimatedBuilder(
                    animation: _weatherAnimation,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: weather.backgroundGradient.map((color) {
                              return color.withOpacity(0.3 + emotionIntensity * 0.7);
                            }).toList(),
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Weather particles
                  AnimatedBuilder(
                    animation: _particleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: WeatherParticlePainter(
                          particleType: weather.particleType,
                          animationProgress: _particleAnimation.value,
                          intensity: emotionIntensity,
                          color: AppTheme.getEmotionColor(dominantEmotion, emotionIntensity),
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),
                  
                  // Main weather display
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _weatherAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_weatherAnimation.value * 0.1),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.getEmotionColor(dominantEmotion, emotionIntensity)
                                          .withOpacity(0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  weather.icon,
                                  size: 64,
                                  color: AppTheme.getEmotionColor(dominantEmotion, emotionIntensity),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          weather.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          weather.description,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(emotionIntensity * 100).toInt()}% intensity',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildEmotionBreakdown(),
        ],
      ),
    );
  }

  Widget _buildEmotionBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.getEmotionColor(dominantEmotion, emotionIntensity).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emotion Breakdown',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: emotionWeights.entries.map((entry) {
              final emotion = entry.key;
              final weight = entry.value;
              final color = AppTheme.getEmotionColor(emotion, weight);
              final weather = _getWeatherForEmotion(emotion);
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(weather.icon, color: color, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      emotion.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(weight * 100).toInt()}%',
                      style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class WeatherData {
  final IconData icon;
  final String name;
  final String description;
  final List<Color> backgroundGradient;
  final WeatherParticleType particleType;

  WeatherData({
    required this.icon,
    required this.name,
    required this.description,
    required this.backgroundGradient,
    required this.particleType,
  });
}

enum WeatherParticleType {
  sunRays,
  raindrops,
  lightning,
  sparkles,
  mist,
  leaves,
  flames,
  dust,
  clouds,
}

class WeatherParticlePainter extends CustomPainter {
  final WeatherParticleType particleType;
  final double animationProgress;
  final double intensity;
  final Color color;

  WeatherParticlePainter({
    required this.particleType,
    required this.animationProgress,
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (particleType) {
      case WeatherParticleType.raindrops:
        _drawRaindrops(canvas, size);
        break;
      case WeatherParticleType.sunRays:
        _drawSunRays(canvas, size);
        break;
      case WeatherParticleType.sparkles:
        _drawSparkles(canvas, size);
        break;
      case WeatherParticleType.lightning:
        _drawLightning(canvas, size);
        break;
      case WeatherParticleType.mist:
        _drawMist(canvas, size);
        break;
      case WeatherParticleType.leaves:
        _drawLeaves(canvas, size);
        break;
      case WeatherParticleType.flames:
        _drawFlames(canvas, size);
        break;
      case WeatherParticleType.dust:
        _drawDust(canvas, size);
        break;
      case WeatherParticleType.clouds:
        _drawClouds(canvas, size);
        break;
    }
  }

  void _drawRaindrops(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final random = math.Random(42); // Fixed seed for consistent animation
    final dropCount = (intensity * 50).toInt();

    for (int i = 0; i < dropCount; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final y = (baseY + animationProgress * size.height * 2) % (size.height + 20);
      
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 10),
        paint,
      );
    }
  }

  void _drawSunRays(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final rayCount = 8;
    final rayLength = size.width * 0.3 * intensity;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * math.pi / rayCount) + (animationProgress * math.pi / 4);
      final start = center + Offset(
        math.cos(angle) * rayLength * 0.7,
        math.sin(angle) * rayLength * 0.7,
      );
      final end = center + Offset(
        math.cos(angle) * rayLength,
        math.sin(angle) * rayLength,
      );
      
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final random = math.Random(42);
    final sparkleCount = (intensity * 30).toInt();

    for (int i = 0; i < sparkleCount; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final size1 = 3 + random.nextDouble() * 5;
      final twinkle = math.sin(animationProgress * 2 * math.pi + i) * 0.5 + 0.5;
      
      canvas.drawCircle(
        Offset(x, y),
        size1 * twinkle,
        paint..color = color.withOpacity(0.8 * twinkle),
      );
    }
  }

  void _drawLightning(Canvas canvas, Size size) {
    if (animationProgress > 0.9 || animationProgress < 0.1) {
      final paint = Paint()
        ..color = color.withOpacity(0.9)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(size.width * 0.4, 0);
      path.lineTo(size.width * 0.5, size.height * 0.3);
      path.lineTo(size.width * 0.3, size.height * 0.5);
      path.lineTo(size.width * 0.6, size.height * 0.7);
      path.lineTo(size.width * 0.4, size.height);

      canvas.drawPath(path, paint);
    }
  }

  void _drawMist(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (int i = 0; i < 5; i++) {
      final y = size.height * (0.2 + i * 0.15);
      final width = size.width * (0.8 + math.sin(animationProgress * 2 * math.pi + i) * 0.2);
      
      canvas.drawOval(
        Rect.fromLTWH(
          (size.width - width) / 2,
          y,
          width,
          20,
        ),
        paint,
      );
    }
  }

  void _drawLeaves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final leafCount = (intensity * 15).toInt();

    for (int i = 0; i < leafCount; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final x = baseX + math.sin(animationProgress * 2 * math.pi + i) * 20;
      final y = (baseY + animationProgress * size.height * 0.5) % size.height;
      
      final leafPath = Path();
      leafPath.addOval(Rect.fromCenter(center: Offset(x, y), width: 6, height: 10));
      canvas.drawPath(leafPath, paint);
    }
  }

  void _drawFlames(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final random = math.Random(42);
    final flameCount = (intensity * 20).toInt();

    for (int i = 0; i < flameCount; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = size.height - random.nextDouble() * 100;
      final flicker = math.sin(animationProgress * 8 * math.pi + i * 2) * 10;
      final y = baseY + flicker;
      
      final flamePath = Path();
      flamePath.moveTo(x, y + 20);
      flamePath.quadraticBezierTo(x - 5, y + 10, x, y);
      flamePath.quadraticBezierTo(x + 5, y + 10, x, y + 20);
      canvas.drawPath(flamePath, paint);
    }
  }

  void _drawDust(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final dustCount = (intensity * 40).toInt();

    for (int i = 0; i < dustCount; i++) {
      final x = (random.nextDouble() * size.width + animationProgress * 50) % size.width;
      final y = random.nextDouble() * size.height;
      final particleSize = 1 + random.nextDouble() * 2;
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final cloudY = size.height * 0.2;
    final cloudWidth = size.width * 0.6;
    final cloudOffset = math.sin(animationProgress * 2 * math.pi) * 20;
    
    final cloudPath = Path();
    cloudPath.addOval(Rect.fromLTWH(
      size.width * 0.2 + cloudOffset,
      cloudY,
      cloudWidth,
      40,
    ));
    
    canvas.drawPath(cloudPath, paint);
  }

  @override
  bool shouldRepaint(covariant WeatherParticlePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
           oldDelegate.intensity != intensity;
  }
} 