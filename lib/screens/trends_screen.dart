import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
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

  Widget _buildAnalysisTab() {
    return _currentAnalysisResults.isEmpty
        ? const Center(
            child: Text(
              '분석 데이터가 없습니다.',
              style: TextStyle(color: AppTheme.textColor),
            ),
          )
        : GridView.count(
            crossAxisCount: 2,
            children: [
              Card(
                elevation: 4,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: AppTheme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '감정 분석',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _currentAnalysisResults.length,
                          itemBuilder: (context, index) {
                            final result = _currentAnalysisResults[index];
                            return ListTile(
                              title: Text(
                                result.youtubeData.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Wrap(
                                spacing: 4,
                                children: result.keywords.map((k) {
                                  final color = _getSentimentColor(k.sentiment);
                                  return Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      k.keyword,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }).toList(),
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
          );
  }

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