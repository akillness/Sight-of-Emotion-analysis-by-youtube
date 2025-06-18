import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/youtube_data.dart';
import '../models/api_response.dart';
// import 'database_helper.dart'; // 데이터베이스 직접 호출 제거
import 'package:flutter/foundation.dart';
import '../config/api_keys.dart';

class ApiService {
  static const String _youtubeApiBaseUrl = 'https://www.googleapis.com/youtube/v3';
  static const String _regionCode = 'KR';
  static const int _maxResults = 20;
  // final DatabaseHelper _dbHelper = DatabaseHelper.instance; // 데이터베이스 직접 호출 제거
  
  Future<ApiResponse> getTrends() async {
    try {
      final response = await http.get(
        Uri.parse('$_youtubeApiBaseUrl/videos?part=snippet,statistics&chart=mostPopular&regionCode=$_regionCode&maxResults=$_maxResults&key=$youtubeApiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data['items'] as List)
            .map((item) => YoutubeData.fromVideoItem(item))
            .toList();
            
        // Extract keywords asynchronously
        for (final item in items) {
          await item.extractKeywordsFromTitle();
        }
            
        // 데이터베이스에 저장 로직 제거
        // for (final item in items) {
        //   await _dbHelper.insertTrend(item);
        // }
            
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
    print('ApiService: Fetching keyword analysis from database...');
    // final analysisData = await _dbHelper.getKeywordTrends(); // 데이터베이스 직접 호출 제거
    // print('ApiService: Keyword analysis data received: $analysisData');
    // return analysisData;
    return {}; // 임시로 빈 맵 반환
  }
  
  Future<List<Map<String, dynamic>>> getTopTrends({int limit = 10}) async {
    // return await _dbHelper.getTopTrends(limit: limit); // 데이터베이스 직접 호출 제거
    return []; // 임시로 빈 리스트 반환
  }

  /// 키워드로 트렌드를 검색합니다.
  Future<ApiResponse> getTrendsByKeyword(String keyword) async {
    return _fetchVideosBySearch(keyword);
  }

  /// 검색 쿼리를 사용하여 비디오를 검색하고 세부 정보를 가져오는 내부 메서드
  Future<ApiResponse> _fetchVideosBySearch(String query) async {
    if (kDebugMode) {
      print('ApiService: _fetchVideosBySearch started with query: "$query", maxResults: $_maxResults');
    }
    final searchUrl = Uri.parse(
      '$_youtubeApiBaseUrl/search?part=snippet&q=$query&type=video&regionCode=$_regionCode&maxResults=$_maxResults&key=$youtubeApiKey'
    );

    if (kDebugMode) {
      print('ApiService: Calling YouTube Search API: $searchUrl');
    }

    try {
      final searchResponse = await http.get(searchUrl);
      if (kDebugMode) {
          print('ApiService: YouTube Search API status: ${searchResponse.statusCode}');
      }

      if (searchResponse.statusCode == 200) {
        final searchData = json.decode(searchResponse.body);
        final List<dynamic> searchItems = searchData['items'] ?? [];
        
        final videoIds = searchItems
            .map((item) => item['id']?['videoId'] as String?)
            .where((id) => id != null)
            .cast<String>()
            .toList();

        if (kDebugMode) {
            print('ApiService: Found ${videoIds.length} video IDs: ${videoIds.join(',')}');
        }

        if (videoIds.isEmpty) {
          if (kDebugMode) {
              print('ApiService: No video IDs found for query "$query".');
          }
          return _emptyResponse();
        }

        final videosUrl = Uri.parse(
          '$_youtubeApiBaseUrl/videos?part=snippet,statistics&id=${videoIds.join(',')}&key=$youtubeApiKey'
        );
        if (kDebugMode) {
            print('ApiService: Calling YouTube Videos API: $videosUrl');
        }
        final videosResponse = await http.get(videosUrl);
         if (kDebugMode) {
            print('ApiService: YouTube Videos API status: ${videosResponse.statusCode}');
         }

        if (videosResponse.statusCode == 200) {
          final videosData = json.decode(videosResponse.body);
          final List<dynamic> videoItems = videosData['items'] ?? [];
           if (kDebugMode) {
              print('ApiService: Processing ${videoItems.length} video items.');
           }
          final items = videoItems.map((item) => YoutubeData.fromVideoItem(item)).toList();
            
          // Extract keywords asynchronously
          for (final item in items) {
            await item.extractKeywordsFromTitle();
          }
            
          // 데이터베이스에 저장
          // print('ApiService: Saving ${items.length} items to database.');
          // for (final item in items) {
          //   await _dbHelper.insertTrend(item);
          // }
          // print('ApiService: Finished saving items.');
            
          return ApiResponse(
            items: items,
            total: items.length,
            currentPage: 1,
            totalPages: 1
          );
        } else {
          if (kDebugMode) {
              print('ApiService: Failed to fetch video details. Status: ${videosResponse.statusCode}, Body: ${videosResponse.body}');
          }
          throw Exception('Failed to fetch video details');
        }
      } else {
        if (kDebugMode) {
            print('ApiService: Failed to search videos. Status: ${searchResponse.statusCode}, Body: ${searchResponse.body}');
        }
        throw Exception('Failed to search videos');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ApiService: Error during YouTube API call: $e');
      }
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

  Future<void> saveVideosToDatabase(List<YoutubeData> videos) async {
    if (kIsWeb) {
      print('ApiService: Saving ${videos.length} items to database.');
    }
    // for (final video in videos) {
    //   await _dbHelper.insertTrend(video);
    // }
    if (kIsWeb) {
      print('ApiService: Finished saving items.');
    }
  }

  /// 비디오에 대한 댓글을 가져옵니다.
  Future<List<String>> getComments(String videoId) async {
    final url = Uri.parse(
        '$_youtubeApiBaseUrl/commentThreads?part=snippet&videoId=$videoId&maxResults=100&key=$youtubeApiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?;
        if (items == null) return [];
        return items.map((item) {
          final snippet = item['snippet']['topLevelComment']['snippet'];
          return snippet['textDisplay'] as String;
        }).toList();
      } else {
        if (kDebugMode) {
          print(
              'Failed to fetch comments for video $videoId: ${response.statusCode}');
        }
        return [];
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Error fetching comments for video $videoId: $e');
      }
      return [];
    }
  }

  /// 비디오에 대한 캡션(자막)을 가져옵니다.
  Future<String> getCaptions(String videoId) async {
    // 1. 사용 가능한 캡션 목록 가져오기
    final listUrl = Uri.parse(
        '$_youtubeApiBaseUrl/captions?part=snippet&videoId=$videoId&key=$youtubeApiKey');
    try {
      final listResponse = await http.get(listUrl);
      if (listResponse.statusCode != 200) {
        return ''; // 캡션 목록을 가져올 수 없음
      }

      final listData = json.decode(listResponse.body);
      final items = listData['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        return ''; // 사용 가능한 캡션 없음
      }

      // 2. 한국어 또는 영어 캡션 ID 찾기
      String? captionId;
      for (var item in items) {
        final language = item['snippet']['language'] as String;
        if (language == 'ko' || language == 'en') {
          captionId = item['id'] as String;
          if (language == 'ko') break; // 한국어 우선
        }
      }

      if (captionId == null) {
        return ''; // 원하는 언어의 캡션 없음
      }

      // 3. 캡션 다운로드
      final downloadUrl = Uri.parse(
          '$_youtubeApiBaseUrl/captions/$captionId?key=$youtubeApiKey');
      final downloadResponse = await http.get(downloadUrl);

      if (downloadResponse.statusCode == 200) {
        // 간단한 SRT/VTT 태그 제거
        return downloadResponse.body
            .replaceAll(RegExp(r'<[^>]*>'), '') // HTML 태그 제거
            .replaceAll(RegExp(r'[\d:.,\s]*-->[\d:.,\s]*'), '') // 타임스탬프 제거
            .trim();
      } else {
        return '';
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('Error fetching captions for video $videoId: $e');
      }
      return '';
    }
  }
} 