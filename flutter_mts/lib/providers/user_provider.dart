import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UserProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  
  // .env 파일의 값을 우선시하고, 없을 경우 환경에 맞는 IP를 자동으로 선택합니다.
  static String get _defaultHost {
    if (kIsWeb) return "localhost";
    return defaultTargetPlatform == TargetPlatform.android ? "10.0.2.2" : "localhost";
  }

  final String ledgerUrl = dotenv.get('ACCOUNT_SERVER_URL', fallback: "http://$_defaultHost:9000");
  final String tradingUrl = dotenv.get('TRADING_SERVER_URL', fallback: "http://$_defaultHost:9001");

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  int? _userId;
  int? get userId => _userId;
  String? _username;
  String? get username => _username;
  String? _name;
  String? get name => _name;
  String? _phone;
  String? get phone => _phone;
  String? _rrn;
  String? get rrn => _rrn;

  List<dynamic> _accounts = [];
  List<dynamic> get accounts => _accounts;
  
  int _selectedAccountIndex = 0;
  int get selectedAccountIndex => _selectedAccountIndex;

  Map<String, dynamic>? get selectedAccount => 
      _accounts.isEmpty ? null : _accounts[_selectedAccountIndex];

  Map<String, dynamic>? get primaryAccount => 
      _accounts.isEmpty ? null : _accounts.firstWhere((a) => a['isPrimary'] == true, orElse: () => _accounts.first);

  double get cashBalance => (selectedAccount?['balance'] ?? 0.0).toDouble();
  
  double get totalCashBalance => _accounts.fold(0.0, (sum, acc) => sum + (acc['balance'] ?? 0.0).toDouble());

  void selectAccount(int index) {
    if (index >= 0 && index < _accounts.length) {
      _selectedAccountIndex = index;
      notifyListeners();
    }
  }

  static String getAccountTypeLabel(String? type) {
    if (type == null) return '계좌';
    switch (type.toUpperCase()) {
      case 'CONSIGNMENT':
        return '위탁계좌';
      case 'SAVINGS':
        return '저축계좌';
      case 'CMA':
        return 'CMA계좌';
      default:
        return type;
    }
  }
  
  List<dynamic> _holdings = [];
  List<dynamic> get holdings => _holdings;

  List<dynamic> _tradeHistory = [];
  List<dynamic> get tradeHistory => _tradeHistory;

  List<dynamic> _transferHistory = [];
  List<dynamic> get transferHistory => _transferHistory;

  final Set<String> _watchlist = {};
  Set<String> get watchlist => _watchlist;

  void toggleWatchlist(String ticker) {
    if (_watchlist.contains(ticker)) {
      _watchlist.remove(ticker);
    } else {
      _watchlist.add(ticker);
    }
    notifyListeners();
  }

  bool isWatching(String ticker) => _watchlist.contains(ticker);

  UserProvider() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final savedToken = await _storage.read(key: 'jwt_token');
    final savedUserId = await _storage.read(key: 'user_id');
    final savedUsername = await _storage.read(key: 'username');

    if (savedToken != null && savedUserId != null) {
      _token = savedToken;
      _userId = int.parse(savedUserId);
      _username = savedUsername;
      await fetchUserData();
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$ledgerUrl/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          _token = data['token'];
          _userId = data['userId'];
          _username = data['username'];
          
          await _storage.write(key: 'jwt_token', value: _token);
          await _storage.write(key: 'user_id', value: _userId.toString());
          await _storage.write(key: 'username', value: _username);

          await fetchUserData();
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to log in to Antigravity MTS',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        return await _tryAutoLogin().then((_) => isAuthenticated);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String name,
    required String accountType,
    String? email,
    String? rrn,
    String? phone,
    String? address,
    String? job,
    String? workplace,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$ledgerUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username, 
          "password": password, 
          "name": name,
          "accountType": accountType,
          "email": email,
          "rrn": rrn,
          "phone": phone,
          "address": address,
          "job": job,
          "workplace": workplace,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "Failure", "message": "Connection error: $e"};
    }
  }

  void logout() async {
    _token = null;
    _userId = null;
    _username = null;
    _accounts = [];
    _holdings = [];
    await _storage.deleteAll();
    notifyListeners();
  }

  Future<void> fetchUserData() async {
    if (!isAuthenticated) {
            // Not authenticated - skip silently
      return;
    }
    try {
      // 0. Fetch Profile
      final profileResponse = await http.get(
        Uri.parse('$ledgerUrl/account/profile/$_userId'),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body);
        _name = profileData['name'];
        _phone = profileData['phone'];
        _rrn = profileData['rrn'];
        notifyListeners(); // Notify UI immediately when profile is loaded
      }

      // 1. Fetch Accounts
      final accResponse = await http.get(
        Uri.parse('$ledgerUrl/account/list/$_userId'),
        headers: {"Authorization": "Bearer $_token"},
      );
            // Account list fetched
      if (accResponse.statusCode == 200) {
        _accounts = jsonDecode(accResponse.body) as List<dynamic>;
                // Accounts loaded
      }

      // 2. Fetch Holdings
      final assetResponse = await http.get(
        Uri.parse('$ledgerUrl/assets/$_userId'),
        headers: {"Authorization": "Bearer $_token"},
      );
            // Assets fetched
      if (assetResponse.statusCode == 200) {
        final data = jsonDecode(assetResponse.body);
        _holdings = data['holdings'] as List<dynamic>;
      }

      // 3. Fetch Trade History
      await fetchTradeHistory();

      // 4. Fetch Open Orders
      await fetchOpenOrders();

      notifyListeners();
    } catch (e) {
            debugPrint('fetchUserData error: $e');
    }
  }

  Future<void> fetchTradeHistory({String? ticker}) async {
    if (!isAuthenticated) return;
    try {
      final url = ticker != null 
          ? '$ledgerUrl/trades/user/$_userId/$ticker'
          : '$ledgerUrl/trades/user/$_userId';
      final response = await http.get(
        Uri.parse(url),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (response.statusCode == 200) {
        _tradeHistory = jsonDecode(response.body) as List<dynamic>;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchTradeHistory error: $e');
    }
  }

  Future<void> fetchTransferHistory() async {
    if (!isAuthenticated || selectedAccount == null) return;
    try {
      final accountNumber = selectedAccount!['accountNumber'];
      final response = await http.get(
        Uri.parse('$ledgerUrl/account/transfer/history/$accountNumber'),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (response.statusCode == 200) {
        _transferHistory = jsonDecode(response.body) as List<dynamic>;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchTransferHistory error: $e');
    }
  }

  Future<Map<String, dynamic>> transfer(String toAccount, double amount) async {
    if (primaryAccount == null) return {"status": "Failure", "message": "No source account"};
    
    try {
      final response = await http.post(
        Uri.parse('$ledgerUrl/account/transfer'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({
          "fromAccountNumber": primaryAccount!['accountNumber'],
          "toAccountNumber": toAccount,
          "amount": amount,
        }),
      );
      final result = jsonDecode(response.body);
      if (result['status'] == 'Success') {
        await fetchUserData();
      }
      return result;
    } catch (e) {
      return {"status": "Failure", "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> createAdditionalAccount(String accountType) async {
    if (!isAuthenticated) return {"status": "Failure", "message": "Not authenticated"};
    
    try {
      final response = await http.post(
        Uri.parse('$ledgerUrl/account/create'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({
          "userId": _userId,
          "accountType": accountType,
        }),
      );
      final result = jsonDecode(response.body);
      if (result['status'] == 'Success') {
        await fetchUserData();
      }
      return result;
    } catch (e) {
      return {"status": "Failure", "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> placeOrder({
    required String ticker,
    required int quantity,
    required int price,
    required String side,
  }) async {
    if (!isAuthenticated) return {"status": "Error", "reason": "Not authenticated"};
    
    try {
      final response = await http.post(
        Uri.parse('$tradingUrl/order'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({
          "ticker": ticker,
          "quantity": quantity,
          "price": price,
          "side": side,
        }),
      );

      final result = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await fetchUserData();
      }
      return result;
    } catch (e) {
      return {"status": "Error", "reason": e.toString()};
    }
  }

  List<dynamic> _openOrders = [];
  List<dynamic> get openOrders => _openOrders;

  Future<void> fetchOpenOrders() async {
    if (!isAuthenticated) return;
    try {
      final response = await http.get(
        Uri.parse('$tradingUrl/order/user'),
        headers: {"Authorization": "Bearer $_token"},
      );
      if (response.statusCode == 200) {
        _openOrders = jsonDecode(response.body) as List<dynamic>;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchOpenOrders error: $e');
    }
  }
}
