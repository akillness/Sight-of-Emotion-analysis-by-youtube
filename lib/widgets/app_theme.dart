import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 앱 테마 설정을 관리하는 클래스
class AppTheme {
  // 넷플릭스 색상 팔레트
  static const Color primaryColor = Color(0xFFE50914); // 넷플릭스 빨간색
  static const Color secondaryColor = Color(0xFF564D4D); // 보조 색상
  static const Color backgroundColor = Color(0xFF121212); // 어두운 배경
  static const Color cardColor = Color(0xFF1A1A1A); // 카드 배경
  static const Color textColor = Color(0xFFE5E5E5); // 텍스트 색상
  static const Color subtitleColor = Color(0xFF8C8C8C); // 부제목 색상
  static const Color accentColor = Color(0xFFFFFFFF); // 강조 색상 (흰색)

  // === 감정 시각화를 위한 색상 심리학 기반 팔레트 ===
  
  /// 감정별 색상 스킴 클래스
  static const Map<String, EmotionColorScheme> emotionColors = {
    'joy': EmotionColorScheme(
      primary: Color(0xFFFFD700),    // 골드 (기쁨, 활력, 밝음)
      secondary: Color(0xFFFFA500),  // 오렌지 (따뜻함, 에너지)
      accent: Color(0xFFFFFF8C),     // 연한 노랑 (밝음, 희망)
      gradient: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFFF8C)],
    ),
    'happiness': EmotionColorScheme(
      primary: Color(0xFFFFD700),    // joy와 동일
      secondary: Color(0xFFFFA500),
      accent: Color(0xFFFFFF8C),
      gradient: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFFFF8C)],
    ),
    'sadness': EmotionColorScheme(
      primary: Color(0xFF4A90E2),    // 파랑 (차분, 슬픔, 안정)
      secondary: Color(0xFF7BB3F0),  // 연한 파랑 (우울함)
      accent: Color(0xFF2E5C8A),     // 진한 파랑 (깊은 슬픔)
      gradient: [Color(0xFF2E5C8A), Color(0xFF4A90E2), Color(0xFF7BB3F0)],
    ),
    'anger': EmotionColorScheme(
      primary: Color(0xFFE74C3C),    // 빨강 (분노, 강렬함, 위험)
      secondary: Color(0xFFFF6B6B),  // 연한 빨강 (짜증)
      accent: Color(0xFFC0392B),     // 진한 빨강 (격노)
      gradient: [Color(0xFFC0392B), Color(0xFFE74C3C), Color(0xFFFF6B6B)],
    ),
    'surprise': EmotionColorScheme(
      primary: Color(0xFF9B59B6),    // 보라 (놀라움, 신비, 예상치 못함)
      secondary: Color(0xFFBF85C9),  // 연한 보라
      accent: Color(0xFF7D3C98),     // 진한 보라
      gradient: [Color(0xFF7D3C98), Color(0xFF9B59B6), Color(0xFFBF85C9)],
    ),
    'fear': EmotionColorScheme(
      primary: Color(0xFF6C3483),    // 진한 보라 (두려움, 불안)
      secondary: Color(0xFF884EA0),  // 중간 보라
      accent: Color(0xFF512E5F),     // 매우 진한 보라 (공포)
      gradient: [Color(0xFF512E5F), Color(0xFF6C3483), Color(0xFF884EA0)],
    ),
    'disgust': EmotionColorScheme(
      primary: Color(0xFF8B4513),    // 갈색 (혐오, 거부감)
      secondary: Color(0xFFA0522D),  // 연한 갈색
      accent: Color(0xFF654321),     // 진한 갈색
      gradient: [Color(0xFF654321), Color(0xFF8B4513), Color(0xFFA0522D)],
    ),
    'neutral': EmotionColorScheme(
      primary: Color(0xFF95A5A6),    // 회색 (중립, 평온)
      secondary: Color(0xFFBDC3C7),  // 연한 회색
      accent: Color(0xFF7F8C8D),     // 진한 회색
      gradient: [Color(0xFF7F8C8D), Color(0xFF95A5A6), Color(0xFFBDC3C7)],
    ),
    'love': EmotionColorScheme(
      primary: Color(0xFFFF69B4),    // 핑크 (사랑, 애정)
      secondary: Color(0xFFFFB6C1),  // 연한 핑크
      accent: Color(0xFFFF1493),     // 진한 핑크
      gradient: [Color(0xFFFF1493), Color(0xFFFF69B4), Color(0xFFFFB6C1)],
    ),
    'excitement': EmotionColorScheme(
      primary: Color(0xFFFF4500),    // 주황-빨강 (흥분, 열정)
      secondary: Color(0xFFFF6347),  // 토마토색
      accent: Color(0xFFFF2500),     // 진한 주황-빨강
      gradient: [Color(0xFFFF2500), Color(0xFFFF4500), Color(0xFFFF6347)],
    ),
    'calm': EmotionColorScheme(
      primary: Color(0xFF20B2AA),    // 라이트 시그린 (평온, 안정)
      secondary: Color(0xFF48CAE4),  // 하늘색
      accent: Color(0xFF0FA3B1),     // 진한 시그린
      gradient: [Color(0xFF0FA3B1), Color(0xFF20B2AA), Color(0xFF48CAE4)],
    ),
  };
  
  /// 감정 강도에 따른 동적 색상 생성
  static Color getEmotionColor(String emotion, double intensity) {
    final scheme = emotionColors[emotion.toLowerCase()] ?? emotionColors['neutral']!;
    final baseColor = scheme.primary;
    
    // HSL 색상 모델을 사용하여 강도에 따른 채도와 밝기 조절
    final hsl = HSLColor.fromColor(baseColor);
    
    return hsl.withLightness(
      (0.3 + intensity * 0.4).clamp(0.0, 1.0) // 강도에 따른 밝기 조절
    ).withSaturation(
      (0.6 + intensity * 0.4).clamp(0.0, 1.0) // 강도에 따른 채도 조절
    ).toColor();
  }
  
  /// 감정에 따른 그라데이션 색상 리스트 반환
  static List<Color> getEmotionGradient(String emotion) {
    final scheme = emotionColors[emotion.toLowerCase()] ?? emotionColors['neutral']!;
    return scheme.gradient;
  }
  
  /// 감정별 기본 색상 반환
  static Color getBasicEmotionColor(String emotion) {
    final scheme = emotionColors[emotion.toLowerCase()] ?? emotionColors['neutral']!;
    return scheme.primary;
  }
  
  /// 접근성을 고려한 색상 대비 확인
  static bool hasGoodContrast(Color color1, Color color2) {
    final luminance1 = color1.computeLuminance();
    final luminance2 = color2.computeLuminance();
    final contrast = (luminance1 > luminance2) 
        ? (luminance1 + 0.05) / (luminance2 + 0.05)
        : (luminance2 + 0.05) / (luminance1 + 0.05);
    return contrast >= 4.5; // WCAG AA 기준
  }
  
  /// 감정별 아이콘 반환
  static IconData getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'joy':
      case 'happiness':
        return Icons.sentiment_very_satisfied;
      case 'sadness':
        return Icons.sentiment_very_dissatisfied;
      case 'anger':
        return Icons.mood_bad;
      case 'surprise':
        return Icons.sentiment_neutral;
      case 'fear':
        return Icons.sentiment_dissatisfied;
      case 'disgust':
        return Icons.thumb_down;
      case 'love':
        return Icons.favorite;
      case 'excitement':
        return Icons.celebration;
      case 'calm':
        return Icons.self_improvement;
      case 'neutral':
      default:
        return Icons.sentiment_neutral;
    }
  }

  // 넷플릭스 스타일 타이포그래피
  static final TextTheme textTheme = TextTheme(
    displayLarge: GoogleFonts.roboto(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    displayMedium: GoogleFonts.roboto(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    displaySmall: GoogleFonts.roboto(
      fontSize: 20, 
      fontWeight: FontWeight.w700,
      color: textColor,
    ),
    headlineMedium: GoogleFonts.roboto(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    titleLarge: GoogleFonts.roboto(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: textColor,
    ),
    bodyLarge: GoogleFonts.roboto(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    bodyMedium: GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textColor,
    ),
    bodySmall: GoogleFonts.roboto(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textColor.withOpacity(0.8),
    ),
  );

  // 넷플릭스 테마 스타일
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textColor,
      elevation: 0,
      titleTextStyle: textTheme.headlineMedium,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}

/// 감정별 색상 스킴을 정의하는 클래스
class EmotionColorScheme {
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradient;
  
  const EmotionColorScheme({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
  });
} 