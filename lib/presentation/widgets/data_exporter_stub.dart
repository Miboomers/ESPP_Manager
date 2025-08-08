import 'package:flutter/material.dart';
import '../../data/models/transaction_model.dart';
import '../screens/export_screen.dart';

class DataExporter {
  static Future<void> exportData({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required ExportFormat format,
    required int year,
  }) async {
    throw UnsupportedError('Data export not supported on this platform');
  }
}