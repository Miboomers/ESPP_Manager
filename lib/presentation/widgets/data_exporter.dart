import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
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
      if (Platform.isIOS || Platform.isAndroid) {
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
    
    // Datei über Share Dialog teilen
    await Share.shareXFiles(
      [XFile(tempPath)],
      subject: 'ESPP Export $year',
      text: 'ESPP Export für Steuerjahr $year',
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
      
      final incomeTax = (discountEUR * 0.42).toStringAsFixed(2);
      
      buffer.writeln(
        '${t.purchaseDate.day.toString().padLeft(2, '0')}.${t.purchaseDate.month.toString().padLeft(2, '0')}.${t.purchaseDate.year},'
        '$saleDate,'
        '${t.quantity.toStringAsFixed(4)},'
        '${t.purchasePricePerShare.toStringAsFixed(2)},'
        '$salePriceUSD,'
        '${t.fmvPerShare.toStringAsFixed(2)},'
        '${discountPercentage.toStringAsFixed(0)},'
        '${discountUSD.toStringAsFixed(2)},'
        '${discountEUR.toStringAsFixed(2)},'
        '${t.exchangeRateAtPurchase?.toStringAsFixed(4) ?? ''},'
        '$exchangeRateSale,'
        '${investedEUR.toStringAsFixed(2)},'
        '$saleValueEUR,'
        '$gainEUR,'
        '$taxableGainEUR,'
        '$incomeTax,'
        '$capitalGainsTax'
      );
    }
    
    // Datei direkt am gewählten Pfad speichern
    final file = File(filePath);
    await file.writeAsString(buffer.toString());
  }
  
  static Future<void> _exportAsExcel(List<TransactionModel> transactions, String filePath) async {
    final excel = Excel.createExcel();
    final sheet = excel['ESPP_Data'];
    
    // Header
    sheet.appendRow([
      TextCellValue('Kaufdatum'),
      TextCellValue('Verkaufsdatum'),
      TextCellValue('Anzahl'),
      TextCellValue('Kaufpreis USD'),
      TextCellValue('Verkaufspreis USD'),
      TextCellValue('FMV USD'),
      TextCellValue('ESPP Rabatt %'),
      TextCellValue('ESPP Rabatt USD'),
      TextCellValue('ESPP Rabatt EUR'),
      TextCellValue('Wechselkurs Kauf'),
      TextCellValue('Wechselkurs Verkauf'),
      TextCellValue('Investiert EUR'),
      TextCellValue('Verkaufserlös EUR'),
      TextCellValue('Gewinn EUR'),
      TextCellValue('Steuerpfl. Kapitalgewinn EUR'),
      TextCellValue('Lohnsteuer EUR'),
      TextCellValue('Kapitalertragsteuer EUR'),
    ]);
    
    // Daten
    for (final t in transactions) {
      final saleDate = t.saleDate != null 
          ? '${t.saleDate!.day.toString().padLeft(2, '0')}.${t.saleDate!.month.toString().padLeft(2, '0')}.${t.saleDate!.year}'
          : '';
      
      // Berechnungen
      final discountUSD = (t.fmvPerShare - t.purchasePricePerShare) * t.quantity;
      final discountPercentage = ((t.fmvPerShare - t.purchasePricePerShare) / t.fmvPerShare) * 100;
      final discountEUR = discountUSD * (t.exchangeRateAtPurchase ?? 0.92);
      final investedEUR = t.totalPurchaseCost * (t.exchangeRateAtPurchase ?? 0.92);
      final incomeTax = discountEUR * 0.42;
      
      double? saleValueEUR;
      double? gainEUR;
      double? taxableGainEUR;
      double? capitalGainsTax;
      
      if (t.type == TransactionType.sale && t.salePricePerShare != null && t.exchangeRateAtSale != null) {
        saleValueEUR = t.salePricePerShare! * t.quantity * t.exchangeRateAtSale!;
        gainEUR = t.totalGainEUR ?? 0;
        
        taxableGainEUR = t.taxableCapitalGainEUR ?? 0;
        capitalGainsTax = t.capitalGainsTaxEUR ?? 0;
      }
      
      sheet.appendRow([
        TextCellValue('${t.purchaseDate.day.toString().padLeft(2, '0')}.${t.purchaseDate.month.toString().padLeft(2, '0')}.${t.purchaseDate.year}'),
        TextCellValue(saleDate),
        DoubleCellValue(t.quantity),
        DoubleCellValue(t.purchasePricePerShare),
        if (t.salePricePerShare != null) DoubleCellValue(t.salePricePerShare!) else TextCellValue(''),
        DoubleCellValue(t.fmvPerShare),
        DoubleCellValue(discountPercentage),
        DoubleCellValue(discountUSD),
        DoubleCellValue(discountEUR),
        if (t.exchangeRateAtPurchase != null) DoubleCellValue(t.exchangeRateAtPurchase!) else TextCellValue(''),
        if (t.exchangeRateAtSale != null) DoubleCellValue(t.exchangeRateAtSale!) else TextCellValue(''),
        DoubleCellValue(investedEUR),
        if (saleValueEUR != null) DoubleCellValue(saleValueEUR) else TextCellValue(''),
        if (gainEUR != null) DoubleCellValue(gainEUR) else TextCellValue(''),
        if (taxableGainEUR != null) DoubleCellValue(taxableGainEUR) else TextCellValue(''),
        DoubleCellValue(incomeTax),
        if (capitalGainsTax != null) DoubleCellValue(capitalGainsTax) else TextCellValue(''),
      ]);
    }
    
    // Datei direkt am gewählten Pfad speichern
    final file = File(filePath);
    final bytes = excel.encode()!;
    await file.writeAsBytes(bytes);
  }
  
  static Future<void> _exportAsJSON(List<TransactionModel> transactions, String filePath) async {
    final List<Map<String, dynamic>> jsonData = [];
    
    for (final t in transactions) {
      // Berechnungen
      final discountUSD = (t.fmvPerShare - t.purchasePricePerShare) * t.quantity;
      final discountPercentage = ((t.fmvPerShare - t.purchasePricePerShare) / t.fmvPerShare) * 100;
      final discountEUR = discountUSD * (t.exchangeRateAtPurchase ?? 0.92);
      final investedEUR = t.totalPurchaseCost * (t.exchangeRateAtPurchase ?? 0.92);
      final incomeTax = discountEUR * 0.42;
      
      final data = {
        'kaufdatum': t.purchaseDate.toIso8601String(),
        'verkaufsdatum': t.saleDate?.toIso8601String(),
        'anzahl': t.quantity,
        'kaufpreis_usd': t.purchasePricePerShare,
        'verkaufspreis_usd': t.salePricePerShare,
        'fmv_usd': t.fmvPerShare,
        'espp_rabatt_prozent': discountPercentage,
        'espp_rabatt_usd': discountUSD,
        'espp_rabatt_eur': discountEUR,
        'wechselkurs_kauf': t.exchangeRateAtPurchase,
        'wechselkurs_verkauf': t.exchangeRateAtSale,
        'investiert_eur': investedEUR,
        'lohnsteuer_eur': incomeTax,
      };
      
      if (t.type == TransactionType.sale && t.salePricePerShare != null && t.exchangeRateAtSale != null) {
        final saleValueEUR = t.salePricePerShare! * t.quantity * t.exchangeRateAtSale!;
        
        data['verkaufserlos_eur'] = saleValueEUR;
        data['gewinn_eur'] = t.totalGainEUR;
        data['steuerpfl_kapitalgewinn_eur'] = t.taxableCapitalGainEUR;
        data['kapitalertragsteuer_eur'] = t.capitalGainsTaxEUR;
      }
      
      jsonData.add(data);
    }
    
    // JSON formatieren
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert({
      'export_datum': DateTime.now().toIso8601String(),
      'anzahl_transaktionen': transactions.length,
      'transaktionen': jsonData,
    });
    
    // Datei direkt am gewählten Pfad speichern
    final file = File(filePath);
    await file.writeAsString(jsonString);
  }
}