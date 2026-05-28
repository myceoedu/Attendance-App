import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_time.dart';
import '../../utils/error_messages.dart';

/// New expense claim: structured fields + **multiple** supporting files
/// (receipts, invoices, scans, spreadsheets, etc.).
class SubmitClaimScreen extends StatefulWidget {
  const SubmitClaimScreen({super.key});

  @override
  State<SubmitClaimScreen> createState() => _SubmitClaimScreenState();
}

class _SubmitClaimScreenState extends State<SubmitClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _category = 'meal';
  String _currency = 'MYR';
  DateTime? _expenseDate;
  final List<PlatformFile> _files = [];
  bool _submitting = false;

  static const _categories = [
    ('meal', 'Meals & refreshments'),
    ('transport', 'Transport & mileage'),
    ('accommodation', 'Accommodation'),
    ('supplies', 'Office supplies & equipment'),
    ('medical', 'Medical'),
    ('communications', 'Phone, data & postage'),
    ('training', 'Training & courses'),
    ('client_entertainment', 'Client entertainment'),
    ('other', 'Other'),
  ];

  static const _currencies = ['MYR', 'USD', 'SGD'];

  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpenseDate() async {
    final now = AppTime.malaysiaNow();
    final first = DateTime(now.year - 1, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? now,
      firstDate: first,
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _expenseDate = picked);
  }

  Future<void> _addFiles() async {
    if (_files.length >= SupabaseService.maxClaimFilesPerSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maximum ${SupabaseService.maxClaimFilesPerSubmit} files per claim',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final remaining =
          SupabaseService.maxClaimFilesPerSubmit - _files.length;
      final toAdd = result.files.take(remaining).toList();
      for (final f in toAdd) {
        try {
          SupabaseService.validateClaimFile(f);
          _files.add(f);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
      if (result.files.length > toAdd.length && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $remaining more file(s) allowed — extra files were skipped.',
            ),
          ),
        );
      }
      setState(() {});
    } on MissingPluginException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File picker not ready. Fully restart the app with flutter run.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick files: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _removeAt(int i) {
    setState(() => _files.removeAt(i));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expenseDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the expense date')),
      );
      return;
    }
    if (_files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attach at least one receipt or document (photo, PDF, invoice, etc.)',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid amount greater than zero'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final uid = context.read<AuthProvider>().user!.id;
      await SupabaseService.submitExpenseClaimWithFiles(
        userId: uid,
        title: _titleCtrl.text,
        description: _descCtrl.text,
        category: _category,
        amount: amount,
        currency: _currency,
        expenseDate: _expenseDate!,
        files: List<PlatformFile>.from(_files),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Claim submitted for review'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyClaimError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('New expense claim')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const Text(
              'Tell finance what the spend was for, how much, and when it happened. '
              'Upload every receipt or proof you have — multiple files are supported.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title / short summary',
                hintText: 'e.g. Client lunch with ABC Corp',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 4) return 'Add a clear title (at least 4 characters)';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _category, // ignore: deprecated_member_use
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final (value, label) in _categories)
                  DropdownMenuItem(value: value, child: Text(label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.,]'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final raw = v?.trim().replaceAll(',', '') ?? '';
                      final n = double.tryParse(raw);
                      if (n == null || n <= 0) return 'Enter amount';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _currency, // ignore: deprecated_member_use
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: [
                      for (final c in _currencies)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickExpenseDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date of expense',
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _expenseDate != null
                      ? _dateFmt.format(_expenseDate!)
                      : 'Tap to choose',
                  style: TextStyle(
                    color: _expenseDate != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                alignLabelWithHint: true,
                labelText: 'Description & details',
                hintText:
                    'What was purchased, project or cost centre, why it was necessary, '
                    'GST / tax if relevant…',
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 12) {
                  return 'Add a bit more detail (at least 12 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: AppColors.orange, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Supporting documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'PDF, images (JPG/PNG/WebP/GIF), Word, Excel, CSV, text, or ZIP. '
              'Up to ${SupabaseService.maxClaimFilesPerSubmit} files, '
              '${SupabaseService.maxClaimAttachmentBytes ~/ (1024 * 1024)} MB each.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _addFiles,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add files'),
            ),
            const SizedBox(height: 12),
            if (_files.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warningLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'At least one file is required (e.g. receipt photo or PDF invoice).',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              )
            else
              ...List.generate(_files.length, (i) {
                final f = _files[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: _submitting ? null : () => _removeAt(i),
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit claim'),
            ),
          ],
        ),
      ),
    );
  }
}
