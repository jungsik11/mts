import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:intl/intl.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _toAccountController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final primaryAcc = userProvider.primaryAccount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('송금하기'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From Account Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('출금 계좌', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${primaryAcc?['accountType']} ${primaryAcc?['accountNumber']}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('잔액: ${formatter.format(userProvider.cashBalance)}', 
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('입금 계좌', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _toAccountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                // 숫자만 허용 - 하이픈(-) 입력 불가
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: '계좌번호 숫자만 입력 (예: 1234567890)',
                filled: true,
                fillColor: const Color(0xFF1A1D2D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const Text('이체 금액', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '이체할 금액을 입력하세요',
                prefixText: '₩ ',
                filled: true,
                fillColor: const Color(0xFF1A1D2D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _handleTransfer(context, userProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D5AF7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('지금 이체하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _handleTransfer(BuildContext context, UserProvider userProvider) async {
    // 혹시 붙여넣기 등으로 하이픈이 들어온 경우 제거 (안전망)
    final toAcc = _toAccountController.text.trim().replaceAll('-', '');
    final amountText = _amountController.text.trim();
    
    if (toAcc.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('올바른 금액을 입력해주세요')));
      return;
    }

    setState(() => _isLoading = true);
    final result = await userProvider.transfer(toAcc, amount);
    setState(() => _isLoading = false);

    if (result['status'] == 'Success') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('이체 성공'),
          content: Text('${NumberFormat.currency(locale: 'ko_KR', symbol: '₩').format(amount)}이(가) $toAcc 계좌로 전송되었습니다.'),
          actions: [
            TextButton(onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Go back from transfer screen
            }, child: const Text('확인'))
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? '이체에 실패했습니다')));
    }
  }
}
