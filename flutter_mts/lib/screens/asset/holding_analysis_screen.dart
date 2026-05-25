import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/user_provider.dart';
import '../../providers/market_data_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/formatter_utils.dart';

class HoldingAnalysisScreen extends StatefulWidget {
  const HoldingAnalysisScreen({super.key});

  @override
  State<HoldingAnalysisScreen> createState() => _HoldingAnalysisScreenState();
}

class _HoldingAnalysisScreenState extends State<HoldingAnalysisScreen> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    // 1. Portfolio Analysis Logic
    final holdings = userProvider.holdings;
    double totalEvaluation = 0;
    Map<String, double> tickerEvaluations = {};

    for (var h in holdings) {
      final ticker = h['ticker'];
      final qty = (h['quantity'] as int) + (h['locked_quantity'] as int? ?? 0);
      final avgPrice = (h['avg_price'] ?? 0).toDouble();
      final currentPrice = (marketData.prices[ticker]?['price'] ?? avgPrice).toDouble();
      
      double eval = currentPrice * qty;
      if (RegExp(r'[a-zA-Z]').hasMatch(ticker)) {
        eval = eval * marketData.usdKrwExchangeRate;
      }
      
      totalEvaluation += eval;
      tickerEvaluations[ticker] = eval;
    }

    // Sort by evaluation amount descending
    final sortedTickers = tickerEvaluations.keys.toList()
      ..sort((a, b) => tickerEvaluations[b]!.compareTo(tickerEvaluations[a]!));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('보유 종목 분석', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: holdings.isEmpty
          ? _buildEmptyState(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Chart Section
                  _buildPieChartSection(context, sortedTickers, tickerEvaluations, totalEvaluation),
                  
                  const SizedBox(height: 32),
                  const Text('포트폴리오 비중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // 2. Weightage List
                  ...sortedTickers.map((ticker) {
                    final eval = tickerEvaluations[ticker]!;
                    final weight = (eval / totalEvaluation) * 100;
                    final priceData = marketData.prices[ticker] ?? {};
                    final name = priceData['name'] ?? ticker.split('_')[0];
                    final currency = "KRW"; // 달러 자산도 원화로 환산됨
                    
                    return _buildWeightItem(context, name, ticker, weight, eval, currency, settings);
                  }),
                  
                  const SizedBox(height: 32),
                  const Text('성과 분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // 3. Performance Metrics
                  _buildPerformanceMetrics(userProvider, marketData, settings, formatter),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPieChartSection(BuildContext context, List<String> tickers, Map<String, double> evals, double total) {
    final List<Color> colors = [
      const Color(0xFF2D5AF7),
      const Color(0xFF00D2FF),
      const Color(0xFF50E3C2),
      const Color(0xFFF5A623),
      const Color(0xFFFF4B4B),
      const Color(0xFF9B51E0),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        touchedIndex = -1;
                        return;
                      }
                      touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                borderData: FlBorderData(show: false),
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: List.generate(tickers.length, (i) {
                  final isTouched = i == touchedIndex;
                  final fontSize = isTouched ? 16.0 : 12.0;
                  final radius = isTouched ? 60.0 : 50.0;
                  final ticker = tickers[i];
                  final weight = (evals[ticker]! / total) * 100;

                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: weight,
                    title: weight > 5 ? '${weight.toStringAsFixed(0)}%' : '',
                    radius: radius,
                    titleStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(tickers.take(5).length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tickers[i].split('_')[0],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightItem(BuildContext context, String name, String ticker, double weight, double eval, String currency, SettingsProvider settings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(ticker, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(FormatterUtils.formatPrice(eval, currency: currency), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${weight.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: weight / 100,
              backgroundColor: Colors.white.withOpacity(0.05),
              color: const Color(0xFF2D5AF7),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics(UserProvider userProvider, MarketDataProvider marketData, SettingsProvider settings, NumberFormat formatter) {
    // Top Performer
    Map<String, double> profits = {};
    for (var h in userProvider.holdings) {
      final ticker = h['ticker'];
      final avgPrice = (h['avg_price'] ?? 0).toDouble();
      final currentPrice = (marketData.prices[ticker]?['price'] ?? avgPrice).toDouble();
      if (avgPrice > 0) {
        profits[ticker] = ((currentPrice - avgPrice) / avgPrice) * 100;
      }
    }

    String topTicker = "N/A";
    double topReturn = 0;
    String bottomTicker = "N/A";
    double bottomReturn = 0;

    if (profits.isNotEmpty) {
      final sortedProfits = profits.keys.toList()
        ..sort((a, b) => profits[b]!.compareTo(profits[a]!));
      topTicker = sortedProfits.first.split('_')[0];
      topReturn = profits[sortedProfits.first]!;
      bottomTicker = sortedProfits.last.split('_')[0];
      bottomReturn = profits[sortedProfits.last]!;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('최고 수익 종목', topTicker, '${topReturn > 0 ? '+' : ''}${topReturn.toStringAsFixed(2)}%', settings.upColor)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('최저 수익 종목', bottomTicker, '${bottomReturn > 0 ? '+' : ''}${bottomReturn.toStringAsFixed(2)}%', settings.downColor)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDiversityCard(userProvider.holdings.length),
      ],
    );
  }

  Widget _buildMetricCard(String title, String ticker, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(ticker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDiversityCard(int count) {
    String message = "";
    Color color = Colors.greenAccent;
    if (count <= 1) {
      message = "집중 투자 중입니다. 분산 투자를 고려해보세요.";
      color = Colors.orangeAccent;
    } else if (count <= 3) {
      message = "적절한 분산이 이루어지고 있습니다.";
      color = Colors.blueAccent;
    } else {
      message = "다양한 종목에 분산 투자 중입니다.";
      color = const Color(0xFF50E3C2);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text('분석할 보유 종목이 없습니다.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
