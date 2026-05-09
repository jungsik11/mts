import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
      length: 5, 
      vsync: this, 
      initialIndex: widget.initialTabIndex,
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final marketProvider = Provider.of<MarketDataProvider>(context, listen: false);
      marketProvider.fetchOrderBook(widget.ticker);
      marketProvider.fetchMarketTrades(widget.ticker);
      marketProvider.setLastViewedTicker(widget.ticker);
      Provider.of<UserProvider>(context, listen: false).fetchTradeHistory(ticker: widget.ticker);
      _updateCandles();
    });
    
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        Provider.of<MarketDataProvider>(context, listen: false).fetchOrderBook(widget.ticker);
        Provider.of<MarketDataProvider>(context, listen: false).fetchMarketTrades(widget.ticker);
        Provider.of<UserProvider>(context, listen: false).fetchTradeHistory(ticker: widget.ticker);
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

  // --- 체결 탭 ---
  Widget _buildExecutionsTab(UserProvider userProvider, MarketDataProvider marketData, NumberFormat formatter) {
    final trades = marketData.getMarketTrades(widget.ticker);
    return ListView.builder(
      itemCount: trades.length,
      itemBuilder: (context, index) {
        final trade = trades[index];
        return ListTile(
          title: Text(formatter.format(trade['price'] ?? 0)),
          subtitle: Text('수량: ${trade['quantity']}'),
          trailing: Text(trade['timestamp'].toString()),
        );
      },
    );
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

  void _handleOrder(String side) async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;
    if (qty <= 0 || price <= 0) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await userProvider.placeOrder(ticker: widget.ticker, quantity: qty, price: price, side: side);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['status'] == 'Order Processed' ? '주문 성공' : '주문 실패'), backgroundColor: result['status'] == 'Order Processed' ? Colors.green : Colors.red));
      userProvider.fetchTradeHistory(ticker: widget.ticker);
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
