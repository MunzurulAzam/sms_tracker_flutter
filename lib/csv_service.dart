import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'db/hive/transaction.dart';


class CsvService {
  Future<String> exportToCsv(List<Transaction> transactions, String userId) async {
    List<List<dynamic>> csvData = [
      ['ID', 'User ID', 'Amount', 'Currency', 'Type', 'Description', 'Timestamp', 'Raw SMS']
    ];

    for (Transaction transaction in transactions) {
      csvData.add([
        transaction.id,
        transaction.userId,
        transaction.amount,
        transaction.currency,
        transaction.type,
        transaction.description,
        transaction.timestamp.toIso8601String(),
        transaction.rawSms.replaceAll('\n', ' '),
      ]);
    }

    String csv = const ListToCsvConverter().convert(csvData);

    final directory = await getExternalStorageDirectory();
    final fileName = 'transactions_${userId}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory!.path}/$fileName');

    await file.writeAsString(csv);
    return file.path;
  }

  Future<void> shareCsv(String filePath) async {
    await Share.shareXFiles([XFile(filePath)]);
  }
}