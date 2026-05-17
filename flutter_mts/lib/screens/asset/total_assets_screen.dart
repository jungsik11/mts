import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/market_data_provider.dart';
import '../../providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'portfolio_screen.dart';
import 'holding_analysis_screen.dart';

class TotalAssetsScreen extends StatelessWidget {
  const TotalAssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    double krwCash = userProvider.totalCashBalance;
    double usdCash = userProvider.totalUsdCashBalance;

    double krwStockValue = 0;
    double usdStockValue = 0;
    for (var holding in userProvider.holdings) {
      final ticker = holding['ticker'];
      final qty = holding['quantity'] ?? 0;
      final currentPrice = (marketData.prices[ticker]?['price'] ?? holding['avg_price'] ?? 0).toDouble();
      if (ticker.contains('_USD')) {
        usdStockValue += currentPrice * qty;
      } else {
        krwStockValue += currentPrice * qty;
      }
    }

    double totalKrwAssets = krwCash + krwStockValue;
    double totalUsdAssets = usdCash + usdStockValue;
    double totalCombinedAssets = totalKrwAssets + (totalUsdAssets * marketData.usdKrwExchangeRate);

    double totalAssets = totalCombinedAssets;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('내 자산 현황', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => userProvider.fetchUserData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTotalAssetsCard(context, totalAssets, totalKrwAssets, totalUsdAssets, formatter),
              const SizedBox(height: 32),
              const Text('계좌별 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...userProvider.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                return InkWell(
                  onTap: () {
                    userProvider.selectAccount(index);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PortfolioScreen()));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: _buildAccountItem(context, acc, formatter),
                );
              }),
              const SizedBox(height: 32),
              const Text('자산 구성', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildCompositionCard(context, totalKrwAssets, totalUsdAssets, totalAssets, marketData.usdKrwExchangeRate, settings),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HoldingAnalysisScreen()));
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('상세 보유종목 분석 보기', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAssetsCard(BuildContext context, double total, double krwAssets, double usdAssets, NumberFormat formatter) {
    final usdFormatter = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5AF7), Color(0xFF6E8BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D5AF7).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('총 자산 (원화 환산)', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            formatter.format(total),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMiniAssetInfo('원화 자산', krwAssets, formatter),
              Container(width: 1, height: 30, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
              _buildMiniAssetInfo('달러 자산', usdAssets, usdFormatter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAssetInfo(String label, double value, NumberFormat formatter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(formatter.format(value), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAccountItem(BuildContext context, dynamic acc, NumberFormat formatter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.account_balance_wallet_outlined, color: Theme.of(context).primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(UserProvider.getAccountTypeLabel(acc['accountType']), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(acc['accountNumber'], style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatter.format(acc['balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(NumberFormat.currency(locale: 'en_US', symbol: '\$').format(acc['usdBalance'] ?? 0), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionCard(BuildContext context, double krwAssets, double usdAssets, double total, double exchangeRate, SettingsProvider settings) {
    final krwPercent = total == 0 ? 0.0 : (krwAssets / total);
    final usdPercent = total == 0 ? 0.0 : ((usdAssets * exchangeRate) / total);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: (krwPercent * 100).toInt().clamp(1, 100), child: Container(height: 8, decoration: const BoxDecoration(color: Color(0xFF2D5AF7), borderRadius: BorderRadius.horizontal(left: Radius.circular(4))))),
              Expanded(flex: (usdPercent * 100).toInt().clamp(1, 100), child: Container(height: 8, decoration: const BoxDecoration(color: Color(0xFF00D2FF), borderRadius: BorderRadius.horizontal(right: Radius.circular(4))))),
            ],
          ),
          const SizedBox(height: 20),
          _buildCompositionRow('원화 자산', krwPercent, const Color(0xFF2D5AF7)),
          const SizedBox(height: 12),
          _buildCompositionRow('달러 자산', usdPercent, const Color(0xFF00D2FF)),
        ],
      ),
    );
  }

  Widget _buildCompositionRow(String label, double percent, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text('${(percent * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
