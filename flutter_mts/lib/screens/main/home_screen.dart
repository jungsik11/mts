import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/market_data_provider.dart';
import '../market/stock_detail_screen.dart';
import '../asset/holding_analysis_screen.dart';
import '../../providers/settings_provider.dart';
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

    double krwStockValue = 0;
    double usdStockValue = 0;
    for (var holding in userProvider.holdings) {
      final ticker = holding['ticker'];
      final qty = (holding['quantity'] as int) + (holding['locked_quantity'] as int? ?? 0);
      final currentPrice = (marketData.prices[ticker]?['price'] ?? holding['avg_price'] ?? 0).toDouble();
      if (RegExp(r'[a-zA-Z]').hasMatch(ticker)) {
        usdStockValue += currentPrice * qty;
      } else {
        krwStockValue += currentPrice * qty;
      }
    }

    double krwCash = userProvider.totalCashBalance;
    double usdCash = userProvider.totalUsdCashBalance;
    double totalKrwAssets = krwCash + krwStockValue;
    double totalUsdAssets = usdCash + usdStockValue;
    double totalCombinedAssets = totalKrwAssets + (totalUsdAssets * marketData.usdKrwExchangeRate);

    final krwHoldings = userProvider.holdings.where((h) => !RegExp(r'[a-zA-Z]').hasMatch(h['ticker'])).toList();
    final usdHoldings = userProvider.holdings.where((h) => RegExp(r'[a-zA-Z]').hasMatch(h['ticker'])).toList();

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
            _buildHeader(context, totalCombinedAssets, totalKrwAssets, krwCash, krwStockValue, totalUsdAssets, usdCash, usdStockValue, formatter, userProvider),
            _buildMarketSummary(context, marketData),
            if (krwHoldings.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('국내 보유 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildHoldingsList(context, krwHoldings, marketData, formatter, settings),
            ],
            if (usdHoldings.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('해외 보유 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildHoldingsList(context, usdHoldings, marketData, NumberFormat.currency(locale: 'en_US', symbol: '\$'), settings),
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

  Widget _buildHeader(BuildContext context, double totalCombined, double totalKrw, double krwCash, double krwStock, double totalUsd, double usdCash, double usdStock, NumberFormat formatter, UserProvider userProvider) {
    final usdFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
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
          const Text('총 자산 (원화 환산)', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(formatter.format(totalCombined), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('국내 자산', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(formatter.format(totalKrw), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('예수금: ${formatter.format(krwCash)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('주식: ${formatter.format(krwStock)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('해외 자산', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(usdFormatter.format(totalUsd), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('예수금: ${usdFormatter.format(usdCash)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('주식: ${usdFormatter.format(usdStock)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketSummary(BuildContext context, MarketDataProvider marketData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.currency_exchange, color: Colors.orange, size: 16),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('미국 달러 환율', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('USD / KRW', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₩${marketData.usdKrwExchangeRate.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Row(
                children: [
                  Icon(Icons.arrow_drop_up, color: Colors.redAccent, size: 14),
                  Text('0.15%', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAccountSelectionSheet(BuildContext context, UserProvider provider, NumberFormat formatter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Text('계좌 선택', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              ...provider.accounts.asMap().entries.map((entry) {
                int idx = entry.key;
                dynamic acc = entry.value;
                bool isSelected = provider.selectedAccountIndex == idx;
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.account_balance_wallet_outlined,
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                  ),
                  title: Text(UserProvider.getAccountTypeLabel(acc['accountType']), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(acc['accountNumber'], style: const TextStyle(color: Colors.grey)),
                  trailing: Text(formatter.format(acc['balance'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    provider.selectAccount(idx);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
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

  Widget _buildHoldingsList(BuildContext context, List<dynamic> holdings, MarketDataProvider marketData, NumberFormat formatter, SettingsProvider settings) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: holdings.length,
        itemBuilder: (context, index) {
          final holding = holdings[index];
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
                final isUsStock = RegExp(r'[a-zA-Z]').hasMatch(trade['ticker'] ?? '');
                final currentFormatter = isUsStock 
                    ? NumberFormat.currency(locale: 'en_US', symbol: '\$')
                    : NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
                
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
                          Text(currentFormatter.format(trade['price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
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
