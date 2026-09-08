import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/user_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/market_data_provider.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _refreshData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.fetchTradeHistory();
    userProvider.fetchOpenOrders();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    // Combine trades and open orders
    final List<Map<String, dynamic>> allItems = [];
    
    // 1. Add Open Orders (Pending)
    for (var o in userProvider.openOrders) {
      allItems.add({
        ...o,
        'isMatched': false,
      });
    }
    
    // 2. Add Matched Trades
    for (var t in userProvider.tradeHistory) {
      allItems.add({
        ...t,
        'isMatched': true,
      });
    }
    
    // Sort by timestamp desc
    allItems.sort((a, b) => _toMs(b['timestamp']).compareTo(_toMs(a['timestamp'])));

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('주문/체결 내역', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              userProvider.fetchTradeHistory();
              userProvider.fetchOpenOrders();
            },
          ),
        ],
      ),
      body: allItems.isEmpty
          ? const Center(child: Text('주문 내역이 없습니다.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: allItems.length,
              itemBuilder: (context, index) {
                final item = allItems[index];
                final isMatched = item['isMatched'] == true;
                final isBuy = item['side'] == 'BUY' || (item['buyerId'] == userProvider.userId);
                final color = isBuy ? settings.upColor : settings.downColor;
                final marketData = Provider.of<MarketDataProvider>(context, listen: false);
                final ticker = item['ticker'] ?? '-';
                final stockName = marketData.prices[ticker]?['name'] ?? ticker;
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isBuy ? '매수' : '매도',
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(stockName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(ticker, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMatched ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isMatched ? '체결완료' : '미체결',
                              style: TextStyle(
                                color: isMatched ? Colors.green : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailColumn('가격', formatter.format(item['price'] ?? 0)),
                          _buildDetailColumn('수량', '${item['quantity']}주'),
                          _buildDetailColumn('시간', _formatTime(item['timestamp'])),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
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

  String _formatTime(dynamic ts) {
    if (ts == null) return '--:--';
    final ms = _toMs(ts);
    final dt = DateTime.fromMillisecondsSinceEpoch(ms).toUtc().add(const Duration(hours: 9));
    return DateFormat('MM/dd HH:mm').format(dt);
  }
}
