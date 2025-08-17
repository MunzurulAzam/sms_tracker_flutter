import 'dart:math';
import 'package:uuid/uuid.dart';

import 'db/hive/transaction.dart';


class SmsParser {
  final Uuid _uuid = Uuid();

  // Financial keywords to identify money-related SMS
  final List<String> _financialKeywords = [
    'debited', 'credited', 'withdrawn', 'deposited', 'transferred',
    'balance', 'account', 'bank', 'atm', 'card', 'payment', 'transaction',
    'amount', 'rupees', 'rs', 'inr', 'usd', 'dollar', 'taka', 'tk'
  ];

  bool isFinancialSms(String smsBody) {
    final lowerBody = smsBody.toLowerCase();
    return _financialKeywords.any((keyword) => lowerBody.contains(keyword));
  }

  Transaction? parseTransaction(String smsBody, String userId, int timestamp) {
    final amount = _extractAmount(smsBody);
    final currency = _extractCurrency(smsBody);
    final type = _determineTransactionType(smsBody);

    if (amount == null || type == null) return null;

    return Transaction(
      id: _uuid.v4(),
      userId: userId,
      amount: amount,
      currency: currency,
      type: type,
      description: _extractDescription(smsBody),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      rawSms: smsBody,
    );
  }

  double? _extractAmount(String text) {
    // Regex patterns for different amount formats
    final patterns = [
      r'(?:rs\.?|inr|rupees?)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', // Rs. 1,000.00
      r'(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:rs\.?|inr|rupees?)', // 1,000.00 Rs
      r'(?:usd|dollar|$)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', // USD 100.00
      r'(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:usd|dollar)', // 100.00 USD
      r'(?:tk\.?|taka)\s*(\d+(?:,\d{3})*(?:\.\d{2})?)', // Tk. 1000.00
      r'(\d+(?:,\d{3})*(?:\.\d{2})?)\s*(?:tk\.?|taka)', // 1000.00 Tk
    ];

    for (String pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '0';
        return double.tryParse(amountStr);
      }
    }
    return null;
  }

  String _extractCurrency(String text) {
    final lowerText = text.toLowerCase();
    if (lowerText.contains(RegExp(r'\b(?:rs\.?|inr|rupees?)\b'))) return 'INR';
    if (lowerText.contains(RegExp(r'\b(?:usd|dollar|\$)\b'))) return 'USD';
    if (lowerText.contains(RegExp(r'\b(?:tk\.?|taka)\b'))) return 'BDT';
    return 'UNKNOWN';
  }

  String? _determineTransactionType(String text) {
    final lowerText = text.toLowerCase();

    final creditWords = ['credited', 'deposited', 'received', 'refund'];
    final debitWords = ['debited', 'withdrawn', 'spent', 'paid', 'charged'];

    if (creditWords.any((word) => lowerText.contains(word))) return 'credit';
    if (debitWords.any((word) => lowerText.contains(word))) return 'debit';

    return null;
  }

  String _extractDescription(String text) {
    // Extract merchant/description info
    final lines = text.split('\n');
    if (lines.length > 1) {
      return lines[1].trim();
    }
    return text.length > 50 ? text.substring(0, 50) + '...' : text;
  }
}