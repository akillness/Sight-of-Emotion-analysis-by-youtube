import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/youtube_data.dart';
import '../models/api_response.dart';
import 'database_helper.dart';

class ApiService {
  static const String _apiKey = 'AIzaSyBPVLtWE91xmwYkmA7JSANSngXyo084APE';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  Future<ApiResponse> getTrends() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/videos?part=snippet,statistics&chart=mostPopular&regionCode=KR&maxResults=50&key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data['items'] as List)
            .map((item) => YoutubeData.fromVideoItem(item))
            .toList();
            
        // 데이터베이스에 저장
        for (final item in items) {
          await _dbHelper.insertTrend(item);
        }
            
        return ApiResponse(
          items: items,
          total: items.length,
          currentPage: 1,
          totalPages: 1
        );
      } else {
        print('Error fetching trends: ${response.statusCode}');
        return _emptyResponse();
      }
    } catch (e) {
      print('Error fetching trends: $e');
      return _emptyResponse();
    }
  }
  
  Future<ApiResponse> collectTrends() async {
    return getTrends();
  }
  
  /// 유튜브 검색 API를 사용하여 지정된 쿼리로 동영상을 검색하고 결과를 반환합니다.
  Future<ApiResponse> searchTrends(String query) async {
    return _fetchVideosBySearch(query);
  }
  
  Future<Map<String, dynamic>> getKeywordAnalysis() async {
    return await _dbHelper.getKeywordTrends();
  }
  
  Future<List<Map<String, dynamic>>> getTopTrends({int limit = 10}) async {
    return await _dbHelper.getTopTrends(limit: limit);
  }

  /// 키워드로 트렌드를 검색합니다.
  Future<ApiResponse> getTrendsByKeyword(String keyword) async {
    return _fetchVideosBySearch(keyword);
  }

  /// 검색 쿼리를 사용하여 비디오를 검색하고 세부 정보를 가져오는 내부 메서드
  Future<ApiResponse> _fetchVideosBySearch(String query) async {
    try {
      final searchResponse = await http.get(
        Uri.parse('$_baseUrl/search?part=snippet&q=$query&type=video&regionCode=KR&maxResults=50&key=$_apiKey'),
      );

      if (searchResponse.statusCode != 200) {
        print('Error searching trends: ${searchResponse.statusCode}');
        return _emptyResponse();
      }

      final searchData = json.decode(searchResponse.body);
      final videoIds = (searchData['items'] as List)
          .map((item) => item['id']['videoId'])
          .join(',');

      if (videoIds.isEmpty) {
        return _emptyResponse();
      }

      final videosResponse = await http.get(
        Uri.parse('$_baseUrl/videos?part=snippet,statistics&id=$videoIds&key=$_apiKey'),
      );

      if (videosResponse.statusCode == 200) {
        final videosData = json.decode(videosResponse.body);
        final items = (videosData['items'] as List)
            .map((item) => YoutubeData.fromVideoItem(item))
            .toList();
            
        // 데이터베이스에 저장
        for (final item in items) {
          await _dbHelper.insertTrend(item);
        }
            
        return ApiResponse(
          items: items,
          total: items.length,
          currentPage: 1,
          totalPages: 1
        );
      } else {
        print('Error fetching video details: ${videosResponse.statusCode}');
        return _emptyResponse();
      }
    } catch (e) {
      print('Error searching trends: $e');
      return _emptyResponse();
    }
  }

  /// 빈 응답 생성 헬퍼 메서드
  ApiResponse _emptyResponse() {
    return ApiResponse(
      items: [],
      total: 0,
      currentPage: 1,
      totalPages: 1
    );
  }
} 