import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_user.dart';
import '../utils/app_time.dart';

/// Runs on a background isolate to avoid blocking the UI thread.
Future<Uint8List> _buildEmployeeProfilePdfBytes(Map<String, dynamic> userMap) async {
  final u = AppUser.fromMap(userMap);
  final doc = pw.Document();
  final generated =
      AppTime.toMalaysia(DateTime.now().toUtc()).toString().split('.').first;

  pw.Widget row(String k, String? v) {
    final val = (v == null || v.trim().isEmpty) ? '—' : v.trim();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              k,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(val, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: const pw.PageTheme(margin: pw.EdgeInsets.all(32)),
      build: (ctx) => [
        pw.Text(
          'Employee profile',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Generated: $generated', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
        pw.Text('Personal', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('Full name', u.name),
        row('Username', u.username),
        row('Email', u.email),
        row('Mobile', u.phone),
        row('Address', u.address),
        row('Marital status', u.maritalStatus),
        row(
          'Date of birth',
          u.dateOfBirth?.toIso8601String().split('T').first,
        ),
        row('IC number', u.icNumber),
        pw.SizedBox(height: 8),
        pw.Text('Employment', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('Role', u.isAdmin ? 'Administrator' : 'Employee'),
        row('Position', u.jobTitle),
        row('Department', u.department),
        row('Employee ID', u.employeeCode),
        row(
          'Join date',
          u.employmentStartDate != null
              ? u.employmentStartDate!.toIso8601String().split('T').first
              : '${u.createdAt.day}/${u.createdAt.month}/${u.createdAt.year}',
        ),
        pw.SizedBox(height: 8),
        pw.Text('Statutory (Malaysia)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('EPF', u.epfNumber),
        row('SOCSO', u.socsoNumber),
        pw.SizedBox(height: 8),
        pw.Text('Bank', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('Bank name', u.bankName),
        row('Account no.', u.bankAccountNumber),
        pw.SizedBox(height: 8),
        pw.Text('Education', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('Highest level', u.educationLevel),
        row('Institution', u.educationInstitution),
        pw.SizedBox(height: 8),
        pw.Text('Emergency contact', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        row('Name', u.emergencyContactName),
        row('Relationship', u.emergencyContactRelationship),
        row('Phone', u.emergencyContactPhone),
      ],
    ),
  );

  return doc.save();
}

class EmployeeProfilePdf {
  EmployeeProfilePdf._();

  static Future<void> shareProfilePdf(AppUser u) async {
    final payload = Map<String, dynamic>.from(u.toMap());
    final bytes = await Isolate.run(() => _buildEmployeeProfilePdfBytes(payload));

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/employee_profile_${u.id.substring(0, 8)}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Employee profile: ${u.name}',
    );
  }
}
