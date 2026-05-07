import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _pageController = PageController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedAccountType = 'CONSIGNMENT';
  int _currentStep = 0;
  bool _isLoading = false;

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _handleRegister() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    final result = await userProvider.register(
      _usernameController.text,
      _passwordController.text,
      _emailController.text,
      _selectedAccountType,
    );

    setState(() => _isLoading = false);

    if (result['status'] == 'Success' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('계정이 성공적으로 생성되었습니다! 로그인해주세요.')),
      );
      Navigator.pop(context);
    } else if (result['reason'] == 'USER_ALREADY_EXISTS' && mounted) {
      _showUserExistsDialog(_usernameController.text);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? '회원가입에 실패했습니다.')),
      );
    }
  }

  void _showUserExistsDialog(String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2D),
        title: const Text('이미 가입된 계정', style: TextStyle(color: Colors.white)),
        content: Text(
          '사용자 이름 "$username"은(는) 이미 등록되어 있습니다. 아이디를 찾거나 비밀번호를 재설정하시겠습니까?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to Find ID Screen (Placeholder for now)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('아이디/비밀번호 찾기 페이지로 이동합니다... (준비 중)')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('아이디 / 비번 찾기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade900, Colors.black],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100),
            // Progress Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(0, '계정 선택'),
                Container(width: 40, height: 2, color: Colors.white24),
                _buildStepIndicator(1, '정보 입력'),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildAccountSelectionStep(),
                  _buildUserInfoStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    bool isActive = _currentStep == step;
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: isActive ? Colors.blueAccent : Colors.white24,
          child: Text('${step + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildAccountSelectionStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '계좌 종류를 선택하세요',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '회원가입 시 하나의 계좌를 생성할 수 있습니다.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 48),
          _buildAccountTypeCard(
            'CONSIGNMENT',
            '위탁계좌',
            '표준 거래 계좌입니다. 주식 매수 및 매도가 가능합니다.',
            Icons.show_chart,
          ),
          const SizedBox(height: 16),
          _buildAccountTypeCard(
            'CMA',
            'CMA 계좌',
            '현금 관리 계좌입니다. 이율은 높지만 주식 거래는 불가능합니다.',
            Icons.account_balance_wallet,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('계속하기', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountTypeCard(String type, String title, String desc, IconData icon) {
    bool isSelected = _selectedAccountType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountType = type),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.blueAccent : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.white54, size: 32),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '회원 정보 입력',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildTextField(_usernameController, '사용자 이름 (ID)', Icons.person),
            const SizedBox(height: 16),
            _buildTextField(_emailController, '이메일 주소', Icons.email),
            const SizedBox(height: 16),
            _buildTextField(_passwordController, '비밀번호', Icons.lock, obscure: true),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      minimumSize: const Size(0, 56),
                    ),
                    child: const Text('이전', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(0, 56),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('가입 완료', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
      ),
    );
  }
}
