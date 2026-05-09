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
    
    final accounts = userProvider.accounts;
    final selectedAccount = userProvider.selectedAccount;

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('자산 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blueAccent),
            onPressed: () => userProvider.fetchUserData(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => userProvider.fetchUserData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 최상단 계좌 선택기 섹션
              _buildAccountSelectorHeader(context, userProvider, selectedAccount, formatter),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('보유 종목', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (userProvider.holdings.isEmpty)
                      _buildEmptyHoldings()
                    else
                      ...userProvider.holdings.map((h) => _buildStockCard(h, marketData, formatter)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 상단 계좌 선택기 헤더
  Widget _buildAccountSelectorHeader(BuildContext context, UserProvider provider, dynamic selectedAcc, NumberFormat formatter) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D5AF7), Color(0xFF00D2FF)],
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
          GestureDetector(
            onTap: () => _showAccountSelectionSheet(context, provider, formatter),
            child: Row(
              children: [
                Text(
                  selectedAcc?['accountType'] ?? '계좌를 선택하세요',
                  style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            selectedAcc?['accountNumber'] ?? '--- --- ----',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),
          const Text('총 예수금', style: TextStyle(color: Colors.white70, fontSize: 13)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatter.format(selectedAcc?['balance'] ?? 0),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TransferScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('이체', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 계좌 선택 바텀 시트
  void _showAccountSelectionSheet(BuildContext context, UserProvider provider, NumberFormat formatter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161926),
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
                      color: isSelected ? const Color(0xFF2D5AF7).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check : Icons.account_balance_wallet_outlined,
                      color: isSelected ? const Color(0xFF2D5AF7) : Colors.grey,
                    ),
                  ),
                  title: Text(acc['accountType'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(acc['accountNumber'], style: const TextStyle(color: Colors.grey)),
                  trailing: Text(formatter.format(acc['balance']), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildEmptyHoldings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.white10),
          SizedBox(height: 16),
          Text('보유하신 주식이 없습니다.', style: TextStyle(color: Colors.grey)),
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (profit >= 0 ? Colors.redAccent : Colors.blueAccent).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    ticker.substring(0, 1),
                    style: TextStyle(color: profit >= 0 ? Colors.redAccent : Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticker.split('_')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('$qty 주', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatter.format(currentPrice * qty), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Icon(
                    profit >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: profit >= 0 ? Colors.redAccent : Colors.blueAccent,
                    size: 16,
                  ),
                  Text(
                    '${formatter.format(profit.abs())} ($profitPercent%)', 
                    style: TextStyle(color: profit >= 0 ? Colors.redAccent : Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
