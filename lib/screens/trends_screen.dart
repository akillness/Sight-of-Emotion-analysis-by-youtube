import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/youtube_data.dart';
import '../widgets/charts/trends_pie_chart.dart';
import '../widgets/charts/keyword_typography.dart';
import '../widgets/pagination_controls.dart';
import '../services/database_helper.dart';
import 'sentiment_visualization_screen.dart';

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
  List<YoutubeData> _trends = [];
  bool _isLoading = false;
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  static const int _itemsPerPage = 10;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrends(); // Will now default to Korean "게임"
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    try {
      final response = await _apiService.searchTrends(defaultQuery);
      final sortedTrends = response.items..sort((a, b) => b.views.compareTo(a.views));
      setState(() {
        _trends = sortedTrends;
        _totalPages = (_trends.length / _itemsPerPage).ceil();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error loading game trends (검색: $defaultQuery): $e');
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
    try {
      final response = await _apiService.searchTrends(finalQuery);
      final sortedTrends = response.items..sort((a, b) => b.views.compareTo(a.views));
      setState(() {
        _trends = sortedTrends;
        _totalPages = (_trends.length / _itemsPerPage).ceil();
        _currentPage = 1;
      });
    } catch (e) {
      print('Error searching trends for "$finalQuery": $e');
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 48,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dataTableTheme: DataTableThemeData(
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFF4A6FFF),
                          ),
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 84,
                          columnSpacing: 24,
                          horizontalMargin: 24,
                          headingRowHeight: 56,
                          dividerThickness: 0.5,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
                        ),
                      ),
                      child: DataTable(
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
                            if (rank <= 3) return const Color(0xFFFFB800);
                            if (rank <= 10) return const Color(0xFF4A6FFF);
                            if (rank <= 20) return const Color(0xFF00C48C);
                            return Colors.grey;
                          }

                          return DataRow(
                            color: WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) {
                                if (states.contains(WidgetState.hovered)) {
                                  return const Color(0xFF4A6FFF).withOpacity(0.05);
                                }
                                return null;
                              },
                            ),
                            cells: [
                              DataCell(
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: getRankColor().withOpacity(0.1),
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
                                              color: Color(0xFF2C3E50),
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A6FFF).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Icon(
                                            Icons.play_circle_outline,
                                            size: 16,
                                            color: Color(0xFF4A6FFF),
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
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A6FFF).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.visibility,
                                        size: 16,
                                        color: Color(0xFF4A6FFF),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        NumberFormat.compact().format(item.views),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: rank <= 10 ? FontWeight.bold : FontWeight.normal,
                                          color: const Color(0xFF4A6FFF),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4A4A).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.favorite,
                                        size: 16,
                                        color: Color(0xFFFF4A4A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        NumberFormat.compact().format(item.likes),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: rank <= 10 ? FontWeight.bold : FontWeight.normal,
                                          color: const Color(0xFFFF4A4A),
                                        ),
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
                                          child: Chip(
                                             label: Text(keyword),
                                             labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF4A6FFF)),
                                             backgroundColor: const Color(0xFF4A6FFF).withOpacity(0.1),
                                             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                             materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                             side: BorderSide.none,
                                          )
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                               DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        item.timestamp ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
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
        ),
        if (_totalPages > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0, right: 24.0, left: 24.0),
            child: PaginationControls(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onPageChanged: _handlePageChange,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
         title: const Text('YouTube 트렌드 분석', style: TextStyle(fontWeight: FontWeight.bold)),
         centerTitle: false,
         actions: [
           IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: _loadTrends,
             tooltip: '새로고침',
           )
         ],
       ),
      body: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '관련 트렌드 검색 (기본: 게임)...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4A6FFF), width: 1.5),
                      ),
                    ),
                    onChanged: (value) => _searchQuery = value,
                    onSubmitted: (_) => _searchTrends(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _searchTrends,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('검색'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A6FFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
           Container(
             margin: const EdgeInsets.symmetric(horizontal: 24.0).copyWith(bottom: 16.0),
             padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
             child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4A6FFF), Color(0xFF6B8AFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(icon: Icon(Icons.table_chart_outlined), text: '데이터 테이블'),
                  Tab(icon: Icon(Icons.bar_chart_outlined), text: '차트 분석'),
                  Tab(icon: Icon(Icons.psychology_outlined), text: '키워드 시각화'),
                ],
              ),
           ),
           Expanded(
             child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildDataTable(context),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
                    child: Column(
                       children: [
                         Container(
                           height: 300,
                           margin: const EdgeInsets.only(bottom: 16),
                           padding: const EdgeInsets.all(16),
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text("상위 트렌드 조회수 분포", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                               const SizedBox(height: 8),
                               Expanded(child: TrendsPieChart(trends: _trends)),
                             ],
                           ),
                         ),
                         Container(
                            height: 300,
                           padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               const Text("주요 키워드 (상위 5개 영상)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                               const SizedBox(height: 8),
                               Expanded(child: KeywordTypography(trends: _trends.take(5).toList())),
                             ],
                           ),
                         ),
                       ],
                    ),
                  ),
                  const SentimentVisualizationScreen(),
                ],
              ),
           ),
         ],
      ),
    );
  }
} 