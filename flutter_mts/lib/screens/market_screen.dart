import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/user_provider.dart';
import 'stock_detail_screen.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart';

class MarketScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const MarketScreen({super.key, this.onTabChange});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketData = Provider.of<MarketDataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    
    final filteredTickers = marketData.prices.keys.where((ticker) {
      final query = _searchQuery.toLowerCase();
      final tickerLower = ticker.toLowerCase();
      // Also check against display name (removing _MOCK suffix if present)
      final displayName = ticker.split('_')[0].toLowerCase();
      return tickerLower.contains(query) || displayName.contains(query);
    }).toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('주식 시세', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: '투자 정보',
            onPressed: () {
              if (widget.onTabChange != null) {
                widget.onTabChange!(4); // 인사이트 탭으로 이동
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '종목명 또는 티커 검색',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                    )
                  : null,
                filled: true,
                fillColor: const Color(0xFF1A1D2D),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 투자 정보 퀵 배너
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: InkWell(
              onTap: () {
                if (widget.onTabChange != null) {
                  widget.onTabChange!(4); // 인사이트 탭으로 이동
                }
              },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).primaryColor.withOpacity(0.2), Theme.of(context).primaryColor.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('실시간 투자 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('지금 바로 시장의 주요 이슈를 확인하세요', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).primaryColor),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: filteredTickers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.white10),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '데이터를 불러오는 중...' : '검색 결과가 없습니다.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredTickers.length,
                    itemBuilder: (context, index) {
                      final ticker = filteredTickers[index];
                      final data = marketData.prices[ticker];
                      if (data == null) return const SizedBox.shrink();
                      
                      final price = data['price'] ?? 0;
                      final change = data['change_percent'] ?? 0.0;
                      final displayName = data['name'] ?? ticker;
                      final productCode = data['productCode'] ?? "100";
      
                      return _buildStockItem(
                        context, 
                        ticker,
                        displayName,
                        formatter.format(price), 
                        '${change > 0 ? '+' : ''}$change%', 
                        change > 0 ? 1 : (change < 0 ? -1 : 0),
                        productCode,
                        settings,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItem(BuildContext context, String ticker, String name, String price, String change, int trend, String productCode, SettingsProvider settings) {
    final userProvider = Provider.of<UserProvider>(context);
    final isWatching = userProvider.isWatching(ticker);

    String typeLabel = productCode == "200" ? "ETF" : "주식";
    Color typeColor = productCode == "200" ? Colors.orangeAccent : Colors.blueAccent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => StockDetailScreen(ticker: ticker)),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: settings.isCompactMode ? 8 : 16, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => userProvider.toggleWatchlist(ticker),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  isWatching ? Icons.star : Icons.star_border,
                  color: isWatching ? Colors.yellow : Colors.grey,
                  size: 24,
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: typeColor.withOpacity(0.5)),
                            ),
                            child: Text(
                              typeLabel, 
                              style: TextStyle(
                                color: typeColor, 
                                fontSize: 8, 
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ),
                        ],
                      ),
                      Text(ticker, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: settings.isCompactMode ? 14 : 16)),
                      Text(change, style: TextStyle(
                        color: trend > 0 ? settings.upColor : (trend < 0 ? settings.downColor : Colors.white70), 
                        fontSize: settings.isCompactMode ? 12 : 14
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
