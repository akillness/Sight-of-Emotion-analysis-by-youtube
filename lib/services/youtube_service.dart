import '../models/video_info.dart';

class YoutubeService {
  // Simulates fetching game-related videos, sorted by view count
  Future<List<VideoInfo>> fetchGamingVideos() async {
    // In a real app, this would make an API call
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network delay

    // Mock data
    return [
      VideoInfo(id: '1', title: '새로운 게임장르 등장, 펍지는 과연 게임 체인저인가?', viewCount: 1500000),
      VideoInfo(id: '2', title: '역대급 그래픽! 기대 신작 MMORPG 플레이 후기', viewCount: 1200000),
      VideoInfo(id: '3', title: '인디 게임의 반란? 스팀 인기 게임 분석', viewCount: 950000),
      VideoInfo(id: '4', title: '모바일 게임 시장의 미래는? 전문가 토론', viewCount: 800000),
      VideoInfo(id: '5', title: 'E-Sports 결승! T1 vs GenG 하이라이트', viewCount: 1800000),
      VideoInfo(id: '6', title: '고전 게임 리뷰: 추억의 오락실 게임 TOP 5', viewCount: 600000),
    ]..sort((a, b) => b.viewCount.compareTo(a.viewCount)); // Sort descending by view count
  }
} 