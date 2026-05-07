import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/market_data_provider.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    // Calculate total asset value (cash + stocks)
    double stockValue = 0;
    for (var holding in userProvider.holdings) {
      final ticker = holding['ticker'];
      final qty = holding['quantity'] as int;
      final currentPrice = (marketData.prices[ticker]?['price'] ?? holding['avg_price'] ?? 0).toDouble();
      stockValue += currentPrice * qty;
    }
    double totalAssets = userProvider.cashBalance + stockValue;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, totalAssets, userProvider.cashBalance, formatter, userProvider.primaryAccount),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('관심 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildTopMovers(marketData, formatter),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('최근 활동', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double total, double cash, NumberFormat formatter, Map<String, dynamic>? primaryAcc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D5AF7), Color(0xFF00D2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('총 자산', style: TextStyle(color: Colors.white70, fontSize: 16)),
              if (primaryAcc != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${primaryAcc['accountType']} ${primaryAcc['accountNumber']}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(formatter.format(total), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildMiniBalance('예수금', formatter.format(cash)),
              const SizedBox(width: 40),
              _buildMiniBalance('주식 평가금', formatter.format(total - cash)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniBalance(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTopMovers(MarketDataProvider marketData, NumberFormat formatter) {
    final tickers = marketData.prices.keys.toList();
    if (tickers.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('시장 데이터가 없습니다')));
    
    // STABLE SORT: Alphabetical so they don't jump
    tickers.sort();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tickers.length > 5 ? 5 : tickers.length,
        itemBuilder: (context, index) {
          final ticker = tickers[index];
          final data = marketData.prices[ticker];
          final change = data['change_percent'] ?? 0.0;
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D2D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ticker.split('_')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('${change > 0 ? '+' : ''}$change%', 
                  style: TextStyle(color: change >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(
        child: Text('최근 주문 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
