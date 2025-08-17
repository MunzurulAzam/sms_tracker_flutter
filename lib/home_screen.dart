import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smsread/prediction_service.dart';
import 'package:smsread/sms_service.dart';
import 'package:uuid/uuid.dart';

import 'csv_service.dart';
import 'database_service.dart';
import 'db/hive/transaction.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SmsService _smsService = SmsService();
  final DatabaseService _databaseService = DatabaseService();
  final CsvService _csvService = CsvService();
  final PredictionService _predictionService = PredictionService();
  final TextEditingController _userIdController = TextEditingController();
  final Uuid _uuid = Uuid();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String _currentUserId = '';
  Map<String, dynamic>? _predictionResult;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    setState(() {
      _transactions = _databaseService.getAllTransactions();
    });
  }

  Future<void> _scanSms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('=== Starting SMS Scan ===');

      // Check if permissions are already granted
      bool hasPermission = await _smsService.requestPermissions();
      print('Final permission result: $hasPermission');

      if (!hasPermission) {
        print('Permission denied, showing error message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SMS permission is required. Please enable it in App Settings.'),
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
        return;
      }

      print('Permission granted, proceeding with SMS scan');

      // Generate unique user ID
      _currentUserId = _uuid.v4();
      print('Generated User ID: $_currentUserId');

      // Process SMS messages
      await _smsService.processFinancialSms(_currentUserId);

      // Reload transactions
      _loadTransactions();

      // Count user transactions
      int userTransactionCount = _transactions.where((t) => t.userId == _currentUserId).length;
      print('Found $userTransactionCount transactions for current user');

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SMS scanning completed!\nFound $userTransactionCount financial transactions.\nUser ID: $_currentUserId'),
          duration: Duration(seconds: 6),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('SMS Scan Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scanning SMS: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('=== SMS Scan Completed ===');
    }
  }

  Future<void> _exportCsv() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    try {
      String filePath = await _csvService.exportToCsv(_transactions, _currentUserId);
      await _csvService.shareCsv(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }

  void _predictLoanEligibility() {
    String userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a User ID')),
      );
      return;
    }

    List<Transaction> userTransactions = _databaseService.getTransactionsByUserId(userId);
    if (userTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No transactions found for this User ID')),
      );
      return;
    }

    double totalCredit = _databaseService.getTotalCredit(userId);
    double totalDebit = _databaseService.getTotalDebit(userId);
    double netBalance = _databaseService.getNetBalance(userId);
    int transactionCount = userTransactions.length;

    setState(() {
      _predictionResult = _predictionService.predictLoanEligibility(
          userId, totalCredit, totalDebit, netBalance, transactionCount
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SMS Financial Tracker'),
        backgroundColor: Colors.blue[600],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scan SMS Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _scanSms,
              icon: _isLoading
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.sms),
              label: Text(_isLoading ? 'Scanning...' : 'Scan SMS for Transactions'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.green,
              ),
            ),

            SizedBox(height: 16),

            // Current User ID Display
            if (_currentUserId.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Current User ID: $_currentUserId', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

            SizedBox(height: 16),

            // Export CSV Button
            ElevatedButton.icon(
              onPressed: _exportCsv,
              icon: Icon(Icons.file_download),
              label: Text('Export CSV'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.orange,
              ),
            ),

            SizedBox(height: 24),

            // Loan Prediction Section
            Text('Loan Prediction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),

            TextField(
              controller: _userIdController,
              decoration: InputDecoration(
                labelText: 'Enter User ID for Prediction',
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 12),

            ElevatedButton(
              onPressed: _predictLoanEligibility,
              child: Text('Predict Loan Eligibility'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.purple,
              ),
            ),

            SizedBox(height: 16),

            // Prediction Result
            if (_predictionResult != null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _predictionResult!['prediction'] == 'GOOD FOR LOAN' ? Colors.green[50] : Colors.red[50],
                  border: Border.all(color: _predictionResult!['prediction'] == 'GOOD FOR LOAN' ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prediction: ${_predictionResult!['prediction']}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Score: ${_predictionResult!['score']}/100'),
                    Text('Confidence: ${_predictionResult!['confidence']}'),
                    Text('Net Balance: ${_predictionResult!['netBalance'].toStringAsFixed(2)}'),
                    Text('Total Transactions: ${_predictionResult!['transactionCount']}'),
                  ],
                ),
              ),

            SizedBox(height: 16),

            // Transactions List
            Text('Transactions (${_transactions.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            Expanded(
              child: _transactions.isEmpty
                  ? Center(child: Text('No transactions found. Scan SMS to get started.'))
                  : ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final transaction = _transactions[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: transaction.type == 'credit' ? Colors.green : Colors.red,
                        child: Icon(
                          transaction.type == 'credit' ? Icons.add : Icons.remove,
                          color: Colors.white,
                        ),
                      ),
                      title: Text('${transaction.currency} ${transaction.amount.toStringAsFixed(2)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(transaction.description),
                          Text(transaction.timestamp.toString().substring(0, 19)),
                        ],
                      ),
                      trailing: Text(transaction.type.toUpperCase()),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}