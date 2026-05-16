import 'package:intl/intl.dart';

class FormatterUtils {
  static String formatPrice(dynamic price, {String currency = "KRW", String? ticker}) {
    // ticker가 'US_'로 시작하면 USD로 취급
    final bool isUs = (currency == "USD") || (ticker != null && RegExp(r'[a-zA-Z]').hasMatch(ticker));
    
    if (isUs) {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);
      return formatter.format(price);
    } else {
      final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
      return formatter.format(price);
    }
  }

  static String formatCurrency(dynamic amount, {String currency = "KRW"}) {
    if (currency == "USD") {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);
      return formatter.format(amount);
    } else {
      final formatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
      return formatter.format(amount);
    }
  }
}
