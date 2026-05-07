import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});

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
    _tabController = TabController(length: 4, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketDataProvider>(context, listen: false).fetchOrderBook(widget.ticker);
      Provider.of<UserProvider>(context, listen: false).fetchTradeHistory(ticker: widget.ticker);
      _updateCandles();
    });
    
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        Provider.of<MarketDataProvider>(context, listen: false).fetchOrderBook(widget.ticker);
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
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    final priceData = marketData.prices[widget.ticker] ?? {"price": 0, "change_percent": 0.0};
    final currentPrice = priceData['price'];
    final changePercent = priceData['change_percent'];

    if (_priceController.text.isEmpty && currentPrice > 0) {
      _priceController.text = currentPrice.toString();
    }

    final orderBook = marketData.getOrderBook(widget.ticker);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ticker.replaceAll('_MOCK', '')),
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '차트'),
            Tab(text: '매수'),
            Tab(text: '매도'),
            Tab(text: '체결'),
          ],
          indicatorColor: Colors.blueAccent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChartTab(formatter, currentPrice, changePercent),
                _buildBuyTab(orderBook, formatter),
                _buildSellTab(orderBook, formatter),
                _buildExecutionsTab(userProvider, formatter),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab(NumberFormat formatter, dynamic currentPrice, dynamic changePercent) {
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
                    style: TextStyle(color: changePercent >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 18)),
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
            child: _buildCandleChartSection(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                '확대/축소: 핀치  |  이동: 드래그',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16, color: Colors.blueAccent),
                onPressed: () => setState(() {
                  _candleWidth = 10.0;
                  _scrollOffset = 0.0;
                }),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuyTab(Map<String, dynamic> orderBook, NumberFormat formatter) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildOrderBookSection(orderBook, formatter)),
        Container(width: 1, color: Colors.white10),
        Expanded(flex: 1, child: _buildTradeSection(formatter, "BUY")),
      ],
    );
  }

  Widget _buildSellTab(Map<String, dynamic> orderBook, NumberFormat formatter) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildOrderBookSection(orderBook, formatter)),
        Container(width: 1, color: Colors.white10),
        Expanded(flex: 1, child: _buildTradeSection(formatter, "SELL")),
      ],
    );
  }

  Widget _buildExecutionsTab(UserProvider userProvider, NumberFormat formatter) {
    final trades = userProvider.tradeHistory;
    final userId = userProvider.userId;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text('나의 체결 내역', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        // Table Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1),   // Side
              1: FlexColumnWidth(1.8), // Price
              2: FlexColumnWidth(1),   // Exec Qty
              3: FlexColumnWidth(1),   // Unexec Qty
              4: FlexColumnWidth(1.4), // Time
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: const Border(bottom: BorderSide(color: Colors.white24)),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('구분', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('체결가', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('체결 수량', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('미체결 수량', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4), child: Text('시간', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: trades.isEmpty 
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.white10),
                    SizedBox(height: 16),
                    Text('체결 내역이 없습니다.', style: TextStyle(color: Colors.white24)),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: trades.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final trade = trades[index];
                  final isBuyer = trade['buyerId'] == userId;
                  final side = isBuyer ? "매수" : "매도";
                  final color = isBuyer ? Colors.redAccent : Colors.blueAccent;
                  final time = DateFormat('HH:mm:ss').format(DateTime.parse(trade['timestamp']));

                  return Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1),
                      1: FlexColumnWidth(1.8),
                      2: FlexColumnWidth(1),
                      3: FlexColumnWidth(1),
                      4: FlexColumnWidth(1.4),
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            child: Text(side, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            child: Text(formatter.format(trade['price']), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            child: Text('${trade['quantity']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            child: Text('0', style: TextStyle(fontSize: 12, color: Colors.white38)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                            child: Text(time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildIntervalSelector() {
    return Row(
      children: ["1m", "1h", "1d"].map((interval) {
        bool isSelected = _selectedInterval == interval;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedInterval = interval;
              _scrollOffset = 0.0; // Reset scroll on interval change
            });
            _updateCandles();
          },
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              interval.toUpperCase(),
              style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCandleChartSection() {
    return GestureDetector(
      onScaleStart: (details) {
        _baseCandleWidth = _candleWidth;
      },
      onScaleUpdate: (details) {
        setState(() {
          // Handle Zoom
          _candleWidth = (_baseCandleWidth * details.scale).clamp(2.0, 50.0);
          
          // Handle Pan
          _scrollOffset += details.focalPointDelta.dx;
        });
      },
      onLongPressStart: (details) => setState(() => _crosshairPos = details.localPosition),
      onLongPressMoveUpdate: (details) => setState(() => _crosshairPos = details.localPosition),
      onLongPressEnd: (_) => setState(() => _crosshairPos = null),
      onTapDown: (_) => setState(() => _crosshairPos = null),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: CandlePainter(
              candles: _candles, 
              interval: _selectedInterval,
              candleWidth: _candleWidth,
              scrollOffset: _scrollOffset,
              crosshairPos: _crosshairPos,
            ),
          );
        }
      ),
    );
  }

  Widget _buildOrderBookSection(Map<String, dynamic> orderBook, NumberFormat formatter) {
    final sells = (orderBook['sells'] as List<dynamic>).reversed.toList();
    final buys = (orderBook['buys'] as List<dynamic>);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Text('호가', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              if (index >= sells.length) return _buildEmptyRow();
              final order = sells[index];
              return _buildOrderRow(order['price'], order['quantity'], Colors.redAccent.withOpacity(0.1), Colors.redAccent);
            },
          ),
        ),
        const Divider(height: 1, color: Colors.white24),
        Expanded(
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              if (index >= buys.length) return _buildEmptyRow();
              final order = buys[index];
              return _buildOrderRow(order['price'], order['quantity'], Colors.greenAccent.withOpacity(0.1), Colors.greenAccent);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRow() => Container(height: 40);

  Widget _buildOrderRow(dynamic price, dynamic qty, Color bgColor, Color textColor) {
    return InkWell(
      onTap: () => setState(() => _priceController.text = price.toString()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(color: bgColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₩$price', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
            Text('$qty', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeSection(NumberFormat formatter, String side) {
    final userProvider = Provider.of<UserProvider>(context);
    final cash = userProvider.cashBalance;
    final inputPrice = int.tryParse(_priceController.text) ?? 0;
    
    int maxQty = 0;
    String maxLabel = "";
    if (side == "BUY") {
      maxQty = inputPrice > 0 ? (cash ~/ inputPrice) : 0;
      maxLabel = "최대 매수 가능";
    } else {
      final holding = userProvider.holdings.firstWhere(
        (h) => h['ticker'] == widget.ticker, 
        orElse: () => {"quantity": 0}
      );
      maxQty = holding['quantity'] as int;
      maxLabel = "보유 수량";
    }

    final isBuy = side == "BUY";
    final btnColor = isBuy ? Colors.redAccent : Colors.blueAccent;
    final btnLabel = isBuy ? '매수' : '매도';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Text('$btnLabel 주문', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            const SizedBox(height: 20),
            TextField(
              controller: _priceController,
              onChanged: (val) => setState(() {}), // Recalculate max qty on price change
              decoration: const InputDecoration(labelText: '가격 (원)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(labelText: '수량', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (maxQty > 0) {
                  setState(() => _qtyController.text = maxQty.toString());
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(maxLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(
                      '${NumberFormat('#,###').format(maxQty)}주',
                      style: TextStyle(color: btnColor, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _handleOrder(side),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(btnLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleOrder(String side) async {
    final qty = int.tryParse(_qtyController.text) ?? 0;
    final price = int.tryParse(_priceController.text) ?? 0;

    if (qty <= 0 || price <= 0) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await userProvider.placeOrder(
      ticker: widget.ticker,
      quantity: qty,
      price: price,
      side: side,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['status'] == 'Order Processed' ? '주문 성공: ${result['matches'].length}건 체결' : '주문 실패: ${result['reason']}'),
          backgroundColor: result['status'] == 'Order Processed' ? Colors.green : Colors.red,
        ),
      );
      // Refresh trade history after order
      userProvider.fetchTradeHistory(ticker: widget.ticker);
    }
  }
}

class CandlePainter extends CustomPainter {
  final List<dynamic> candles;
  final String interval;
  final double candleWidth;
  final double scrollOffset;
  final Offset? crosshairPos;

  CandlePainter({
    required this.candles, 
    required this.interval,
    required this.candleWidth,
    required this.scrollOffset,
    this.crosshairPos,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    const double marginBottom = 30.0;
    const double marginRight = 60.0;
    final double chartWidth = size.width - marginRight;
    final double chartHeight = size.height - marginBottom;

    double baseScroll = chartWidth - (candles.length * candleWidth);
    double effectiveOffset = baseScroll + scrollOffset;

    List<dynamic> visibleCandles = [];
    for (int i = 0; i < candles.length; i++) {
      double x = i * candleWidth + effectiveOffset;
      if (x + candleWidth >= 0 && x <= chartWidth) {
        visibleCandles.add(candles[i]);
      }
    }

    if (visibleCandles.isEmpty) visibleCandles = candles;

    double maxH = visibleCandles.map((c) => (c['high'] as num).toDouble()).reduce(max);
    double minL = visibleCandles.map((c) => (c['low'] as num).toDouble()).reduce(min);
    
    double range = maxH - minL;
    if (range == 0) range = 1;
    maxH += range * 0.15;
    minL -= range * 0.15;
    range = maxH - minL;

    final Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    const int yDivisions = 5;
    for (int i = 0; i <= yDivisions; i++) {
      double price = minL + (range * i / yDivisions);
      double y = chartHeight - (i / yDivisions * chartHeight);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
      textPainter.text = TextSpan(
        text: price.toStringAsFixed(0),
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartWidth + 5, y - textPainter.height / 2));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, chartWidth, chartHeight));

    double spacing = candleWidth * 0.2;
    double actualCandleWidth = max(1.0, candleWidth - spacing);

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      double x = i * candleWidth + effectiveOffset;
      
      if (x + candleWidth < 0 || x > chartWidth) continue;

      double open = (candle['open'] as num).toDouble();
      double close = (candle['close'] as num).toDouble();
      double high = (candle['high'] as num).toDouble();
      double low = (candle['low'] as num).toDouble();

      bool isUp = close >= open;
      Color color = isUp ? Colors.redAccent : Colors.blueAccent;
      
      Paint paint = Paint()..color = color..style = PaintingStyle.fill;
      Paint wickPaint = Paint()..color = color..strokeWidth = max(1, candleWidth * 0.05);

      canvas.drawLine(
        Offset(x + actualCandleWidth / 2, chartHeight - ((high - minL) / range * chartHeight)),
        Offset(x + actualCandleWidth / 2, chartHeight - ((low - minL) / range * chartHeight)),
        wickPaint,
      );

      double bodyTop = chartHeight - ((max(open, close) - minL) / range * chartHeight);
      double bodyBottom = chartHeight - ((min(open, close) - minL) / range * chartHeight);
      if (bodyTop == bodyBottom) bodyBottom += 1; 

      canvas.drawRect(Rect.fromLTRB(x, bodyTop, x + actualCandleWidth, bodyBottom), paint);
      
      if (i % (max(1, 50 ~/ (chartWidth / (candleWidth * 10))).toInt()) == 0) {
        canvas.restore(); 
        final dynamic ts = candle['timestamp'];
        if (ts != null) {
          DateTime dt = ts < 0 ? DateTime.now().add(Duration(milliseconds: ts.toInt())) : DateTime.fromMillisecondsSinceEpoch(ts.toInt());
          String label = interval == "1d" ? DateFormat('MM/dd').format(dt) : DateFormat('HH:mm').format(dt);
          textPainter.text = TextSpan(text: label, style: const TextStyle(color: Colors.grey, fontSize: 9));
          textPainter.layout();
          textPainter.paint(canvas, Offset(x - textPainter.width / 2, chartHeight + 5));
        }
        canvas.save();
        canvas.clipRect(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
      }
    }
    canvas.restore();

    if (crosshairPos != null && crosshairPos!.dx < chartWidth && crosshairPos!.dy < chartHeight) {
      final Paint crossPaint = Paint()..color = Colors.white54..strokeWidth = 1..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, crosshairPos!.dy), Offset(chartWidth, crosshairPos!.dy), crossPaint);
      canvas.drawLine(Offset(crosshairPos!.dx, 0), Offset(crosshairPos!.dx, chartHeight), crossPaint);
      
      double hoveredPrice = maxH - (crosshairPos!.dy / chartHeight * range);
      textPainter.text = TextSpan(
        text: hoveredPrice.toStringAsFixed(0),
        style: const TextStyle(color: Colors.white, fontSize: 10, backgroundColor: Colors.blueAccent),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chartWidth + 5, crosshairPos!.dy - textPainter.height / 2));
    }

    final Paint axisPaint = Paint()..color = Colors.white24..strokeWidth = 1;
    canvas.drawLine(Offset(0, chartHeight), Offset(chartWidth, chartHeight), axisPaint);
    canvas.drawLine(Offset(chartWidth, 0), Offset(chartWidth, chartHeight), axisPaint);
  }

  @override
  bool shouldRepaint(CandlePainter oldDelegate) => true;
}
