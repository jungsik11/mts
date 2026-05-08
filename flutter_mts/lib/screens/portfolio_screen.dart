import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/market_data_provider.dart';
import 'package:intl/intl.dart';
import 'transfer_screen.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      appBar: AppBar(
        title: const Text('보유 자산', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: () {
              userProvider.logout();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => userProvider.fetchUserData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('보유 계좌', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...userProvider.accounts.map((acc) => _buildAccountCard(context, acc, formatter)),
              const SizedBox(height: 32),
              const Text('보유 주식', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (userProvider.holdings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('보유하신 주식이 없습니다.', style: TextStyle(color: Colors.grey))),
                )
              else
                ...userProvider.holdings.map((h) => _buildStockCard(h, marketData, formatter)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, dynamic acc, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: acc['isPrimary'] == true ? Colors.blue.withOpacity(0.5) : Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(acc['accountType'], style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      if (acc['isPrimary'] == true)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                          child: const Text('주계좌', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(acc['accountNumber'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text(formatter.format(acc['balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const TransferScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('이체하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockCard(dynamic holding, MarketDataProvider marketData, NumberFormat formatter) {
    final ticker = holding['ticker'];
    final qty = holding['quantity'];
    final avgPrice = holding['avg_price'];
    final currentPrice = (marketData.prices[ticker]?['price'] ?? avgPrice ?? 0).toDouble();
    final profit = (currentPrice - (avgPrice ?? 0)) * qty;
    final profitPercent = (avgPrice == null || avgPrice == 0) ? "0.00" : ((currentPrice - avgPrice) / avgPrice * 100).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ticker.split('_')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('$qty 주', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatter.format(currentPrice * qty), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${profit >= 0 ? '+' : ''}${formatter.format(profit)} ($profitPercent%)', 
                style: TextStyle(color: profit >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
