import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../services/nlp_service.dart';
import '../models/video_analysis_result.dart';
import '../models/keyword_sentiment.dart';
import '../models/youtube_data.dart';
import '../widgets/charts/trends_pie_chart.dart';
import '../widgets/charts/keyword_network_graph.dart';
import '../widgets/pagination_controls.dart';
import '../services/database_helper.dart';
import '../widgets/app_theme.dart';

// 추가: 감성 정렬 타입 정의
enum SentimentSortType { all, positive, negative, neutral }

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

// Helper function to check for Korean characters
bool _containsKorean(String text) {
  // Basic check using Unicode range for Hangul Syllables
  final koreanRegex = RegExp(r'[\uAC00-\uD7AF]');
  return koreanRegex.hasMatch(text);
}

class _TrendsScreenState extends State<TrendsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final NlpService _nlpService = NlpService();
  List<YoutubeData> _trends = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _itemsPerPage = 10;
  late TabController _tabController;
  List<VideoAnalysisResult> _currentAnalysisResults = [];
  
  // 추가: 감성 정렬 상태 변수
  SentimentSortType _selectedSentimentSort = SentimentSortType.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadTrends();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    // Optional: Load data only when the tab is selected if preferred
    // if (_tabController.index == 3 && _analysisResults.isEmpty && !_isAnalysisLoading) {
    //   _loadGamingVideoAnalysis();
    // }
  }

  Future<void> _runAnalysis() async {
    if (!mounted || _trends.isEmpty) {
      setState(() => _currentAnalysisResults = []);
      return;
    }
    final analysis = await _nlpService.analyzeVideoTitles(_trends);
    if (mounted) {
      setState(() {
        _currentAnalysisResults = analysis;
      });
    }
  }

  Future<void> _launchYoutubeVideo(String videoId) async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _loadTrends() async {
    setState(() => _isLoading = true);
    const defaultQuery = "게임"; // Default to Korean
    _searchQuery = defaultQuery; // Store the actual default used
    List<YoutubeData> sortedTrends = [];
    try {
      final response = await _apiService.searchTrends(defaultQuery);
      sortedTrends = response.items..sort((a, b) => b.views.compareTo(a.views));
      setState(() {
        _trends = sortedTrends;
        _totalPages = (_trends.length / _itemsPerPage).ceil();
        _currentPage = 1;
      });
      await _runAnalysis();
    } catch (e) {
      print('Error loading game trends (검색: $defaultQuery): $e');
      setState(() => _trends = []);
      await _runAnalysis();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _searchTrends() async {
    final trimmedQuery = _searchQuery.trim();
    String languageSpecificPrefix;
    String finalQuery;

    if (trimmedQuery.isEmpty) {
      languageSpecificPrefix = "게임"; // Default Korean
      finalQuery = languageSpecificPrefix;
    } else if (_containsKorean(trimmedQuery)) {
      languageSpecificPrefix = "게임";
      finalQuery = "$languageSpecificPrefix $trimmedQuery";
    } else {
      languageSpecificPrefix = "game"; // Assume English/other if no Korean detected
      finalQuery = "$languageSpecificPrefix $trimmedQuery";
    }

    print('Performing search with query: $finalQuery'); // Log the query being used

    setState(() => _isLoading = true);
    List<YoutubeData> sortedTrends = [];
    try {
      final response = await _apiService.searchTrends(finalQuery);
      sortedTrends = response.items..sort((a, b) => b.views.compareTo(a.views));
      setState(() {
        _trends = sortedTrends;
        _totalPages = (_trends.length / _itemsPerPage).ceil();
        _currentPage = 1;
      });
      await _runAnalysis();
    } catch (e) {
      print('Error searching trends for "$finalQuery": $e');
      setState(() => _trends = []);
      await _runAnalysis();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handlePageChange(int newPage) {
    if (newPage >= 1 && newPage <= _totalPages) {
      setState(() => _currentPage = newPage);
    }
  }

  List<YoutubeData> get _currentPageItems {
    if (_trends.isEmpty) return [];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex < 0 || startIndex >= _trends.length) {
      if (_totalPages > 0) _currentPage = 1;
      return _trends.take(_itemsPerPage).toList();
    }
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _trends.length);
    return _trends.sublist(startIndex, endIndex);
  }

  Widget _buildDataTable(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 48,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      columnSpacing: 24,
                      horizontalMargin: 24,
                      headingRowHeight: 56,
                      dataRowMinHeight: 70,
                      dataRowMaxHeight: 90,
                      headingRowColor: WidgetStateProperty.all(
                        AppTheme.secondaryColor,
                      ),
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                        fontSize: 14,
                      ),
                      dividerThickness: 0.5,
                      columns: const [
                        DataColumn(label: Text('순위')),
                        DataColumn(label: Text('제목')),
                        DataColumn(label: Text('조회수')),
                        DataColumn(label: Text('좋아요')),
                        DataColumn(label: Text('키워드')),
                        DataColumn(label: Text('업로드 시간')),
                      ],
                      rows: _currentPageItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final rank = (_currentPage - 1) * _itemsPerPage + index + 1;
                        
                        Color getRankColor() {
                          if (rank <= 3) return Colors.amber;
                          if (rank <= 10) return AppTheme.primaryColor;
                          return Colors.grey;
                        }

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.hovered)) {
                                return AppTheme.secondaryColor;
                              }
                              return null;
                            },
                          ),
                          cells: [
                            DataCell(
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: getRankColor().withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    rank.toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: getRankColor(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.3,
                                ),
                                child: InkWell(
                                  onTap: () => _launchYoutubeVideo(item.videoId),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.visibility_outlined,
                                    size: 16,
                                    color: AppTheme.textColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    NumberFormat.compact().format(item.views),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: rank <= 10 ? FontWeight.bold : FontWeight.normal,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.thumb_up_outlined,
                                    size: 16,
                                    color: AppTheme.textColor.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    NumberFormat.compact().format(item.likes),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: rank <= 10 ? FontWeight.bold : FontWeight.normal,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.2,
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: item.keywords.map((keyword) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            keyword,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatDate(item.timestamp),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textColor.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: PaginationControls(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _handlePageChange,
            ),
          ),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return isoDate;
    }
  }

  // Helper function to get the max score for a specific sentiment in a result
  double _getMaxSentimentScore(VideoAnalysisResult result, Sentiment targetSentiment) {
    double maxScore = 0.0; 
    for (var kw in result.keywords) {
      if (kw.sentiment == targetSentiment) {
        maxScore = max(maxScore, kw.score);
      }
    }
    return maxScore;
  }

  Widget _buildAnalysisTab() {
    if (_currentAnalysisResults.isEmpty) {
      return const Center(
        child: Text(
          '분석 데이터가 없습니다.',
          style: TextStyle(color: AppTheme.textColor),
        ),
      );
    }
    
    // Limit the number of results
    final baseResults = _currentAnalysisResults.take(20).toList();

    // 필터링 및 정렬된 결과 리스트 계산
    List<VideoAnalysisResult> filteredAndSortedResults;
    if (_selectedSentimentSort == SentimentSortType.all) {
      // 'all' 선택 시 조회수 기준으로 정렬
      filteredAndSortedResults = List.from(baseResults)
        ..sort((a, b) => b.youtubeData.views.compareTo(a.youtubeData.views));
    } else {
      // 특정 감성 타입 선택 시 필터링 및 조회수 기준 정렬
      Sentiment targetSentiment;
      switch (_selectedSentimentSort) {
        case SentimentSortType.positive: targetSentiment = Sentiment.positive; break;
        case SentimentSortType.negative: targetSentiment = Sentiment.negative; break;
        case SentimentSortType.neutral: targetSentiment = Sentiment.neutral; break;
        default: targetSentiment = Sentiment.neutral; // Should not happen
      }
      
      filteredAndSortedResults = baseResults.where((result) {
        // Check if the video contains at least one keyword with the target sentiment
        return result.keywords.any((kw) => kw.sentiment == targetSentiment);
      }).toList()
        // Sort by the maximum score of the target sentiment (descending)
        ..sort((a, b) {
            double scoreA = _getMaxSentimentScore(a, targetSentiment);
            double scoreB = _getMaxSentimentScore(b, targetSentiment);
            // If scores are equal, fall back to view count as a secondary sort
            int scoreComparison = scoreB.compareTo(scoreA);
            if (scoreComparison == 0) {
                return b.youtubeData.views.compareTo(a.youtubeData.views);
            }
            return scoreComparison;
        });
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end, // 드롭다운을 오른쪽으로
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SentimentSortType>(
                    value: _selectedSentimentSort,
                    dropdownColor: AppTheme.cardColor, // 드롭다운 메뉴 배경색
                    style: const TextStyle(color: AppTheme.textColor, fontSize: 14), // 드롭다운 텍스트 스타일
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
                    onChanged: (SentimentSortType? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSentimentSort = newValue;
                        });
                      }
                    },
                    items: SentimentSortType.values
                        .map<DropdownMenuItem<SentimentSortType>>((SentimentSortType value) {
                      return DropdownMenuItem<SentimentSortType>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(
                              value == SentimentSortType.positive ? Icons.thumb_up
                              : value == SentimentSortType.negative ? Icons.thumb_down
                              : value == SentimentSortType.neutral ? Icons.thumbs_up_down
                              : Icons.list,
                              color: _getSentimentColorForSort(value),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(value.toString().split('.').last.capitalize()),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2, 
            childAspectRatio: 1.0,
            children: [
              Card(
                elevation: 4,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '감정 분석 결과', // 제목 변경
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredAndSortedResults.isEmpty
                        ? Center(
                            child: Text(
                              '${_selectedSentimentSort.toString().split('.').last.capitalize()} 감성의 비디오가 없습니다.', 
                              style: const TextStyle(color: AppTheme.textColor, fontSize: 14)
                            )
                          )
                        : ListView.builder(
                            // itemCount는 필터링된 리스트 길이를 사용
                            itemCount: filteredAndSortedResults.length, 
                            itemBuilder: (context, index) {
                              // 필터링/정렬된 결과 사용
                              final result = filteredAndSortedResults[index]; 
                              final youtubeData = result.youtubeData;
                              
                              // 대표 감정 계산 (이미 필터링 시 사용했으나 아이콘 표시 위해 유지)
                              int positiveCount = 0, negativeCount = 0, neutralCount = 0;
                              for (var kw in result.keywords) {
                                switch (kw.sentiment) {
                                  case Sentiment.positive: positiveCount++; break;
                                  case Sentiment.negative: negativeCount++; break;
                                  case Sentiment.neutral: neutralCount++; break;
                                }
                              }
                              final overallSentiment = (positiveCount > negativeCount && positiveCount > neutralCount)
                                  ? Sentiment.positive
                                  : (negativeCount > positiveCount && negativeCount > neutralCount)
                                      ? Sentiment.negative
                                      : Sentiment.neutral;
                              
                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container( // 대표 감정 아이콘
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      color: _getSentimentColor(overallSentiment).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(child: Icon(
                                      overallSentiment == Sentiment.positive ? Icons.thumb_up
                                      : overallSentiment == Sentiment.negative ? Icons.thumb_down
                                      : Icons.thumbs_up_down,
                                      color: _getSentimentColor(overallSentiment), size: 18)
                                    ),
                                  ),
                                  title: Text( // 비디오 제목
                                    youtubeData.title.length > 30 ? '${youtubeData.title.substring(0, 30)}...' : youtubeData.title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textColor),
                                  ),
                                  subtitle: result.keywords.isEmpty // 필터링 없이 원래 키워드 표시
                                    ? Text('키워드 없음', style: TextStyle(fontSize: 10, color: AppTheme.textColor.withOpacity(0.7)))
                                    : SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            // 필터링 없이 비디오의 원래 키워드 표시 (최대 5개)
                                            for (var kw in result.keywords.take(5)) 
                                              Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: Chip(
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                  label: Text(kw.keyword, style: TextStyle(fontSize: 10, color: _getSentimentColor(kw.sentiment))),
                                                  backgroundColor: _getSentimentColor(kw.sentiment).withOpacity(0.1),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  trailing: IconButton( // 비디오 링크
                                    icon: const Icon(Icons.open_in_new, size: 16), 
                                    color: AppTheme.primaryColor,
                                    onPressed: () => _launchYoutubeVideo(youtubeData.videoId),
                                  ),
                                  dense: true,
                                ),
                              );
                            },
                          ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TrendsPieChart(trends: _trends, itemCount: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 정렬 타입에 따른 색상 반환 (선택된 칩 표시용)
  Color _getSentimentColorForSort(SentimentSortType type) {
    switch (type) {
      case SentimentSortType.positive: return const Color(0xFF1DB954);
      case SentimentSortType.negative: return AppTheme.primaryColor;
      case SentimentSortType.neutral: return AppTheme.textColor;
      case SentimentSortType.all: return Colors.blueGrey; // 전체 선택 시 색상
    }
  }

  // 기존 감성 색상 함수
  Color _getSentimentColor(Sentiment sentiment) {
    switch (sentiment) {
      case Sentiment.positive:
        return const Color(0xFF1DB954); // Spotify Green
      case Sentiment.negative:
        return AppTheme.primaryColor; // Netflix Red
      case Sentiment.neutral:
      default:
        return AppTheme.textColor; // White
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.movie_filter,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'YouTube 트렌드 분석',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: const TextStyle(color: AppTheme.textColor),
                            decoration: InputDecoration(
                              hintText: '검색어를 입력하세요',
                              hintStyle: TextStyle(color: AppTheme.textColor.withOpacity(0.5)),
                              border: InputBorder.none,
                              icon: const Icon(Icons.search, color: AppTheme.primaryColor),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            onSubmitted: (_) => _searchTrends(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _searchTrends,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: AppTheme.textColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('검색'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryColor,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: AppTheme.textColor.withOpacity(0.7),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.table_chart_outlined),
                    text: '트렌드 테이블',
                  ),
                  Tab(
                    icon: Icon(Icons.insights_outlined),
                    text: '분석',
                  ),
                  Tab(
                    icon: Icon(Icons.hub_outlined),
                    text: '네트워크',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDataTable(context),
                        _buildAnalysisTab(),
                        KeywordNetworkGraph(analysisResults: _currentAnalysisResults),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// 문자열 확장 함수 (첫 글자 대문자화)
extension StringExtension on String {
    String capitalize() {
      return "${this[0].toUpperCase()}${substring(1)}";
    }
} 