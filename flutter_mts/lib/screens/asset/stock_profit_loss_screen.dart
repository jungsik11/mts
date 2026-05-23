import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/market_data_provider.dart';
import 'package:intl/intl.dart';

class StockProfitLossScreen extends StatefulWidget {
  const StockProfitLossScreen({super.key});

  @override
  State<StockProfitLossScreen> createState() => _StockProfitLossScreenState();
}

class _StockProfitLossScreenState extends State<StockProfitLossScreen> {
  String _sortCriteria = 'NAME'; // 정렬 기준: 'NAME', 'RETURN'

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final selectedAccount = userProvider.selectedAccount;
    
    // 계산 로직 (선택된 계좌 기준)
    double totalEvaluation = 0;
    double totalPurchase = 0;
    
    List<Map<String, dynamic>> enrichedHoldings = [];

    for (var h in userProvider.holdings) {
      final ticker = h['ticker'];
      final qty = h['quantity'] as int;
      final avgPrice = (h['avg_price'] ?? 0).toDouble();
      final currentPrice = (marketData.prices[ticker]?['price'] ?? avgPrice).toDouble();
      
      totalPurchase += avgPrice * qty;
      totalEvaluation += currentPrice * qty;

      final percent = avgPrice == 0 ? 0.0 : ((currentPrice - avgPrice) / avgPrice * 100);
      enrichedHoldings.add({
        'original': h,
        'tickerName': ticker.split('_')[0],
        'percent': percent,
      });
    }
    
    final totalProfit = totalEvaluation - totalPurchase;
    final totalProfitPercent = totalPurchase == 0 ? 0.0 : (totalProfit / totalPurchase * 100);

    // 정렬 라벨 계산 (오전 8시 ~ 오후 8시는 가나다순, 그 외는 ABC순)
    final now = DateTime.now();
    final nameSortLabel = (now.hour >= 8 && now.hour < 20) ? '가나다순' : 'ABC순';

    // 정렬 적용
    if (_sortCriteria == 'NAME') {
      enrichedHoldings.sort((a, b) => a['tickerName'].compareTo(b['tickerName']));
    } else {
      // 수익률순 (내림차순)
      enrichedHoldings.sort((a, b) => b['percent'].compareTo(a['percent']));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        title: const Text('주식 잔고 · 손익', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 계좌 선택 헤더 (PortfolioScreen과 일관성 유지)
            _buildAccountSelectorHeader(context, userProvider, selectedAccount, formatter),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. 총 손익 요약 카드
                  _buildSummaryCard(formatter, totalEvaluation, totalProfit, totalProfitPercent, totalPurchase),
                  
                  const SizedBox(height: 32),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('종목별 상세 손익', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D2D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: DropdownButton<String>(
                              value: _sortCriteria,
                              dropdownColor: const Color(0xFF1A1D2D),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              underline: const SizedBox(),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16),
                              items: [
                                DropdownMenuItem(value: 'NAME', child: Text(nameSortLabel)),
                                const DropdownMenuItem(value: 'RETURN', child: Text('수익률순')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _sortCriteria = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${userProvider.holdings.length} 종목', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  if (userProvider.holdings.isEmpty)
                    _buildEmptyState()
                  else
                    ...enrichedHoldings.map((eh) => _buildProfitDetailCard(eh['original'], marketData, formatter)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 계좌 선택기 헤더
  Widget _buildAccountSelectorHeader(BuildContext context, UserProvider provider, dynamic selectedAcc, NumberFormat formatter) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: InkWell(
        onTap: () => _showAccountSelectionSheet(context, provider, formatter),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      UserProvider.getAccountTypeLabel(selectedAcc?['accountType']) ?? '계좌를 선택하세요',
                      style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.blueAccent, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  selectedAcc?['accountNumber'] ?? '--- --- ----',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('예수금', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(
                  formatter.format(selectedAcc?['balance'] ?? 0),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
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
                  title: Text(UserProvider.getAccountTypeLabel(acc['accountType']), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildSummaryCard(NumberFormat formatter, double totalEval, double profit, double percent, double purchase) {
    final isPositive = profit >= 0;
    final color = isPositive ? const Color(0xFFFF4B4B) : const Color(0xFF2D5AF7);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Text('총 평가금액', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            formatter.format(totalEval),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('총 손익', formatter.format(profit), color),
              _buildSummaryItem('수익률', '${isPositive ? '+' : ''}${percent.toStringAsFixed(2)}%', color),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('총 매입금액', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text(formatter.format(purchase), style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildProfitDetailCard(dynamic h, MarketDataProvider marketData, NumberFormat formatter) {
    final ticker = h['ticker'];
    final qty = h['quantity'] as int;
    final avgPrice = (h['avg_price'] ?? 0).toDouble();
    final currentPrice = (marketData.prices[ticker]?['price'] ?? avgPrice).toDouble();
    final evalAmount = currentPrice * qty;
    final profit = (currentPrice - avgPrice) * qty;
    final percent = avgPrice == 0 ? 0.0 : ((currentPrice - avgPrice) / avgPrice * 100);
    final isPositive = profit >= 0;
    final color = isPositive ? const Color(0xFFFF4B4B) : const Color(0xFF2D5AF7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ticker.split('_')[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${isPositive ? '+' : ''}${formatter.format(profit)} (${percent.toStringAsFixed(2)}%)',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('평가금액', formatter.format(evalAmount), isBold: true),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildDetailRow('매입가', formatter.format(avgPrice))),
              const SizedBox(width: 20),
              Expanded(child: _buildDetailRow('현재가', formatter.format(currentPrice))),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailRow('보유수량', '$qty 주'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: TextStyle(
          color: isBold ? Colors.white : Colors.white70, 
          fontSize: 13, 
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal
        )),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Text('보유 종목이 없습니다.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
