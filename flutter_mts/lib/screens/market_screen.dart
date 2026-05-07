import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/market_data_provider.dart';
import 'stock_detail_screen.dart';
import 'package:intl/intl.dart';

class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final marketData = Provider.of<MarketDataProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final sortedTickers = marketData.prices.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stocks', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: sortedTickers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sortedTickers.length,
              itemBuilder: (context, index) {
                final ticker = sortedTickers[index];
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
