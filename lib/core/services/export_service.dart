import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/entities.dart';

class ExportService {
  static Future<void> saveCsv(ExportTable t) async {
    final rows = <List<dynamic>>[t.headers, ...t.rows];
    final csv = const ListToCsvConverter().convert(rows);
    await FileSaver.instance.saveFile(
      name: t.fileName,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static Future<void> savePdf(ExportTable t) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Text('MoneyMind', style: pw.TextStyle(fontSize: 11, color: PdfColors.green800)),
        pw.SizedBox(height: 4),
        pw.Text(t.title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        for (final s in t.summary) pw.Text(s, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: t.headers,
          data: t.rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ));
    final bytes = await doc.save();
    await FileSaver.instance.saveFile(
      name: t.fileName,
      bytes: Uint8List.fromList(bytes),
      ext: 'pdf',
      mimeType: MimeType.pdf,
    );
  }
}
