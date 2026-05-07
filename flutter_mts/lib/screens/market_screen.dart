import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import 'stock_detail_screen.dart';
import 'package:intl/intl.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

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
      body: filteredTickers.isEmpty
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
                final price = data['price'] ?? 0;
                final change = data['change_percent'] ?? 0.0;
                return _buildStockItem(
                  context, 
                  ticker, 
                  formatter.format(price), 
                  '${change > 0 ? '+' : ''}$change%', 
                  change >= 0
                );
              },
            ),
    );
  }

  Widget _buildStockItem(BuildContext context, String name, String price, String change, bool isPositive) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => StockDetailScreen(ticker: name)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.split('_')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Text('KOSPI', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(change, style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
