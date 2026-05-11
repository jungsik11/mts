import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  bool _isInit = true;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _loadData();
      _isInit = false;
    }
    super.didChangeDependencies();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Provider.of<UserProvider>(context, listen: false).fetchTransferHistory();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final history = userProvider.transferHistory;
    final primaryAccount = userProvider.primaryAccount;
    final accountNumber = primaryAccount?['accountNumber'] ?? '';
    
    final currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('이체 내역'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      final isOutgoing = item['fromAccountNumber'] == accountNumber;
                      final amount = item['amount'] as double;
                      final timestamp = DateTime.parse(item['timestamp']);
                      final otherAccount = isOutgoing ? item['toAccountNumber'] : item['fromAccountNumber'];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        leading: CircleAvatar(
                          backgroundColor: isOutgoing ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          child: Icon(
                            isOutgoing ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isOutgoing ? Colors.redAccent : Colors.blueAccent,
                          ),
                        ),
                        title: Text(
                          isOutgoing ? '송금 (출금)' : '입금',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              isOutgoing ? '받는 계좌: $otherAccount' : '보낸 계좌: $otherAccount',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateFormatter.format(timestamp),
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${isOutgoing ? "-" : "+"}${currencyFormatter.format(amount)}',
                          style: TextStyle(
                            color: isOutgoing ? Colors.redAccent : Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text(
            '이체 내역이 없습니다.',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
