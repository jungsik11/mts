import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class UserProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  
  static String get _host => kIsWeb ? "localhost" : (defaultTargetPlatform == TargetPlatform.android ? "10.0.2.2" : "localhost");
  final String ledgerUrl = "http://$_host:9000";
  final String tradingUrl = "http://$_host:9001";

  String? _token;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  int? _userId;
  int? get userId => _userId;
  String? _username;
  String? get username => _username;

  List<dynamic> _accounts = [];
  List<dynamic> get accounts => _accounts;
  
  Map<String, dynamic>? get primaryAccount => _accounts.isEmpty ? null : _accounts.firstWhere((a) => a['isPrimary'] == true, orElse: () => _accounts.first);

  double get cashBalance => (primaryAccount?['balance'] ?? 0.0).toDouble();
  
  List<dynamic> _holdings = [];
  List<dynamic> get holdings => _holdings;

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

  Future<Map<String, dynamic>> register(String username, String password, String email, String accountType) async {
    try {
      final response = await http.post(
        Uri.parse('$ledgerUrl/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username, 
          "password": password, 
          "email": email,
          "accountType": accountType
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
            // Fetching user data
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
      notifyListeners();
    } catch (e) {
            debugPrint('fetchUserData error: $e');
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
}
