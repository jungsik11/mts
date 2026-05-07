import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart';

class StockDetailScreen extends StatefulWidget {
  final String ticker;
  const StockDetailScreen({super.key, required this.ticker});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final TextEditingController _qtyController = TextEditingController(text: "1");
  final TextEditingController _priceController = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MarketDataProvider>(context, listen: false).fetchOrderBook(widget.ticker);
    });
    // Poll order book every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        Provider.of<MarketDataProvider>(context, listen: false).fetchOrderBook(widget.ticker);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _qtyController.dispose();
    _priceController.dispose();
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
      ),
      body: Column(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Available Cash', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text(formatter.format(userProvider.cashBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildOrderBookSection(orderBook, formatter)),
                Container(width: 1, color: Colors.white10),
                Expanded(child: _buildTradeSection(formatter)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderBookSection(Map<String, dynamic> orderBook, NumberFormat formatter) {
    final sells = (orderBook['sells'] as List<dynamic>).reversed.toList();
    final buys = (orderBook['buys'] as List<dynamic>);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Order Book', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        // Sells (Asks) - Blue/Red themed
        Expanded(
          child: ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) {
              if (index >= sells.length) return _buildEmptyRow();
              final order = sells[index];
              return _buildOrderRow(order['price'], order['quantity'], Colors.redAccent.withOpacity(0.1), Colors.redAccent);
            },
          ),
        ),
        const Divider(height: 1, color: Colors.white24),
        // Buys (Bids)
        Expanded(
          child: ListView.builder(
            itemCount: 5,
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: bgColor),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('₩$price', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            Text('$qty', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeSection(NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _priceController,
            decoration: const InputDecoration(labelText: 'Price (KRW)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyController,
            decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _handleOrder("BUY"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('BUY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _handleOrder("SELL"),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('SELL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
        ],
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
          content: Text(result['status'] == 'Order Processed' ? 'Success: ${result['matches'].length} matches' : 'Failed: ${result['reason']}'),
          backgroundColor: result['status'] == 'Order Processed' ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
