import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/market_data_provider.dart';
import 'account_opening_screen.dart';
import 'stock_detail_screen.dart';
import 'stock_profit_loss_screen.dart';
import 'return_report_screen.dart';
import 'app_ui_settings_screen.dart';
import 'total_assets_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int)? onTabChange;

  const SettingsScreen({super.key, this.onTabChange});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['주식', '자산', '뱅킹'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (widget.onTabChange != null) {
      widget.onTabChange!(index);
    }
  }

  // 주식 상세 이동 로직 (목적지 탭 지정)
  void _navigateToStockDetail(MarketDataProvider marketData, int targetIndex) {
    if (marketData.lastViewedTicker != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StockDetailScreen(
            ticker: marketData.lastViewedTicker!,
            initialTabIndex: targetIndex, 
          ),
        ),
      );
    } else {
      _navigateToTab(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최근 조회한 종목이 없습니다. 종목을 먼저 선택해주세요.'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final marketData = Provider.of<MarketDataProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F111A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _navigateToTab(0),
        ),
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.withOpacity(0.6),
          indicatorColor: const Color(0xFF2D5AF7),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. 주식 전용 탭
          _buildTabContent([
            _buildSection(
              icon: Icons.auto_graph,
              iconColor: const Color(0xFF2D5AF7),
              title: '국내 주식',
              items: [
                {'name': '관심종목', 'action': () => _navigateToTab(1)},
                {'name': '주식 현재가', 'action': () => _navigateToStockDetail(marketData, 1)}, 
                {'name': '주식 주문하기', 'action': () => _navigateToStockDetail(marketData, 2)},
              ],
            ),
          ], userProvider),

          // 2. 자산 전용 탭
          _buildTabContent([
            _buildSection(
              icon: Icons.pie_chart_outline,
              iconColor: Colors.orangeAccent,
              title: '나의 자산',
              items: [
                {'name': '내 자산', 'action': () => _navigateToTab(2)},
                {'name': '주식잔고 · 손익', 'action': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StockProfitLossScreen()))},
                {'name': '보유종목 분석', 'action': () => _navigateToTab(2)},
                {'name': '수익률 리포트', 'action': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnReportScreen()))},
              ],
            ),
          ], userProvider),

          // 3. 뱅킹 전용 탭
          _buildTabContent([
            _buildSection(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF00D2FF),
              title: '뱅킹 서비스',
              items: [
                {'name': '송금하기 (이체)', 'action': () => _navigateToTab(3)},
                {'name': '이체 내역 조회', 'action': () => _navigateToTab(3)},
                {'name': '비대면 계좌개설', 'action': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountOpeningScreen()))},
              ],
            ),
          ], userProvider),
        ],
      ),
    );
  }

  Widget _buildTabContent(List<Widget> sections, UserProvider userProvider) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        ...sections,
        const SizedBox(height: 40),
        _buildDivider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_outlined, color: Colors.grey),
          title: const Text('앱 설정', style: TextStyle(color: Colors.white70)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppUISettingsScreen())),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_open_outlined, color: Colors.redAccent),
          title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
          onTap: () => _handleLogout(context, userProvider),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Map<String, dynamic>> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return InkWell(
              onTap: items[index]['action'] as VoidCallback,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.03)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[index]['name'] as String,
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w400),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.15), size: 14),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text('정말 로그아웃 하시겠습니까?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              userProvider.logout();
            },
            child: const Text('확인', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
