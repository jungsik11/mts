import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/market_data_provider.dart';
import 'stock_detail_screen.dart';
import '../providers/settings_provider.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final double safeAreaTop = MediaQuery.of(context).padding.top;

    // Calculate total asset value (cash + stocks)
    double stockValue = 0;
    for (var holding in userProvider.holdings) {
      final ticker = holding['ticker'];
      final qty = holding['quantity'] as int;
      final currentPrice = (marketData.prices[ticker]?['price'] ?? holding['avg_price'] ?? 0).toDouble();
      stockValue += currentPrice * qty;
    }
    double totalAssets = userProvider.cashBalance + stockValue;

    return RefreshIndicator(
      onRefresh: () async {
        await userProvider.fetchUserData();
        await marketData.fetchTickers();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: safeAreaTop),
            _buildHeader(context, totalAssets, userProvider.cashBalance, formatter, userProvider.primaryAccount),
            if (userProvider.holdings.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 12),
                child: Text('보유 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              _buildHoldingsList(context, userProvider, marketData, formatter, settings),
            ],
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('관심 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildWatchlist(context, userProvider, marketData, formatter, settings),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('최근 활동', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            _buildRecentActivity(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, double total, double cash, NumberFormat formatter, Map<String, dynamic>? primaryAcc) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5AF7), Color(0xFF00D2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5AF7).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                    '${UserProvider.getAccountTypeLabel(primaryAcc['accountType'])} ${primaryAcc['accountNumber']}',
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

  Widget _buildHoldingsList(BuildContext context, UserProvider userProvider, MarketDataProvider marketData, NumberFormat formatter, SettingsProvider settings) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: userProvider.holdings.length,
        itemBuilder: (context, index) {
          final holding = userProvider.holdings[index];
          final ticker = holding['ticker'];
          final qty = holding['quantity'] as int;
          final data = marketData.prices[ticker] ?? {};
          final currentPrice = (data['price'] ?? holding['avg_price'] ?? 0).toDouble();
          final displayName = data['name'] ?? ticker;
          final profitPercent = holding['avg_price'] != null && holding['avg_price'] > 0
              ? ((currentPrice - holding['avg_price']) / holding['avg_price'] * 100)
              : 0.0;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockDetailScreen(ticker: ticker)),
            ),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(displayName, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      Text('${qty}주', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(formatter.format(currentPrice * qty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    '${profitPercent > 0 ? '+' : ''}${profitPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: profitPercent > 0 ? settings.upColor : (profitPercent < 0 ? settings.downColor : Colors.white70),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWatchlist(BuildContext context, UserProvider userProvider, MarketDataProvider marketData, NumberFormat formatter, SettingsProvider settings) {
    final watchlistTickers = userProvider.watchlist.toList()..sort();
    
    if (watchlistTickers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('관심 종목이 없습니다.\n주식 탭에서 별을 눌러 추가해보세요.', 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey)
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: watchlistTickers.length,
        itemBuilder: (context, index) {
          final ticker = watchlistTickers[index];
          final data = marketData.prices[ticker] ?? {};
          final change = data['change_percent'] ?? 0.0;
          final price = data['price'] ?? 0;
          final displayName = data['name'] ?? ticker;

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => StockDetailScreen(ticker: ticker)),
            ),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(displayName, 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(ticker, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(formatter.format(price), style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  Text('${change > 0 ? '+' : ''}$change%', 
                    style: TextStyle(color: change > 0 ? settings.upColor : (change < 0 ? settings.downColor : Colors.white70), fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final trades = userProvider.tradeHistory.take(3).toList();
          if (trades.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('최근 주문 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }

            return Column(
              children: trades.map((trade) {
                final isBuyer = trade['buyerId'] == userProvider.userId;
                final color = isBuyer ? Colors.redAccent : Colors.blueAccent;
                final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
                
                dynamic ts = trade['timestamp'];
                String time = "";
                try {
                  if (ts is int) {
                    time = DateFormat('MM/dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
                  } else if (ts is String && ts.isNotEmpty) {
                    time = DateFormat('MM/dd HH:mm').format(DateTime.parse(ts));
                  } else {
                    time = "--/-- --:--";
                  }
                } catch (e) {
                  time = "--/-- --:--";
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(isBuyer ? Icons.add : Icons.remove, color: color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((trade['ticker'] ?? 'Unknown').split('_')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatter.format(trade['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${trade['quantity'] ?? 0}주', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
        },
      ),
    );
  }
}
