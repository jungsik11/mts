import 'package:flutter/services.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll('-', '');
    if (text.length > 11) text = text.substring(0, 11);
    
    String formatted = '';
    if (text.length >= 3) {
      formatted += '${text.substring(0, 3)}-';
      if (text.length >= 7) {
        formatted += '${text.substring(3, 7)}-';
        formatted += text.substring(7);
      } else {
        formatted += text.substring(3);
      }
    } else {
      formatted = text;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class RRNFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll('-', '');
    if (text.length > 13) text = text.substring(0, 13);
    
    String formatted = '';
    if (text.length >= 6) {
      formatted += '${text.substring(0, 6)}-';
      formatted += text.substring(6);
    } else {
      formatted = text;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
