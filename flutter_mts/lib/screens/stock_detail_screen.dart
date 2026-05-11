import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../providers/news_provider.dart';
import 'news_detail_screen.dart';

class StockDetailScreen extends StatefulWidget {
  final String ticker;
  final int initialTabIndex; // 0: 요약, 1: 차트, 2: 매수, 3: 매도, 4: 체결

  const StockDetailScreen({
    super.key, 
    required this.ticker, 
    this.initialTabIndex = 1, // 기본값을 차트(1)로 설정
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _priceController = TextEditingController();
  Timer? _timer;
  List<dynamic> _candles = [];
  String _selectedInterval = "1m";
  late TabController _tabController;

  // Interaction States
  double _candleWidth = 10.0;
  double _scrollOffset = 0.0;
  double _baseCandleWidth = 10.0;
  Offset? _crosshairPos;

  @override
  void initState() {
    super.initState();
    // TabController 생성 시 initialIndex 명시적 적용
    _tabController = TabController(
      length: 6, 
      vsync: this, 
      initialIndex: widget.initialTabIndex,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final marketProvider = Provider.of<MarketDataProvider>(context, listen: false);
      marketProvider.fetchOrderBook(widget.ticker);
      marketProvider.fetchMarketTrades(widget.ticker);
      marketProvider.setLastViewedTicker(widget.ticker);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.fetchTradeHistory(); // Fetch all history
      userProvider.fetchOpenOrders();
      _updateCandles();
    });
    
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        final marketProvider = Provider.of<MarketDataProvider>(context, listen: false);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        marketProvider.fetchOrderBook(widget.ticker);
        marketProvider.fetchMarketTrades(widget.ticker);
        userProvider.fetchTradeHistory(); // Fetch all history
        userProvider.fetchOpenOrders();
        _updateCandles();
      }
    });
  }

  Future<void> _updateCandles() async {
    final candles = await Provider.of<MarketDataProvider>(context, listen: false)
        .fetchCandles(widget.ticker, _selectedInterval);
    if (mounted) {
      setState(() {
        _candles = candles;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _qtyController.dispose();
    _priceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final marketData = Provider.of<MarketDataProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    final priceData = marketData.prices[widget.ticker] ?? {"price": 0, "change_percent": 0.0};
    final currentPrice = (priceData['price'] ?? 0) as num;
    final changePercent = (priceData['change_percent'] ?? 0.0) as num;
    final displayName = priceData['name'] ?? widget.ticker.replaceAll('_MOCK', '');

    if (_priceController.text.isEmpty && currentPrice > 0) {
      _priceController.text = currentPrice.toString();
    }

    final orderBook = marketData.getOrderBook(widget.ticker);

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F111A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.ticker.replaceAll('_MOCK', ''), style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF2D5AF7),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '요약'), // 0
            Tab(text: '차트'), // 1
            Tab(text: '매수'), // 2
            Tab(text: '매도'), // 3
            Tab(text: '체결'), // 4
            Tab(text: '뉴스'), // 5
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(priceData, formatter, settings),
          _buildChartTab(formatter, currentPrice, changePercent, settings),
          _buildBuyTab(orderBook, formatter, settings),
          _buildSellTab(orderBook, formatter, settings),
          _buildExecutionsTab(userProvider, marketData, formatter),
          _buildNewsTab(displayName, widget.ticker), // 5: 뉴스 탭
        ],
      ),
    );
  }

  // --- 요약 탭 ---
  Widget _buildSummaryTab(Map<String, dynamic> data, NumberFormat formatter, SettingsProvider settings) {
    final productCode = data['productCode'] ?? "100";
    final typeLabel = productCode == "200" ? "ETF (상장지수펀드)" : "KOSPI 일반주식";
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('종목 요약 정보', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              _buildInfoRow('종목명', data['name'] ?? '-'),
              _buildInfoDivider(),
              _buildInfoRow('티커코드', widget.ticker),
              _buildInfoDivider(),
              _buildInfoRow('상품구분', typeLabel),
              _buildInfoDivider(),
              _buildInfoRow('현재가', formatter.format(data['price'] ?? 0)),
              _buildInfoDivider(),
              _buildInfoRow('등락률', '${data['change_percent'] ?? 0}%', 
                valueColor: (data['change_percent'] ?? 0) > 0 
                  ? settings.upColor 
                  : ((data['change_percent'] ?? 0) < 0 ? settings.downColor : Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() => Divider(color: Colors.white.withOpacity(0.05), height: 1);

  // --- 차트 탭 ---
  Widget _buildChartTab(NumberFormat formatter, dynamic currentPrice, dynamic changePercent, SettingsProvider settings) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatter.format(currentPrice), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  Text('${changePercent > 0 ? '+' : ''}$changePercent%', 
                    style: TextStyle(
                      color: changePercent > 0 ? settings.upColor : (changePercent < 0 ? settings.downColor : Colors.white70), 
                      fontSize: 18
                    )),
                ],
              ),
              _buildIntervalSelector(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: _buildCandleChartSection(settings),
          ),
        ),
      ],
    );
  }

  // --- 매수/매도 탭 ---
  Widget _buildBuyTab(Map<String, dynamic> orderBook, NumberFormat formatter, SettingsProvider settings) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildOrderBookSection(orderBook, formatter, settings)),
        Container(width: 1, color: Colors.white10),
        Expanded(flex: 1, child: _buildTradeSection(formatter, "BUY", settings)),
      ],
    );
  }

  Widget _buildSellTab(Map<String, dynamic> orderBook, NumberFormat formatter, SettingsProvider settings) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildOrderBookSection(orderBook, formatter, settings)),
        Container(width: 1, color: Colors.white10),
        Expanded(flex: 1, child: _buildTradeSection(formatter, "SELL", settings)),
      ],
    );
  }

  int _executionViewMode = 0; // 0: 시장 체결, 1: 내 체결, 2: 미체결

  // --- 체결 탭 ---
  Widget _buildExecutionsTab(UserProvider userProvider, MarketDataProvider marketData, NumberFormat formatter) {
    final marketTrades = marketData.getMarketTrades(widget.ticker);
    final myTrades = userProvider.tradeHistory;
    final openOrders = userProvider.openOrders;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTradeToggleBtn('시장 체결', _executionViewMode == 0, () => setState(() => _executionViewMode = 0)),
                _buildTradeToggleBtn('내 체결', _executionViewMode == 1, () => setState(() => _executionViewMode = 1)),
              ],
            ),
          ),
        ),
        Expanded(
          child: _buildExecutionList(userProvider, marketTrades, myTrades, openOrders, formatter, settings),
        ),
      ],
    );
  }

  Widget _buildExecutionList(UserProvider userProvider, List<dynamic> marketTrades, List<dynamic> myTrades, List<dynamic> openOrders, NumberFormat formatter, SettingsProvider settings) {
    if (_executionViewMode == 1) {
      return _buildMyTradesList(myTrades, openOrders, userProvider.userId, formatter, settings);
    }
    return _buildMarketTradesList(marketTrades, formatter, settings);
  }

  Widget _buildOpenOrdersList(List<dynamic> orders, NumberFormat formatter, SettingsProvider settings) {
    if (orders.isEmpty) return const Center(child: Text('미체결 주문이 없습니다.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isBuy = order['side'] == 'BUY';
        final color = isBuy ? settings.upColor : settings.downColor;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isBuy ? '매수' : '매도', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[${order['ticker']}] ${formatter.format(order['price'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('남은 수량: ${order['quantity']} / ${order['initialQuantity']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Text('대기중', style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
  Widget _buildTradeToggleBtn(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2D5AF7) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketTradesList(List<dynamic> trades, NumberFormat formatter, SettingsProvider settings) {
    if (trades.isEmpty) return const Center(child: Text('체결 내역이 없습니다.', style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      itemCount: trades.length,
      itemBuilder: (context, index) {
        final trade = trades[index];
        final isUp = (trade['side'] == 'BUY' || trade['type'] == 'BUY'); // 데이터 필드명에 따라 조정 필요할 수 있음
        return ListTile(
          dense: true,
          title: Text(formatter.format(trade['price'] ?? 0), 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Text('수량: ${trade['quantity']}주', style: const TextStyle(color: Colors.white60)),
          trailing: Text(_formatTradeTime(trade['timestamp']), style: const TextStyle(color: Colors.white38, fontSize: 12)),
        );
      },
    );
  }

  Widget _buildMyTradesList(List<dynamic> trades, List<dynamic> openOrders, int? userId, NumberFormat formatter, SettingsProvider settings) {
    final List<Map<String, dynamic>> combined = [];
    for (var o in openOrders) combined.add({...o, 'isMatched': false});
    for (var t in trades) combined.add({...t, 'isMatched': true});
    combined.sort((a, b) => (b['timestamp'] as num).compareTo(a['timestamp'] as num));

    if (combined.isEmpty) return const Center(child: Text('내 주문 내역이 없습니다.', style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      itemCount: combined.length,
      itemBuilder: (context, index) {
        final item = combined[index];
        final isMatched = item['isMatched'] == true;
        final isBuyer = item['buyerId'] == userId || (item['side'] == 'BUY' && !isMatched);
        final color = isBuyer ? settings.upColor : settings.downColor;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isMatched ? color.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isMatched ? color.withOpacity(0.1) : Colors.orange.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: Icon(isBuyer ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isMatched ? color : Colors.orange),
            title: Row(
              children: [
                Text(isBuyer ? '매수' : '매도', style: TextStyle(color: isMatched ? color : Colors.orange, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (!isMatched) 
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                    child: const Text('대기중', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatter.format(item['price'] ?? 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(_formatTradeTime(item['timestamp']), style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
            trailing: Text('${item['quantity']}주', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      },
    );
  }

  int _toMs(dynamic ts) {
    if (ts == null) return 0;
    if (ts is int) return ts;
    if (ts is String) {
      try {
        // 서버의 LocalDateTime(ISO8601) 문자열을 UTC로 강제 인식
        String parseTarget = ts;
        if (!ts.contains('Z') && !ts.contains('+')) {
          parseTarget = ts + 'Z';
        }
        return DateTime.parse(parseTarget).millisecondsSinceEpoch;
      } catch (e) {
        return 0;
      }
    }
    return 0;
  }

  String _formatTradeTime(dynamic ts) {
    try {
      if (ts == null) return "--:--:--";
      DateTime dt;
      if (ts is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(ts).toUtc().add(const Duration(hours: 9));
      } else if (ts is String) {
        String parseTarget = ts;
        if (!ts.contains('Z') && !ts.contains('+')) {
          parseTarget = ts + 'Z';
        }
        dt = DateTime.parse(parseTarget).toUtc().add(const Duration(hours: 9));
      } else {
        return ts.toString();
      }
      return DateFormat('HH:mm:ss').format(dt);
    } catch (e) {
      return "--:--:--";
    }
  }

  // --- 공통 컴포넌트 ---
  Widget _buildIntervalSelector() {
    return Row(
      children: ["1m", "1h", "1d"].map((interval) {
        bool isSelected = _selectedInterval == interval;
        return GestureDetector(
          onTap: () { setState(() { _selectedInterval = interval; _scrollOffset = 0.0; }); _updateCandles(); },
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : Colors.white10, borderRadius: BorderRadius.circular(20)),
            child: Text(interval.toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCandleChartSection(SettingsProvider settings) {
    return GestureDetector(
      onScaleStart: (details) => _baseCandleWidth = _candleWidth,
      onScaleUpdate: (details) => setState(() { _candleWidth = (_baseCandleWidth * details.scale).clamp(2.0, 50.0); _scrollOffset += details.focalPointDelta.dx; }),
      onLongPressStart: (details) => setState(() => _crosshairPos = details.localPosition),
      onLongPressMoveUpdate: (details) => setState(() => _crosshairPos = details.localPosition),
      onLongPressEnd: (_) => setState(() => _crosshairPos = null),
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomPaint(size: Size(constraints.maxWidth, constraints.maxHeight), painter: CandlePainter(candles: _candles, interval: _selectedInterval, candleWidth: _candleWidth, scrollOffset: _scrollOffset, crosshairPos: _crosshairPos, upColor: settings.upColor, downColor: settings.downColor));
      }),
    );
  }

  Widget _buildOrderBookSection(Map<String, dynamic>? orderBook, NumberFormat formatter, SettingsProvider settings) {
    final bestSells = ((orderBook?['sells'] as List<dynamic>?) ?? []).take(10).toList(); 
    final bestBuys = ((orderBook?['buys'] as List<dynamic>?) ?? []).take(10).toList();
    return Column(children: [
      const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Text('호가', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
      Expanded(child: ListView.builder(reverse: true, itemCount: 10, itemBuilder: (context, index) => index >= bestSells.length ? Container(height: 40) : _buildOrderRow(bestSells[index]['price'], bestSells[index]['quantity'], settings.downColor.withOpacity(0.1), settings.downColor))),
      const Divider(height: 1, color: Colors.white24),
      Expanded(child: ListView.builder(itemCount: 10, itemBuilder: (context, index) => index >= bestBuys.length ? Container(height: 40) : _buildOrderRow(bestBuys[index]['price'], bestBuys[index]['quantity'], settings.upColor.withOpacity(0.1), settings.upColor))),
    ]);
  }

  Widget _buildOrderRow(dynamic price, dynamic qty, Color bgColor, Color textColor) {
    return InkWell(onTap: () => setState(() => _priceController.text = price.toString()), child: Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: bgColor), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('₩$price', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)), Text('$qty', style: const TextStyle(color: Colors.white70, fontSize: 13))])));
  }

  Widget _buildTradeSection(NumberFormat formatter, String side, SettingsProvider settings) {
    final userProvider = Provider.of<UserProvider>(context);
    final inputPrice = int.tryParse(_priceController.text) ?? 0;
    int maxQty = side == "BUY" ? (inputPrice > 0 ? (userProvider.cashBalance ~/ inputPrice) : 0) : (userProvider.holdings.firstWhere((h) => h['ticker'] == widget.ticker, orElse: () => {"quantity": 0})['quantity'] as int);
    final isBuy = side == "BUY";
    final btnColor = isBuy ? settings.upColor : settings.downColor;
    return Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Text('${isBuy ? "매수" : "매도"} 주문', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
      const SizedBox(height: 20),
      TextField(controller: _priceController, decoration: const InputDecoration(labelText: '가격 (원)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height: 16),
      TextField(controller: _qtyController, decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height: 8),
      Text('${isBuy ? "최대 매수" : "보유"} 수량: $maxQty주', style: TextStyle(color: btnColor, fontSize: 12)),
      const SizedBox(height: 32),
      ElevatedButton(onPressed: () => _handleOrder(side), style: ElevatedButton.styleFrom(backgroundColor: btnColor, minimumSize: const Size(double.infinity, 55)), child: Text(isBuy ? "매수" : "매도", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
    ]));
  }

  Widget _buildNewsTab(String name, String ticker) {
    final newsProvider = Provider.of<NewsProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final filteredNews = newsProvider.getArticlesForTicker(ticker, name);

    if (newsProvider.isLoading && filteredNews.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredNews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('관련 뉴스가 없습니다.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => newsProvider.fetchNews(),
              child: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: filteredNews.length > 20 ? 20 : filteredNews.length,
      itemBuilder: (context, index) {
        final article = filteredNews[index];
        return _buildMiniNewsCard(article, settings);
      },
    );
  }

  Widget _buildMiniNewsCard(NewsArticle article, SettingsProvider settings) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _viewNewsDetail(article),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(article.pubDate, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  Icon(Icons.open_in_new, size: 12, color: Colors.white.withOpacity(0.3)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                article.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                article.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewNewsDetail(NewsArticle article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailScreen(url: article.link, title: article.title),
      ),
    );
  }

  void _handleOrder(String side) async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    if (qty <= 0 || price <= 0) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await userProvider.placeOrder(ticker: widget.ticker, quantity: qty, price: price, side: side);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['status'] == 'Order Processed' ? '주문 성공' : '주문 실패'), backgroundColor: result['status'] == 'Order Processed' ? Colors.green : Colors.red));
      userProvider.fetchTradeHistory();
      userProvider.fetchOpenOrders();
    }
  }
}

// Painter 로직 (기존과 동일)
class CandlePainter extends CustomPainter {
  final List<dynamic> candles;
  final String interval;
  final double candleWidth;
  final double scrollOffset;
  final Offset? crosshairPos;
  final Color upColor;
  final Color downColor;
  CandlePainter({required this.candles, required this.interval, required this.candleWidth, required this.scrollOffset, this.crosshairPos, required this.upColor, required this.downColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const double marginBottom = 30.0;
    const double marginRight = 60.0;
    final double chartWidth = size.width - marginRight;
    final double chartHeight = size.height - marginBottom;
    double baseScroll = chartWidth - (candles.length * candleWidth);
    double effectiveOffset = baseScroll + scrollOffset;

    List<dynamic> visibleCandles = candles.where((c) {
      int i = candles.indexOf(c);
      double x = i * candleWidth + effectiveOffset;
      return x + candleWidth >= 0 && x <= chartWidth;
    }).toList();
    if (visibleCandles.isEmpty) visibleCandles = candles;

    double maxH = visibleCandles.map((c) => (c['high'] as num).toDouble()).reduce(max);
    double minL = visibleCandles.map((c) => (c['low'] as num).toDouble()).reduce(min);
    double range = (maxH - minL).clamp(1.0, double.infinity);
    maxH += range * 0.1; minL -= range * 0.1; range = maxH - minL;

    final Paint gridPaint = Paint()..color = Colors.white.withOpacity(0.05);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 5; i++) {
      double price = minL + (range * i / 5);
      double y = chartHeight - (i / 5 * chartHeight);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      textPainter.text = TextSpan(text: price.toStringAsFixed(0), style: const TextStyle(color: Colors.grey, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartWidth + 5, y - textPainter.height / 2));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      double x = i * candleWidth + effectiveOffset;
      if (x + candleWidth < 0 || x > chartWidth) continue;
      double open = (c['open'] as num).toDouble();
      double close = (c['close'] as num).toDouble();
      double high = (c['high'] as num).toDouble();
      double low = (c['low'] as num).toDouble();
      Color color = close >= open ? upColor : downColor;
      canvas.drawLine(Offset(x + candleWidth/2, chartHeight - ((high - minL)/range * chartHeight)), Offset(x + candleWidth/2, chartHeight - ((low - minL)/range * chartHeight)), Paint()..color = color);
      canvas.drawRect(Rect.fromLTRB(x, chartHeight - ((max(open,close)-minL)/range * chartHeight), x + candleWidth*0.8, chartHeight - ((min(open,close)-minL)/range * chartHeight)), Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CandlePainter oldDelegate) => true;
}
