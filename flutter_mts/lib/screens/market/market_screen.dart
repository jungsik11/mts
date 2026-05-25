import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/market_data_provider.dart';
import '../../providers/user_provider.dart';
import 'stock_detail_screen.dart';
import '../../providers/settings_provider.dart';
import 'package:intl/intl.dart';
import '../../utils/formatter_utils.dart';

class MarketScreen extends StatefulWidget {
  final Function(int)? onTabChange;
  const MarketScreen({super.key, this.onTabChange});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortCriteria = 'NAME'; // 'NAME' or 'RETURN'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketData = Provider.of<MarketDataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    
    final filteredTickers = marketData.prices.keys.where((ticker) {
      final query = _searchQuery.toLowerCase();
      final tickerLower = ticker.toLowerCase();
      
      // Get the actual stock name from marketData
      final stockData = marketData.prices[ticker];
      final stockName = (stockData?['name'] ?? "").toString().toLowerCase();
      
      // Check against ticker, derived displayName, AND the actual stockName
      final displayName = ticker.split('_')[0].toLowerCase();
      
      return tickerLower.contains(query) || 
             displayName.contains(query) || 
             stockName.contains(query);
    }).toList();

    // 정렬 라벨 계산 (오전 8시 ~ 오후 8시는 가나다순, 그 외는 ABC순)
    final now = DateTime.now();
    final nameSortLabel = (now.hour >= 8 && now.hour < 20) ? '가나다순' : 'ABC순';

    // 정렬 적용
    filteredTickers.sort((a, b) {
      if (_sortCriteria == 'NAME') {
        final nameA = (marketData.prices[a]?['name'] ?? a).toString();
        final nameB = (marketData.prices[b]?['name'] ?? b).toString();
        
        if (nameSortLabel == '가나다순') {
          final isKoreanA = nameA.isNotEmpty && nameA.codeUnitAt(0) >= 0xAC00 && nameA.codeUnitAt(0) <= 0xD7A3;
          final isKoreanB = nameB.isNotEmpty && nameB.codeUnitAt(0) >= 0xAC00 && nameB.codeUnitAt(0) <= 0xD7A3;
          if (isKoreanA && !isKoreanB) return -1;
          if (!isKoreanA && isKoreanB) return 1;
        }
        return nameA.compareTo(nameB);
      } else if (_sortCriteria == 'PRICE_DESC' || _sortCriteria == 'PRICE_ASC') {
        final priceA = (marketData.prices[a]?['price'] ?? 0.0) as num;
        final priceB = (marketData.prices[b]?['price'] ?? 0.0) as num;
        return _sortCriteria == 'PRICE_DESC'
            ? priceB.compareTo(priceA)
            : priceA.compareTo(priceB);
      } else if (_sortCriteria == 'RETURN_DESC' || _sortCriteria == 'RETURN_ASC') {
        final changeA = (marketData.prices[a]?['change_percent'] ?? 0.0) as double;
        final changeB = (marketData.prices[b]?['change_percent'] ?? 0.0) as double;
        return _sortCriteria == 'RETURN_DESC' 
            ? changeB.compareTo(changeA) 
            : changeA.compareTo(changeB);
      }
      return 0;
    });

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (_searchQuery.isEmpty)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (widget.onTabChange != null) {
                          widget.onTabChange!(4); // 인사이트 탭으로 이동
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('실시간 투자 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text('지금 바로 시장의 주요 이슈를 확인하세요', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Theme.of(context).primaryColor),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (_searchQuery.isEmpty) const SizedBox(width: 12),
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D2D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButton<String>(
                    value: _sortCriteria,
                    dropdownColor: const Color(0xFF1A1D2D),
                    borderRadius: BorderRadius.circular(16),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                    items: [
                      DropdownMenuItem(value: 'NAME', child: Text(nameSortLabel)),
                      const DropdownMenuItem(value: 'PRICE_DESC', child: Text('가격 높은순')),
                      const DropdownMenuItem(value: 'PRICE_ASC', child: Text('가격 낮은순')),
                      const DropdownMenuItem(value: 'RETURN_DESC', child: Text('수익률 높은순')),
                      const DropdownMenuItem(value: 'RETURN_ASC', child: Text('수익률 낮은순')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _sortCriteria = val);
                      }
                    },
                  ),
                ),
              ],
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filteredTickers.length,
                    itemBuilder: (context, index) {
                      final ticker = filteredTickers[index];
                      final data = marketData.prices[ticker];
                      if (data == null) return const SizedBox.shrink();
                      
                      final price = data['price'] ?? 0;
                      final change = data['change_percent'] ?? 0.0;
                      final displayName = data['name'] ?? ticker;
                      final productCode = data['productCode'] ?? "100";
                      final currency = data['currency'] ?? (RegExp(r'[a-zA-Z]').hasMatch(ticker) ? "USD" : "KRW");
      
                      return _buildStockItem(
                        context, 
                        ticker,
                        displayName,
                        FormatterUtils.formatPrice(price, currency: currency), 
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

    String typeLabel = productCode == "200" ? "ETF" : (productCode == "300" ? "해외" : "주식");
    Color typeColor = productCode == "200" ? Colors.orangeAccent : (productCode == "300" ? Colors.greenAccent : Colors.blueAccent);

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name, 
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                              ),
                            ),
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
                  ),
                  const SizedBox(width: 12),
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
