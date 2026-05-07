import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class MarketDataProvider with ChangeNotifier {
  Map<String, dynamic> _prices = {};
  Map<String, dynamic> get prices => _prices;

  Map<String, dynamic> _orderBooks = {};
  Map<String, dynamic> getOrderBook(String ticker) => _orderBooks[ticker] ?? {"buys": [], "sells": []};

  WebSocketChannel? _channel;
  final String tradingUrl = "http://localhost:9001";

  MarketDataProvider() {
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://localhost:9001/ws'),
      );

      _channel!.stream.listen((message) {
        final decoded = jsonDecode(message);
        final channel = decoded['channel'];
        final data = decoded['data'];

        if (channel == 'market_prices') {
          final ticker = data['ticker'];
          _prices[ticker] = data;
          notifyListeners();
        } else if (channel == 'trade_updates') {
          // data is like {"ticker": "SAMSUNG_MOCK", "price": 75200, "quantity": 10, "timestamp": ...}
          // We could use this to update order book immediately or show toast
          notifyListeners();
        }
      }, onError: (err) {
        debugPrint("WS Error: $err");
        Future.delayed(const Duration(seconds: 5), () => _connectWebSocket());
      }, onDone: () {
        debugPrint("WS Closed");
        Future.delayed(const Duration(seconds: 5), () => _connectWebSocket());
      });
    } catch (e) {
      debugPrint("WS Connection Error: $e");
    }
  }

  Future<void> fetchOrderBook(String ticker) async {
    try {
      final response = await http.get(Uri.parse('$tradingUrl/order/book/$ticker'));
      if (response.statusCode == 200) {
        _orderBooks[ticker] = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching order book: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
