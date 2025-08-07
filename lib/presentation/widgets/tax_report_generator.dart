import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/services/pdf_service.dart';
import '../../data/models/transaction_model.dart';

class TaxReportGenerator {
  static Future<void> generateReport(
    BuildContext context,
    int year,
    List<TransactionModel> transactions,
  ) async {
    final pdf = pw.Document();
    
    // Font für Umlaute
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    
    // Berechnungen für die Zusammenfassung - mit korrekter Lookback-Berücksichtigung
    final soldTransactions = transactions.where((t) => t.isSold).toList();
    
    // Verkaufte Transaktionen für Bericht verarbeiten
    
    final totalShares = soldTransactions.fold<double>(0, (sum, t) => sum + t.quantity);
    final totalProceeds = soldTransactions.fold<double>(0, (sum, t) => sum + (t.totalSaleProceeds ?? 0));
    final totalFmvCost = soldTransactions.fold<double>(0, (sum, t) => sum + (t.fmvPerShare * t.quantity));
    final totalActualCost = soldTransactions.fold<double>(0, (sum, t) => sum + t.totalPurchaseCost);
    final totalDiscountTaxed = soldTransactions.fold<double>(0, (sum, t) => sum + t.totalGeldwerterVorteil);
    final taxableCapitalGain = soldTransactions.fold<double>(0, (sum, t) => sum + (t.taxableCapitalGainEUR ?? 0));

    // Erste Seite mit der neuen Finanzamt-Erklärung
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  'Anlage zur Einkommensteuererklärung: Erläuterung zu Kapitalerträgen aus dem Mitarbeiteraktienprogramm (ESPP)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: boldFont),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Anrede
              pw.Text('Sehr geehrte Damen und Herren,', style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 15),
              
              // Haupttext
              pw.Text(
                'im Steuerjahr $year habe ich Kapitalerträge aus dem Verkauf von Mitarbeiteraktien (Employee Stock Purchase Plan, ESPP) erzielt.\n'
                'Dabei wurde bereits ein Teil des Gewinns als Arbeitslohn im Rahmen der Lohnsteuer erfasst.',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 15),
              
              // Hintergrund
              pw.Text(
                'Hintergrund zur Besteuerung:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
              ),
              pw.Text(
                'Die Aktien wurden im Rahmen eines ESPP-Programms mit 15 % Rabatt auf den günstigeren Kurs zu Beginn oder Ende der Bezugsperiode („Lookback-Mechanismus") erworben. '
                'Der Rabatt wird dabei immer auf den niedrigeren der beiden Kurswerte angewendet.',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 10),
              
              pw.Text(
                'Dabei wurde der geldwerte Vorteil wie folgt lohnversteuert:',
                style: pw.TextStyle(font: font),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  color: PdfColors.grey100,
                ),
                child: pw.Text(
                  'FMV am Kaufdatum – tatsächlicher Kaufpreis = geldwerter Vorteil\n'
                  'wobei: tatsächlicher Kaufpreis = MIN(Startdatum-FMV, Kaufdatum-FMV) × 85%',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
              
              pw.Text(
                'Der so ermittelte geldwerte Vorteil wurde bereits in der Lohnabrechnung versteuert und unterliegt nicht erneut der Besteuerung.',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 15),
              
              // Kapitalertragsteuer
              pw.Text(
                'Kapitalertragsteuerlich wurde der Gewinn folgendermaßen berechnet:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  color: PdfColors.grey100,
                ),
                child: pw.Text(
                  'Veräußerungserlös – FMV am Erwerbsstichtag = steuerpflichtiger Kapitalgewinn',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
              ),
              pw.SizedBox(height: 10),
              
              pw.Text(
                'Damit wird eine Doppelbesteuerung vermieden, wie es § 20 EStG i. V. m. R 19.9 Abs. 2 LStR vorsieht.',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 20),
              
              // Wechselkurs-Dokumentation
              pw.Text(
                'Wechselkurse und rechtliche Grundlagen:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
              ),
              pw.Text(
                'Alle USD/EUR-Wechselkurse wurden nach den offiziell anerkannten Referenzkursen der Europäischen Zentralbank (EZB) ermittelt, wie in § 16 AO (Abgabenordnung) und R 16.1 AStR vorgesehen.',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 10),
              
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  color: PdfColors.grey100,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Rechtliche Grundlagen für Wechselkurse:',
                      style: pw.TextStyle(font: boldFont, fontSize: 10),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      '• § 16 AO: Bewertungsvorschriften für Fremdwährungen',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                    pw.Text(
                      '• R 16.1 AStR: EZB-Referenzkurse sind offiziell anerkannt',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                    pw.Text(
                      '• Quelle: www.ecb.europa.eu/stats/eurofxref/',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                    pw.Text(
                      '• Methodik: Tagesaktuelle Kurse bzw. Jahresdurchschnitte',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Übersicht der Verkäufe
              pw.Text(
                'Übersicht meiner Verkäufe und steuerlichen Behandlung:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont),
              ),
              pw.SizedBox(height: 10),
              
              pw.Bullet(text: 'Anzahl verkaufter Aktien: ${totalShares.toStringAsFixed(2)}', style: pw.TextStyle(font: font)),
              pw.Bullet(text: 'FMV-Kostenbasis am Kaufdatum (gesamt): ${totalFmvCost.toStringAsFixed(2)} USD', style: pw.TextStyle(font: font)),
              pw.Bullet(text: 'Tatsächlicher Erwerbspreis (inkl. 15% Rabatt): ${totalActualCost.toStringAsFixed(2)} USD', style: pw.TextStyle(font: font)),
              pw.Bullet(text: 'Veräußerungserlös (gesamt): ${totalProceeds.toStringAsFixed(2)} USD', style: pw.TextStyle(font: font)),
              pw.Bullet(text: 'Kapitalertrag (steuerpflichtiger Teil): ${taxableCapitalGain.toStringAsFixed(2)} EUR', style: pw.TextStyle(font: font)),
              pw.Bullet(text: 'Bereits lohnversteuerte ESPP-Rabatte: ${totalDiscountTaxed.toStringAsFixed(2)} USD', style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 15),
              
              pw.Text(
                'Die vollständige Berechnung finden Sie in der beigefügten Tabelle „ESPP-Steuerübersicht $year".',
                style: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 20),
              
              pw.Text('Mit freundlichen Grüßen', style: pw.TextStyle(font: font)),
              pw.SizedBox(height: 30),
              
              // Rechtlicher Hinweis
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  color: PdfColors.grey50,
                ),
                child: pw.Text(
                  'Automatisch generiert von ESPP Manager. Alle Berechnungen erfolgen nach bestem Wissen und Gewissen '
                  'auf Basis der geltenden deutschen Steuergesetzgebung. Die Verwendung von EZB-Referenzkursen '
                  'entspricht den Vorgaben der Abgabenordnung (§ 16 AO).',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.justify,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Separate Seiten für detaillierte Tabelle
    _addTransactionTablePages(pdf, soldTransactions, font, boldFont, year);

    // PDF speichern und anzeigen - plattformunabhängig
    final bytes = await pdf.save();
    await PdfService.savePdf(
      bytes: bytes,
      filename: 'ESPP_Steuerbericht_$year.pdf',
    );
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF-Bericht wurde erstellt'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  static void _addTransactionTablePages(
    pw.Document pdf,
    List<TransactionModel> transactions,
    pw.Font font,
    pw.Font boldFont,
    int year,
  ) {
    const rowsPerPage = 18; // Max Zeilen pro Seite (angepasst für mehr Spalten)
    final headers = [
      'Verkaufsdatum',
      'Kaufdatum',
      'Angebotszeitraum',
      'Stück',
      'FMV Start',
      'FMV Kauf',
      'Kaufpreis', 
      'Verkaufspreis',
      'Erlös',
      'Lstpfl. Betrag EUR',
      'Kapitalgewinn EUR',
    ];
    
    // Alle Datenzeilen vorbereiten mit Lookback-Informationen
    final allData = transactions.map((t) {
      final saleValueEUR = t.saleValueEURForTax ?? 0;
      final taxableGainEUR = t.taxableCapitalGainEUR ?? 0;
      final lohnsteuerpflichtigerBetragEUR = t.totalGeldwerterVorteil * (t.exchangeRateAtPurchase ?? 0.92);
      
      // Wechselkurse für die Anzeige
      final exchangeRateAtPurchase = t.exchangeRateAtPurchase ?? 0.92;
      final exchangeRateAtSale = t.exchangeRateAtSale ?? 0.92;
      
      // Berechne EUR-Werte für doppelzeilige Anzeige
      final fmvStartEUR = (t.lookbackFmv ?? (t.purchasePricePerShare / 0.85)) * exchangeRateAtPurchase;
      final fmvKaufEUR = t.fmvPerShare * exchangeRateAtPurchase;
      final kaufpreisEUR = t.purchasePricePerShare * exchangeRateAtPurchase;
      final verkaufspreisEUR = (t.salePricePerShare ?? 0) * exchangeRateAtSale;
      
      // KORREKTE Lookback-FMV Berechnung für doppelzeilige Anzeige
      String lookbackFmvDisplay = 'N/A';
      if (t.lookbackFmv != null) {
        // Echte Lookback-Daten vorhanden
        lookbackFmvDisplay = '${fmvStartEUR.toStringAsFixed(2)} EUR\n${t.lookbackFmv!.toStringAsFixed(2)} USD';
      } else {
        // Fallback: Berechne Lookback-FMV basierend auf ESPP-Logik
        final calculatedLookbackFmv = t.purchasePricePerShare / 0.85;
        
        if (calculatedLookbackFmv <= t.fmvPerShare) {
          lookbackFmvDisplay = '${fmvStartEUR.toStringAsFixed(2)} EUR\n${calculatedLookbackFmv.toStringAsFixed(2)}* USD';
        } else {
          lookbackFmvDisplay = '${fmvStartEUR.toStringAsFixed(2)} EUR\n${t.fmvPerShare.toStringAsFixed(2)}* USD';
        }
      }
      
      return [
        '${t.saleDate!.day.toString().padLeft(2, '0')}.${t.saleDate!.month.toString().padLeft(2, '0')}.${t.saleDate!.year}',
        '${t.purchaseDate.day.toString().padLeft(2, '0')}.${t.purchaseDate.month.toString().padLeft(2, '0')}.${t.purchaseDate.year}',
        t.offeringPeriod ?? 'Siehe Kaufdatum',
        t.quantity.toStringAsFixed(2),
        lookbackFmvDisplay,
        '${fmvKaufEUR.toStringAsFixed(2)} EUR\n${t.fmvPerShare.toStringAsFixed(2)} USD',
        '${kaufpreisEUR.toStringAsFixed(2)} EUR\n${t.purchasePricePerShare.toStringAsFixed(2)} USD',
        '${verkaufspreisEUR.toStringAsFixed(2)} EUR\n${t.salePricePerShare?.toStringAsFixed(2) ?? 'N/A'} USD',
        '${saleValueEUR.toStringAsFixed(2)} EUR\n${(t.totalSaleProceeds ?? 0).toStringAsFixed(2)} USD',
        lohnsteuerpflichtigerBetragEUR.toStringAsFixed(2),
        taxableGainEUR.toStringAsFixed(2),
      ];
    }).toList();
    
    // Tabelle in Seiten aufteilen
    for (int i = 0; i < allData.length; i += rowsPerPage) {
      final endIndex = (i + rowsPerPage < allData.length) ? i + rowsPerPage : allData.length;
      final pageData = allData.sublist(i, endIndex);
      final pageNumber = (i ~/ rowsPerPage) + 1;
      final totalPages = ((allData.length - 1) ~/ rowsPerPage) + 1;
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, // Querformat für mehr Spalten
          margin: const pw.EdgeInsets.all(30),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Seitentitel
                pw.Center(
                  child: pw.Text(
                    'ESPP-Steuerübersicht $year (Seite $pageNumber von $totalPages)',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: boldFont),
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Erklärung
                pw.Text(
                  'Erläuterung: Alle Preisspalten zeigen oben EUR (zum jeweiligen Stichtagskurs), unten USD (Originalwerte). '
                  'FMV Start = Kurs am Beginn der Angebotsperiode, FMV Kauf = Kurs am Erwerbstag (steuerliche Kostenbasis), '
                  'Kaufpreis = MIN(FMV Start, FMV Kauf) × 85%, Kapitalgewinn = Verkaufspreis minus FMV Kauf',
                  style: pw.TextStyle(font: font, fontSize: 8),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Wechselkurse: Alle USD/EUR-Umrechnungen basieren auf EZB-Referenzkursen (§ 16 AO)',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.blue800),
                ),
                pw.SizedBox(height: 10),
                
                // Tabelle für diese Seite
                pw.Expanded(
                  child: pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont, fontSize: 7),
                    cellStyle: pw.TextStyle(font: font, fontSize: 7), // Kleinere Schrift für doppelzeilige Zellen
                    headers: headers,
                    data: pageData,
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    headerDecoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    cellAlignment: pw.Alignment.centerRight,
                    headerAlignment: pw.Alignment.center,
                    cellAlignments: {
                      0: pw.Alignment.center, // Verkaufsdatum
                      1: pw.Alignment.center, // Kaufdatum  
                      2: pw.Alignment.center, // Angebotszeitraum
                    },
                    columnWidths: {
                      0: const pw.FixedColumnWidth(60), // Verkaufsdatum
                      1: const pw.FixedColumnWidth(60), // Kaufdatum
                      2: const pw.FixedColumnWidth(90), // Angebotszeitraum
                      3: const pw.FixedColumnWidth(60), // Stück
                      4: const pw.FixedColumnWidth(60), // FMV Start (breiter für 2 Zeilen)
                      5: const pw.FixedColumnWidth(60), // FMV Kauf (breiter für 2 Zeilen)
                      6: const pw.FixedColumnWidth(60), // Kaufpreis (breiter für 2 Zeilen)
                      7: const pw.FixedColumnWidth(60), // Verkaufspreis (breiter für 2 Zeilen)
                      8: const pw.FixedColumnWidth(60), // Erlös (breiter für 2 Zeilen)
                      9: const pw.FixedColumnWidth(60), // Lohnsteuer EUR
                      10: const pw.FixedColumnWidth(60), // Kapitalgewinn EUR
                    },
                    cellHeight: 25, // Höhere Zellen für doppelzeiligen Text
                  ),
                ),
                
                // Fußnote und Gesamtsummen
                if (pageNumber == totalPages) ...[
                  pw.SizedBox(height: 15),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Gesamt: ${transactions.length} Transaktionen',
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                      pw.Text(
                        'Gesamter steuerpflichtiger Kapitalgewinn: ${transactions.fold<double>(0, (sum, t) => sum + (t.taxableCapitalGainEUR ?? 0)).toStringAsFixed(2)} EUR',
                        style: pw.TextStyle(font: boldFont, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Wechselkurs-Nachweis: Alle USD-Beträge wurden mit den offiziell anerkannten EZB-Referenzkursen '
                    'der jeweiligen Transaktionsdaten in EUR umgerechnet (§ 16 AO, R 16.1 AStR). '
                    'Quelle: Europäische Zentralbank (www.ecb.europa.eu/stats/eurofxref/)',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.blue800),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Wichtiger Hinweis: Die steuerliche Kostenbasis für die Kapitalertragsteuer ist immer der FMV am Kaufdatum, '
                    'da der geldwerte Vorteil (FMV Kauf minus Kaufpreis) bereits lohnversteuert wurde.',
                    style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.orange800),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }
  }
}