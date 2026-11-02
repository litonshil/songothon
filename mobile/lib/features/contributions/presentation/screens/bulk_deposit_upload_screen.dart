import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/bulk_deposit_result_model.dart';
import '../../data/repositories/contribution_repository.dart';

/// Admin screen: pick a deposits .xlsx, preview it (server dry run), then import.
/// Pops with `true` when deposits were imported.
class BulkDepositUploadScreen extends StatefulWidget {
  final String orgSlug;

  const BulkDepositUploadScreen({super.key, required this.orgSlug});

  static Future<bool?> open(BuildContext context, {required String orgSlug}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BulkDepositUploadScreen(orgSlug: orgSlug)),
    );
  }

  @override
  State<BulkDepositUploadScreen> createState() => _BulkDepositUploadScreenState();
}

class _BulkDepositUploadScreenState extends State<BulkDepositUploadScreen> {
  static const _maxBytes = 5 * 1024 * 1024;
  static const _paymentMethods = {
    'cash': 'Cash',
    'bkash': 'bKash',
    'nagad': 'Nagad',
    'rocket': 'Rocket',
    'bank_transfer': 'Bank Transfer',
  };

  String _paymentMethod = 'cash';
  String? _fileName;
  Uint8List? _bytes;
  BulkDepositResultModel? _preview;
  String? _error;
  bool _busy = false;

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx']);
      if (files.isEmpty) return;
      final file = files.first;
      if ((file.extension ?? '').toLowerCase() != 'xlsx') {
        _showError('Please choose an .xlsx file.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxBytes) {
        _showError('File is too large; the limit is 5 MB.');
        return;
      }
      setState(() {
        _fileName = file.name;
        _bytes = bytes;
        _preview = null;
        _error = null;
      });
      await _runPreview();
    } catch (e) {
      _showError('Could not open the file: $e');
    }
  }

  Future<void> _runPreview() async {
    if (_bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await context.read<ContributionRepository>().bulkUploadDeposits(
            slug: widget.orgSlug,
            bytes: _bytes!,
            fileName: _fileName ?? 'deposits.xlsx',
            paymentMethod: _paymentMethod,
            dryRun: true,
          );
      if (!mounted) return;
      setState(() => _preview = result);
    } on BulkDepositValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = e.result;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final preview = _preview;
    if (_bytes == null || preview == null) return;
    final ok = await confirmAction(
      context,
      title: 'Import deposits?',
      message: '${preview.createCount} deposits totalling ${formatMoney(preview.createAmount)} '
          'for ${preview.memberCount} members will be recorded as approved '
          '(${_paymentMethods[_paymentMethod]}). Members will be notified.',
      confirmLabel: 'Import',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await context.read<ContributionRepository>().bulkUploadDeposits(
            slug: widget.orgSlug,
            bytes: _bytes!,
            fileName: _fileName ?? 'deposits.xlsx',
            paymentMethod: _paymentMethod,
            dryRun: false,
          );
      if (!mounted) return;
      final msg = result.imported
          ? 'Imported ${result.createCount} deposits (${formatMoney(result.createAmount)}).'
          : 'Nothing new to import; these deposits are already recorded.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(result.imported);
    } on BulkDepositValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = e.result;
        _error = e.message;
      });
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppTheme.errorRed));
  }

  bool get _canImport => !_busy && _preview != null && !_preview!.hasErrors && _preview!.createCount > 0;

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Bulk Deposit Upload')),
      bottomNavigationBar: preview == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _canImport ? _import : null,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(preview.createCount > 0 && !preview.hasErrors
                    ? 'Import ${preview.createCount} deposits'
                    : preview.hasErrors
                        ? 'Fix errors to import'
                        : 'Nothing new to import'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _FormatHelpCard(),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method for all rows', prefixIcon: Icon(Icons.payments_outlined)),
            items: _paymentMethods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _paymentMethod = v ?? 'cash'),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(_fileName == null ? 'Choose .xlsx file' : 'Choose a different file'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_fileName!, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (_busy && preview == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy)),
            ),
          if (_error != null && (preview == null || !preview.hasErrors)) _ErrorBanner(message: _error!),
          if (preview != null) ..._buildPreview(preview),
        ],
      ),
    );
  }

  List<Widget> _buildPreview(BulkDepositResultModel p) {
    final widgets = <Widget>[
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          StatTile(label: 'Deposits to import', value: '${p.createCount}', icon: Icons.add_task_rounded),
          StatTile(label: 'Amount to import', value: formatMoney(p.createAmount), icon: Icons.account_balance_wallet_outlined),
          StatTile(label: 'Members', value: '${p.memberCount}', icon: Icons.people_alt_outlined, accent: AppTheme.primaryBlue),
          StatTile(
            label: 'Already recorded (skipped)',
            value: '${p.skippedCount}',
            icon: Icons.history_rounded,
            accent: AppTheme.warningOrange,
          ),
        ],
      ),
      if (p.cycles.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          'Cycles: ${formatCycle(p.cycles.first)} – ${formatCycle(p.cycles.last)}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ],
      const SizedBox(height: 18),
    ];

    if (p.hasErrors) {
      widgets.addAll([
        SectionHeader(title: '${p.errors.length} problem${p.errors.length == 1 ? '' : 's'} to fix'),
        const SizedBox(height: 8),
        ...p.errors.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (e.location.isNotEmpty)
                            Text(e.location, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          Text(e.message, style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 10),
        const Text(
          'Nothing has been imported. Fix the sheet and choose it again.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ]);
      return widgets;
    }

    // Group per member for a compact preview.
    final byMember = <String, List<BulkDepositItemModel>>{};
    for (final item in p.items) {
      byMember.putIfAbsent(item.email, () => []).add(item);
    }
    widgets.add(const SectionHeader(title: 'Preview by member'));
    widgets.add(const SizedBox(height: 8));
    for (final entry in byMember.entries) {
      final items = entry.value;
      final newItems = items.where((i) => !i.isSkipped).toList();
      final total = newItems.fold<double>(0, (sum, i) => sum + i.amount);
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items.first.memberName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(entry.key, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(total), style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    '${newItems.length} new'
                    '${items.length > newItems.length ? ' • ${items.length - newItems.length} skipped' : ''}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ));
    }
    return widgets;
  }
}

class _FormatHelpCard extends StatelessWidget {
  const _FormatHelpCard();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12.5, color: AppTheme.textDark, height: 1.45);
    return AppCard(
      color: AppTheme.primaryBlue.withValues(alpha: 0.04),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryBlue),
              SizedBox(width: 8),
              Text('Sheet format', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          SizedBox(height: 8),
          Text('• Row 1 is the header: an "Email" column, then one column per month named like 2026-01.', style: style),
          Text('• One row per member, using the email they log in with.', style: style),
          Text('• Each amount becomes an approved deposit for that month. Leave a cell blank if nothing was paid.', style: style),
          Text('• Uploading the same sheet again skips deposits that were already imported.', style: style),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      color: AppTheme.errorRed.withValues(alpha: 0.06),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}
