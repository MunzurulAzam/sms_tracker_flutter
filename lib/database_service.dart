import 'package:hive_flutter/hive_flutter.dart';

import 'db/hive/transaction.dart';


class DatabaseService {
  late Box<Transaction> _transactionBox;

  DatabaseService() {
    _transactionBox = Hive.box<Transaction>('transactions');
  }

  Future<void> saveTransaction(Transaction transaction) async {
    await _transactionBox.put(transaction.id, transaction);
  }

  List<Transaction> getAllTransactions() {
    return _transactionBox.values.toList();
  }

  List<Transaction> getTransactionsByUserId(String userId) {
    return _transactionBox.values
        .where((transaction) => transaction.userId == userId)
        .toList();
  }

  double getTotalCredit(String userId) {
    return getTransactionsByUserId(userId)
        .where((t) => t.type == 'credit')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalDebit(String userId) {
    return getTransactionsByUserId(userId)
        .where((t) => t.type == 'debit')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getNetBalance(String userId) {
    return getTotalCredit(userId) - getTotalDebit(userId);
  }
}