import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smsread/sms_parser.dart';

import 'database_service.dart';


class SmsService {
  static const platform = MethodChannel('sms_tracker/sms');
  final DatabaseService _databaseService = DatabaseService();

  Future<bool> requestPermissions() async {
    try {
      // Check current permission status first
      PermissionStatus smsStatus = await Permission.sms.status;
      print('SMS Permission Status: $smsStatus');

      // Check native permission first
      bool nativeCheck = await _checkNativePermission();
      print('Native SMS Permission Check: $nativeCheck');

      // If native check passes, we're good
      if (nativeCheck) {
        print('SMS permission confirmed via native check');
        return true;
      }

      // If not granted, try to request
      if (!smsStatus.isGranted) {
        print('Requesting SMS permission...');
        PermissionStatus newStatus = await Permission.sms.request();
        print('New SMS Permission Status: $newStatus');

        if (newStatus.isGranted) {
          // Double check with native
          bool finalCheck = await _checkNativePermission();
          print('Final native check: $finalCheck');
          return finalCheck;
        }
      }

      return false;
    } catch (e) {
      print('Permission request error: $e');
      // If permission_handler fails, try native check as fallback
      try {
        bool nativeCheck = await _checkNativePermission();
        print('Fallback native check: $nativeCheck');
        return nativeCheck;
      } catch (nativeError) {
        print('Native check also failed: $nativeError');
        return false;
      }
    }
  }

  Future<bool> _checkNativePermission() async {
    try {
      final bool result = await platform.invokeMethod('checkSmsPermission');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check native permission: '${e.message}'.");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSms() async {
    try {
      print('Attempting to read SMS...');
      final dynamic result = await platform.invokeMethod('getAllSms');
      print('SMS read successfully. Result type: ${result.runtimeType}');

      if (result is List) {
        List<Map<String, dynamic>> smsList = [];
        for (var item in result) {
          if (item is Map) {
            // Convert Map<Object?, Object?> to Map<String, dynamic>
            Map<String, dynamic> smsMap = {};
            item.forEach((key, value) {
              if (key != null && value != null) {
                smsMap[key.toString()] = value;
              }
            });
            smsList.add(smsMap);
          }
        }
        print('Converted ${smsList.length} SMS messages');
        return smsList;
      }

      return [];
    } on PlatformException catch (e) {
      print("Platform Exception - Failed to get SMS: '${e.message}'.");
      print("Error Code: ${e.code}");
      print("Error Details: ${e.details}");

      if (e.code == 'PERMISSION_DENIED') {
        // Try to check permission again
        bool hasPermission = await _checkNativePermission();
        print('Rechecked permission after error: $hasPermission');
      }

      return [];
    } catch (e) {
      print("General Exception - Failed to get SMS: $e");
      return [];
    }
  }

  Future<void> processFinancialSms(String userId) async {
    print('Starting SMS processing for user: $userId');

    final smsList = await getAllSms();
    print('Retrieved ${smsList.length} SMS messages');

    if (smsList.isEmpty) {
      print('No SMS messages found or permission denied');
      return;
    }

    final parser = SmsParser();
    int processedCount = 0;
    int skippedCount = 0;

    for (var sms in smsList) {
      try {
        // Safe type conversion
        final String body = _safeGetString(sms, 'body');
        final String smsId = _safeGetString(sms, 'id');
        final dynamic dateValue = sms['date'];

        // Check if this SMS is already processed (prevent duplicates)
        bool alreadyExists = _databaseService.smsAlreadyProcessed(smsId);
        if (alreadyExists) {
          skippedCount++;
          continue;
        }

        int timestamp;
        if (dateValue is int) {
          timestamp = dateValue;
        } else if (dateValue is String) {
          timestamp = int.tryParse(dateValue) ?? DateTime.now().millisecondsSinceEpoch;
        } else if (dateValue is double) {
          timestamp = dateValue.toInt();
        } else {
          timestamp = DateTime.now().millisecondsSinceEpoch;
        }

        if (body.isNotEmpty && parser.isFinancialSms(body)) {
          final transaction = parser.parseTransaction(body, userId, timestamp, smsId);
          if (transaction != null) {
            await _databaseService.saveTransaction(transaction);
            processedCount++;
            print('Processed transaction: ${transaction.amount} ${transaction.currency} (${transaction.type})');
          }
        }
      } catch (e) {
        print('Error processing SMS: $e');
        continue;
      }
    }

    print('Successfully processed $processedCount new financial SMS messages');
    print('Skipped $skippedCount already processed messages');
  }

  String _safeGetString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return '';
    return value.toString();
  }
}