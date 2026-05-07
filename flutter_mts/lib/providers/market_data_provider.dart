import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class MarketDataProvider with ChangeNotifier {
  final Map<String, dynamic> _prices = {};
  Map<String, dynamic> get prices => _prices;

  final Map<String, dynamic> _orderBooks = {};
  Map<String, dynamic> getOrderBook(String ticker) =>
      _orderBooks[ticker] ?? {"buys": [], "sells": []};

  WebSocketChannel? _channel;
  bool _isConnecting = false;

  // Throttle notifyListeners to at most once every 300ms to prevent
  // excessive UI rebuilds caused by high-frequency WebSocket messages
  // (price_generator sends 100 tickers per second).
  Timer? _notifyTimer;
  bool _pendingNotify = false;

  static String get _host => kIsWeb
      ? "localhost"
      : (defaultTargetPlatform == TargetPlatform.android
          ? "10.0.2.2"
          : "localhost");
  final String tradingUrl = "http://$_host:9001";

  MarketDataProvider() {
    _fetchInitialPrices();
    _connectWebSocket();
  }

  /// Schedules a notifyListeners() call throttled to 300ms intervals.
  /// Without this, the UI would rebuild ~100 times/sec (once per ticker
  /// per second from price_generator), causing frame drops and freezes.
  void _throttledNotify() {
    _pendingNotify = true;
    if (_notifyTimer?.isActive != true) {
      _notifyTimer = Timer(const Duration(milliseconds: 300), () {
        if (_pendingNotify) {
          _pendingNotify = false;
          notifyListeners();
        }
      });
    }
  }

  Future<void> _fetchInitialPrices({int retryCount = 0}) async {
    try {
      final response = await http
          .get(Uri.parse('$tradingUrl/market/tickers'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (var tickerData in data) {
          _prices[tickerData['ticker']] = tickerData;
        }
        notifyListeners();
      } else {
        throw Exception("Status ${response.statusCode}");
      }
    } catch (e) {
      if (retryCount < 10) {
        final nextRetry = retryCount + 1;
        final delay = Duration(seconds: nextRetry * 2);
        Future.delayed(delay, () => _fetchInitialPrices(retryCount: nextRetry));
      }
    }
  }

  void _connectWebSocket() {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_host:9001/ws'),
      );

      _channel!.stream.listen(
        (message) {
          final decoded = jsonDecode(message);
          final channel = decoded['channel'];
          final data = decoded['data'];

          if (channel == 'market_prices') {
            final ticker = data['ticker'];
            // Merge new data with existing data to preserve fields like 'name'
            if (_prices.containsKey(ticker)) {
              _prices[ticker] = <String, dynamic>{..._prices[ticker], ...data};
            } else {
              _prices[ticker] = data;
            }
            // Use throttled notify: prevents ~100 rebuilds/sec (one per ticker).
            // UI will update at most every 300ms regardless of message frequency.
            _throttledNotify();
          }
          // trade_updates: no UI rebuild needed here; price changes are
          // already reflected via the market_prices channel.
        },
        onError: (err) {
          _isConnecting = false;
          Future.delayed(
              const Duration(seconds: 5), () => _connectWebSocket());
        },
        onDone: () {
          _isConnecting = false;
          Future.delayed(
              const Duration(seconds: 5), () => _connectWebSocket());
        },
      );
      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
    }
  }

  Future<void> fetchOrderBook(String ticker) async {
    try {
      final response =
          await http.get(Uri.parse('$tradingUrl/order/book/$ticker'));
      if (response.statusCode == 200) {
        _orderBooks[ticker] = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (e) {
      // Silently fail; order book will remain empty
    }
  }

  Future<List<dynamic>> fetchCandles(String ticker, String interval) async {
    try {
      final response = await http.get(Uri.parse('$tradingUrl/market/candles/$ticker?interval=$interval'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      // Silently fail
    }
    return [];
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
