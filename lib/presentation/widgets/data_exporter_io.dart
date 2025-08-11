import 'dart:convert';
import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';
import '../../data/models/transaction_model.dart';
import '../screens/export_screen.dart';

class DataExporter {
  static Future<void> exportData({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required ExportFormat format,
    required int year,
  }) async {
    try {
      if (kIsWeb) {
        // Web: Verwende Web-Export
        await _exportForWeb(context, transactions, format, year);
      } else if (defaultTargetPlatform == TargetPlatform.iOS || 
                 defaultTargetPlatform == TargetPlatform.android) {
        // Mobile: Share-basierter Export
        await _exportForMobile(context, transactions, format, year);
      } else {
        // Desktop: File Picker Export
        await _exportForDesktop(context, transactions, format, year);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export fehlgeschlagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  static Future<void> _exportForWeb(
    BuildContext context,
    List<TransactionModel> transactions,
    ExportFormat format,
    int year,
  ) async {
    // Web-Export wird von data_exporter_web.dart gehandhabt
    // Diese Methode wird nur als Fallback aufgerufen
    throw UnsupportedError('Web-Export wird von data_exporter_web.dart gehandhabt');
  }
  
  static Future<void> _exportForDesktop(
    BuildContext context,
    List<TransactionModel> transactions,
    ExportFormat format,
    int year,
  ) async {
    final fileName = 'ESPP_Export_$year.${_getFileExtension(format)}';
    
    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export speichern',
      fileName: fileName,
      type: _getFileType(format),
    );
    
    if (outputPath == null) return;
    
    switch (format) {
      case ExportFormat.csv:
        await _exportAsCSV(transactions, outputPath);
        break;
      case ExportFormat.excel:
        await _exportAsExcel(transactions, outputPath);
        break;
      case ExportFormat.json:
        await _exportAsJSON(transactions, outputPath);
        break;
    }
    
    await OpenFile.open(outputPath);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export erfolgreich: ${format.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  static Future<void> _exportForMobile(
    BuildContext context,
    List<TransactionModel> transactions,
    ExportFormat format,
    int year,
  ) async {
    final fileName = 'ESPP_Export_$year.${_getFileExtension(format)}';
    
    // Temporäre Datei erstellen
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/$fileName';
    
    switch (format) {
      case ExportFormat.csv:
        await _exportAsCSV(transactions, tempPath);
        break;
      case ExportFormat.excel:
        await _exportAsExcel(transactions, tempPath);
        break;
      case ExportFormat.json:
        await _exportAsJSON(transactions, tempPath);
        break;
    }
    
    // Datei über SharePlus teilen (neue API)
    await SharePlus.instance.share(
      ShareParams(
        text: 'ESPP Export für Steuerjahr $year',
        subject: 'ESPP Export $year',
        files: [XFile(tempPath)],
      ),
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export bereit zum Teilen: ${format.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  static String _getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.json:
        return 'json';
    }
  }
  
  static FileType _getFileType(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return FileType.custom;
      case ExportFormat.excel:
        return FileType.custom;
      case ExportFormat.json:
        return FileType.custom;
    }
  }
  
  static Future<void> _exportAsCSV(List<TransactionModel> transactions, String filePath) async {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln(
      'Kaufdatum,Verkaufsdatum,Anzahl,Kaufpreis USD,Verkaufspreis USD,FMV USD,'
      'ESPP Rabatt %,ESPP Rabatt USD,ESPP Rabatt EUR,'
      'Wechselkurs Kauf,Wechselkurs Verkauf,'
      'Investiert EUR,Verkaufserlös EUR,Gewinn EUR,'
      'Steuerpfl. Kapitalgewinn EUR,Lohnsteuer EUR,Kapitalertragsteuer EUR'
    );
    
    // Daten
    for (final t in transactions) {
      final saleDate = t.saleDate != null 
          ? '${t.saleDate!.day.toString().padLeft(2, '0')}.${t.saleDate!.month.toString().padLeft(2, '0')}.${t.saleDate!.year}'
          : '';
      final salePriceUSD = t.salePricePerShare?.toStringAsFixed(2) ?? '';
      final exchangeRateSale = t.exchangeRateAtSale?.toStringAsFixed(4) ?? '';
      
      // Berechnungen
      final discountUSD = (t.fmvPerShare - t.purchasePricePerShare) * t.quantity;
      final discountPercentage = ((t.fmvPerShare - t.purchasePricePerShare) / t.fmvPerShare) * 100;
      final discountEUR = discountUSD * (t.exchangeRateAtPurchase ?? 0.92);
      final investedEUR = t.totalPurchaseCost * (t.exchangeRateAtPurchase ?? 0.92);
      
      String saleValueEUR = '';
      String gainEUR = '';
      String taxableGainEUR = '';
      String capitalGainsTax = '';
      
      if (t.type == TransactionType.sale && t.salePricePerShare != null && t.exchangeRateAtSale != null) {
        final saleValue = t.salePricePerShare! * t.quantity * t.exchangeRateAtSale!;
        saleValueEUR = saleValue.toStringAsFixed(2);
        
        final gain = t.totalGainEUR ?? 0;
        gainEUR = gain.toStringAsFixed(2);
        
        // Steuerpflichtiger Kapitalgewinn
        final taxableGain = t.taxableCapitalGainEUR ?? 0;
        taxableGainEUR = taxableGain.toStringAsFixed(2);
        
        final capitalGainsTaxAmount = t.capitalGainsTaxEUR ?? 0;
        capitalGainsTax = capitalGainsTaxAmount.toStringAsFixed(2);
      }
      
      buffer.writeln(
        '${t.purchaseDate.day.toString().padLeft(2, '0')}.${t.purchaseDate.month.toString().padLeft(2, '0')}.${t.purchaseDate.year},'
        '$saleDate,'
        '${t.quantity},'
        '${t.purchasePricePerShare.toStringAsFixed(2)},'
        '$salePriceUSD,'
        '${t.fmvPerShare.toStringAsFixed(2)},'
        '${discountPercentage.toStringAsFixed(1)},'
        '${discountUSD.toStringAsFixed(2)},'
        '${discountEUR.toStringAsFixed(2)},'
        '${(t.exchangeRateAtPurchase ?? 0.92).toStringAsFixed(4)},'
        '$exchangeRateSale,'
        '${investedEUR.toStringAsFixed(2)},'
        '$saleValueEUR,'
        '$gainEUR,'
        '$taxableGainEUR,'
        '${(discountEUR * 0.42).toStringAsFixed(2)},'
        '$capitalGainsTax'
      );
    }
    
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
  }
  
  static Future<void> _exportAsExcel(List<TransactionModel> transactions, String filePath) async {
    // Excel-Objekt mit Standard-Sheet erstellen
    final excel = Excel.createExcel();
    
    // Das erste Sheet (Sheet1) direkt verwenden
    final sheet = excel['Sheet1'];
    
    // Header
    final headers = [
      'Kaufdatum', 'Verkaufsdatum', 'Anzahl', 'Kaufpreis USD', 'Verkaufspreis USD', 'FMV USD',
      'ESPP Rabatt %', 'ESPP Rabatt USD', 'ESPP Rabatt EUR',
      'Wechselkurs Kauf', 'Wechselkurs Verkauf',
      'Investiert EUR', 'Verkaufserlös EUR', 'Gewinn EUR',
      'Steuerpfl. Kapitalgewinn EUR', 'Lohnsteuer EUR', 'Kapitalertragsteuer EUR'
    ];
    
    for (int i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
    }
    
    // Daten
    int row = 1;
    for (final t in transactions) {
      final saleDate = t.saleDate != null 
          ? '${t.saleDate!.day.toString().padLeft(2, '0')}.${t.saleDate!.month.toString().padLeft(2, '0')}.${t.saleDate!.year}'
          : '';
      final salePriceUSD = t.salePricePerShare?.toStringAsFixed(2) ?? '';
      final exchangeRateSale = t.exchangeRateAtSale?.toStringAsFixed(4) ?? '';
      
      // Berechnungen
      final discountUSD = (t.fmvPerShare - t.purchasePricePerShare) * t.quantity;
      final discountPercentage = ((t.fmvPerShare - t.purchasePricePerShare) / t.fmvPerShare) * 100;
      final discountEUR = discountUSD * (t.exchangeRateAtPurchase ?? 0.92);
      final investedEUR = t.totalPurchaseCost * (t.exchangeRateAtPurchase ?? 0.92);
      
      String saleValueEUR = '';
      String gainEUR = '';
      String taxableGainEUR = '';
      String capitalGainsTax = '';
      
      if (t.type == TransactionType.sale && t.salePricePerShare != null && t.exchangeRateAtSale != null) {
        final saleValue = t.salePricePerShare! * t.quantity * t.exchangeRateAtSale!;
        saleValueEUR = saleValue.toStringAsFixed(2);
        
        final gain = t.totalGainEUR ?? 0;
        gainEUR = gain.toStringAsFixed(2);
        
        final taxableGain = t.taxableCapitalGainEUR ?? 0;
        taxableGainEUR = taxableGain.toStringAsFixed(2);
        
        final capitalGainsTaxAmount = t.capitalGainsTaxEUR ?? 0;
        capitalGainsTax = capitalGainsTaxAmount.toStringAsFixed(2);
      }
      
      final data = [
        '${t.purchaseDate.day.toString().padLeft(2, '0')}.${t.purchaseDate.month.toString().padLeft(2, '0')}.${t.purchaseDate.year}',
        saleDate,
        t.quantity.toString(),
        t.purchasePricePerShare.toStringAsFixed(2),
        salePriceUSD,
        t.fmvPerShare.toStringAsFixed(2),
        discountPercentage.toStringAsFixed(1),
        discountUSD.toStringAsFixed(2),
        discountEUR.toStringAsFixed(2),
        (t.exchangeRateAtPurchase ?? 0.92).toStringAsFixed(4),
        exchangeRateSale,
        investedEUR.toStringAsFixed(2),
        saleValueEUR,
        gainEUR,
        taxableGainEUR,
        (discountEUR * 0.42).toStringAsFixed(2),
        capitalGainsTax
      ];
      
      for (int i = 0; i < data.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row)).value = TextCellValue(data[i]);
      }
      row++;
    }
    
    final file = File(filePath);
    await file.writeAsBytes(excel.encode()!);
  }
  
  static Future<void> _exportAsJSON(List<TransactionModel> transactions, String filePath) async {
    final jsonData = {
      'exportDate': DateTime.now().toIso8601String(),
      'year': transactions.first.purchaseDate.year,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
    
    final file = File(filePath);
    await file.writeAsString(jsonEncode(jsonData));
  }
}