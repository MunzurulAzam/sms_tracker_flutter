import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String currency;

  @HiveField(4)
  String type; // 'credit' or 'debit'

  @HiveField(5)
  String description;

  @HiveField(6)
  DateTime timestamp;

  @HiveField(7)
  String rawSms;

  @HiveField(8)
  String smsId; // Add SMS ID to prevent duplicates

  Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.rawSms,
    required this.smsId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'type': type,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'rawSms': rawSms,
      'smsId': smsId,
    };
  }
}