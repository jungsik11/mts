import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../utils/formatters.dart';
import 'dart:async';

class AccountOpeningScreen extends StatefulWidget {
  const AccountOpeningScreen({super.key});

  @override
  State<AccountOpeningScreen> createState() => _AccountOpeningScreenState();
}

class _AccountOpeningScreenState extends State<AccountOpeningScreen> {
  int _currentStep = 0;
  final int _totalSteps = 8; // 1단계 추가됨
  
  // 입력 데이터 상태
  bool _allAgreed = false;
  final List<bool> _agreements = [false, false, false, false];
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _rrnController = TextEditingController(); // 주민번호
  
  String _selectedJob = '직장인';
  String _selectedPurpose = '투자/재테크';
  String _selectedSource = '근로소득';
  String _selectedAccountType = '위탁계좌'; // 추가
  
  String _pin = '';
  bool _isVerifying = false;
  String _createdAccountNumber = ''; // 성공 시 표시용
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserInfo();
    });
  }

  Future<void> _initializeUserInfo() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    debugPrint("Initializing User Info... Current Name: ${userProvider.name}");

    // 데이터가 없으면 서버에서 가져옴
    if (userProvider.name == null || userProvider.phone == null || userProvider.rrn == null) {
      await userProvider.fetchUserData();
    }

    _updateControllersFromProvider();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _updateControllersFromProvider() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    if (userProvider.name != null && _nameController.text.isEmpty) {
      _nameController.text = userProvider.name!;
    }
    
    if (userProvider.phone != null && _phoneController.text.isEmpty) {
      String p = userProvider.phone!.replaceAll('-', '');
      if (p.length == 11) {
        _phoneController.text = "${p.substring(0,3)}-${p.substring(3,7)}-${p.substring(7)}";
      } else if (p.length == 10) {
        _phoneController.text = "${p.substring(0,3)}-${p.substring(3,6)}-${p.substring(6)}";
      } else {
        _phoneController.text = userProvider.phone!;
      }
    }
    
    if (userProvider.rrn != null && _rrnController.text.isEmpty) {
      String r = userProvider.rrn!.replaceAll('-', '');
      if (r.length == 13) {
        _rrnController.text = "${r.substring(0,6)}-${r.substring(6)}";
      } else {
        _rrnController.text = userProvider.rrn!;
      }
    }
    
    debugPrint("Controllers updated. Name: ${_nameController.text}, Phone: ${_phoneController.text}");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rrnController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        // 본인 확인 단계로 진입할 때 다시 한번 데이터 확인
        if (_currentStep == 2) {
          _updateControllersFromProvider();
        }
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('비대면 계좌개설', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: Icon(_currentStep == 0 ? Icons.close : Icons.arrow_back_ios, size: 20),
          onPressed: () => _currentStep == 0 ? Navigator.pop(context) : _prevStep(),
        ),
      ),
      body: Column(
        children: [
          // 1. 상단 프로그레스 바
          _buildProgressBar(),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildCurrentStepView(),
            ),
          ),
          
          // 2. 하단 고정 버튼
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: index <= _currentStep ? const Color(0xFF2D5AF7) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0: return _stepAccountType();
      case 1: return _stepAgreements();
      case 2: return _stepIdentity();
      case 3: return _stepIdCard();
      case 4: return _stepExtraInfo();
      case 5: return _stepPassword();
      case 6: return _stepAccountVerify();
      case 7: return _stepSuccess();
      default: return Container();
    }
  }

  // --- Step Views ---

  // 0단계: 약관 동의
  Widget _stepAgreements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('계좌 개설을 위해\n약관에 동의해 주세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 32),
        _buildAgreementItem('전체 동의하기', _allAgreed, (val) {
          setState(() {
            _allAgreed = val!;
            for (int i = 0; i < _agreements.length; i++) {
              _agreements[i] = val;
            }
          });
        }, isBold: true),
        const Divider(color: Colors.white10, height: 32),
        _buildAgreementItem('[필수] 종합계좌 개설 약관', _agreements[0], (val) => setState(() => _agreements[0] = val!)),
        _buildAgreementItem('[필수] 개인정보 수집 및 이용 동의', _agreements[1], (val) => setState(() => _agreements[1] = val!)),
        _buildAgreementItem('[필수] 금융소비자 보호법 안내', _agreements[2], (val) => setState(() => _agreements[2] = val!)),
        _buildAgreementItem('[선택] 마케팅 정보 수신 동의', _agreements[3], (val) => setState(() => _agreements[3] = val!)),
      ],
    );
  }

  // 1단계: 본인 확인
  Widget _stepIdentity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('본인 정보를\n입력해 주세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 32),
        _buildTextField('이름', _nameController, '성함을 입력하세요', onChanged: (_) => setState(() {})),
        const SizedBox(height: 20),
        _buildTextField(
          '휴대폰 번호', 
          _phoneController, 
          '010-0000-0000', 
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          formatters: [PhoneNumberFormatter()],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          '주민등록번호', 
          _rrnController, 
          '앞 6자리 - 뒤 7자리', 
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          formatters: [RRNFormatter()],
        ),
      ],
    );
  }

  // 2단계: 계좌 종류 선택
  Widget _stepAccountType() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('개설하실 계좌의\n종류를 선택해 주세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 32),
        _buildAccountTypeItem('위탁계좌', '주식, ETF 거래가 가능한 기본 계좌', Icons.trending_up, _selectedAccountType == '위탁계좌'),
        const SizedBox(height: 16),
        _buildAccountTypeItem('CMA 계좌', '하루만 맡겨도 이자가 쌓이는 입출금 계좌', Icons.account_balance_wallet, _selectedAccountType == 'CMA 계좌'),
        const SizedBox(height: 16),
        _buildAccountTypeItem('연금 계좌', '노후 준비와 세액 공제를 한 번에', Icons.savings, _selectedAccountType == '연금 계좌'),
      ],
    );
  }

  Widget _buildAccountTypeItem(String title, String desc, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedAccountType = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D5AF7).withOpacity(0.1) : const Color(0xFF1A1D2D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D5AF7) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2D5AF7) : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF2D5AF7)),
          ],
        ),
      ),
    );
  }

  // 2단계: 신분증 촬영
  Widget _stepIdCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('신분증을\n촬영해 주세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 12),
        const Text('주민등록증 또는 운전면허증을\n어두운 배경에 놓아주세요.', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 40),
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2D5AF7), width: 2),
          ),
          child: const Stack(
            children: [
              Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white24, size: 48)),
              Positioned(
                bottom: 20,
                left: 0, right: 0,
                child: Center(child: Text('가이드 라인에 맞춰주세요', style: TextStyle(color: Colors.white54, fontSize: 12))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3단계: 추가 정보
  Widget _stepExtraInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('고객님의\n정보를 확인합니다', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 32),
        _buildDropdown('직업 정보', _selectedJob, ['직장인', '자영업자', '학생', '무직', '전문직'], (val) => setState(() => _selectedJob = val!)),
        const SizedBox(height: 20),
        _buildDropdown('자금 출처', _selectedSource, ['근로소득', '사업소득', '상속/증여', '재테크', '기타'], (val) => setState(() => _selectedSource = val!)),
        const SizedBox(height: 20),
        _buildDropdown('계좌 개설 목적', _selectedPurpose, ['투자/재테크', '급여이체', '생활비관리', '기타'], (val) => setState(() => _selectedPurpose = val!)),
      ],
    );
  }

  // 4단계: 비밀번호 설정
  Widget _stepPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('계좌에서 사용할\n비밀번호를 설정하세요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 40),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              bool isFilled = _pin.length > index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled ? const Color(0xFF2D5AF7) : Colors.white10,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 40),
        _buildNumberPad(),
      ],
    );
  }

  // 5단계: 타행 인증 (1원 송금)
  Widget _stepAccountVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('본인 소유 계좌로\n1원을 보냈습니다', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4)),
        const SizedBox(height: 12),
        const Text('입금자명 뒤의 숫자 3자리를\n입력해 주세요. (예: 안티그래비티123)', style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 40),
        TextField(
          maxLength: 3,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 32, letterSpacing: 20, fontWeight: FontWeight.bold, color: Color(0xFF00D2FF)),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D5AF7))),
          ),
        ),
      ],
    );
  }

  // 6단계: 성공
  Widget _stepSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 80),
          ),
          const SizedBox(height: 32),
          const Text('계좌 개설 완료!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            '고객님의 소중한 자산,\n안티그래비티가 함께합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 40),
          Container(
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
                    const Text('개설 계좌', style: TextStyle(color: Colors.grey)),
                    Text(_selectedAccountType, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('계좌 번호', style: TextStyle(color: Colors.grey)),
                    Text(_createdAccountNumber.isEmpty ? '123-456-789012' : _createdAccountNumber, 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00D2FF))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildAgreementItem(String text, bool value, Function(bool?) onChanged, {bool isBold = false}) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF2D5AF7),
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 12),
            Text(text, style: TextStyle(
              fontSize: isBold ? 16 : 14, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: value ? Colors.white : Colors.white60
            )),
            const Spacer(),
            if (!isBold) const Icon(Icons.chevron_right, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label, 
    TextEditingController controller, 
    String hint, 
    {TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Function(String)? onChanged}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D5AF7))),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D2D),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1D2D),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberPad() {
    final List<String> nums = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5),
      itemBuilder: (context, i) {
        return InkWell(
          onTap: () {
            setState(() {
              if (nums[i] == '⌫') {
                if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
              } else if (nums[i].isNotEmpty && _pin.length < 4) {
                _pin += nums[i];
              }
            });
          },
          child: Center(
            child: Text(nums[i], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _buildBottomButton() {
    bool canGoNext = false;
    if (_currentStep == 0) {
      canGoNext = _selectedAccountType.isNotEmpty;
    } else if (_currentStep == 1) {
      canGoNext = _agreements[0] && _agreements[1] && _agreements[2];
    } else if (_currentStep == 2) {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.replaceAll('-', '');
      final rrn = _rrnController.text.replaceAll('-', '');
      canGoNext = name.length >= 2 && (phone.length == 10 || phone.length == 11) && rrn.length == 13;
    } else if (_currentStep == 5) {
      canGoNext = _pin.length == 4;
    } else {
      canGoNext = true;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: canGoNext ? () async {
            if (_currentStep == _totalSteps - 1) {
              Navigator.pop(context);
            } else if (_currentStep == 6) { // 마지막 인증 단계에서 개설 시도
              setState(() => _isVerifying = true);
              
              try {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final result = await userProvider.createAdditionalAccount(_selectedAccountType);
                
                if (result['status'] == 'Success') {
                  setState(() {
                    _createdAccountNumber = result['accountNumber'];
                    _isVerifying = false;
                  });
                  _nextStep();
                } else {
                  setState(() => _isVerifying = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('계좌 개설 실패: ${result['message'] ?? '알 수 없는 오류'}')),
                    );
                  }
                }
              } catch (e) {
                setState(() => _isVerifying = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('연결 오류: $e')),
                  );
                }
              }
            } else {
              _nextStep();
            }
          } : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D5AF7),
            disabledBackgroundColor: Colors.white.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isVerifying 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                _currentStep == _totalSteps - 1 ? '시작하기' : '다음으로',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
        ),
      ),
    );
  }
}
