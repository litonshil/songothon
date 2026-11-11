import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/settlement_model.dart';
import '../../data/repositories/org_repository.dart';

/// Admin screen to pay out a member who is leaving: shows their deposits and
/// share of the organization's profit, lets the admin adjust the amount, and
/// records the payout. On success it pops with `true`.
class SettleMemberScreen extends StatefulWidget {
  final String orgSlug;
  final String userId;
  final String memberName;

  const SettleMemberScreen({super.key, required this.orgSlug, required this.userId, required this.memberName});

  static Future<bool> open(BuildContext context, {required String orgSlug, required String userId, required String memberName}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SettleMemberScreen(orgSlug: orgSlug, userId: userId, memberName: memberName)),
    );
    return result == true;
  }

  @override
  State<SettleMemberScreen> createState() => _SettleMemberScreenState();
}

class _SettleMemberScreenState extends State<SettleMemberScreen> {
  static const _methods = [
    ('cash', 'Cash'),
    ('bkash', 'bKash'),
    ('nagad', 'Nagad'),
    ('rocket', 'Rocket'),
    ('bank_transfer', 'Bank Transfer'),
  ];

  SettlementPreviewModel? _preview;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  final _amountController = TextEditingController();
  final _trxController = TextEditingController();
  final _notesController = TextEditingController();
  String _method = 'cash';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _trxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await context.read<OrgRepository>().getSettlementPreview(widget.orgSlug, widget.userId);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _amountController.text = preview.calculatedAmount.toStringAsFixed(2);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double? get _enteredAmount => double.tryParse(_amountController.text.trim());

  double get _adjustment {
    final p = _preview;
    final amount = _enteredAmount;
    if (p == null || amount == null) return 0;
    return double.parse((amount - p.calculatedAmount).toStringAsFixed(2));
  }

  String? _validate() {
    final amount = _enteredAmount;
    if (amount == null || amount < 0) return 'Enter a valid payout amount.';
    if (_adjustment != 0 && _notesController.text.trim().isEmpty) {
      return 'Add a note explaining why the amount differs from the calculated settlement.';
    }
    if (amount > 0 && _method != 'cash' && _trxController.text.trim().isEmpty) {
      return 'Transaction ID is required for non-cash payouts.';
    }
    return null;
  }

  Future<void> _submit() async {
    final p = _preview!;
    final problem = _validate();
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem), backgroundColor: AppTheme.errorRed));
      return;
    }
    final amount = _enteredAmount!;
    final ok = await confirmAction(
      context,
      title: 'Settle ${p.fullName}?',
      message: 'Pay ${formatMoney(amount, p.currency)} via ${_methodLabel(_method)} and end their membership. '
          'This is recorded in the ledger and cannot be undone.',
      confirmLabel: 'Settle & Pay',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _submitting = true);
    try {
      await context.read<OrgRepository>().settleMember(
        slug: widget.orgSlug,
        userId: widget.userId,
        finalAmount: amount,
        paymentMethod: _method,
        trxId: _trxController.text,
        notes: _notesController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.fullName} has been settled.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  String _methodLabel(String id) => _methods.firstWhere((m) => m.$1 == id, orElse: () => (id, humanize(id))).$2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Settlement')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not calculate settlement', message: _error!, actionLabel: 'Retry', onAction: _load)
              : _buildBody(_preview!),
    );
  }

  Widget _buildBody(SettlementPreviewModel p) {
    final c = p.currency;
    final amount = _enteredAmount ?? 0;
    final adjustment = _adjustment;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        AppCard(
          color: AppTheme.primaryNavy,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.fullName.isEmpty ? widget.memberName : p.fullName,
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${humanize(p.role)} • ${p.sharesCount} shares • ${humanize(p.status)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 16),
              Text('Calculated payout', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
              const SizedBox(height: 2),
              Text(formatMoney(p.calculatedAmount, c),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        if (!p.canSettle) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppTheme.errorRed.withValues(alpha: 0.08),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block_rounded, color: AppTheme.errorRed, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(p.blockReason ?? 'This member cannot be settled right now.',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.errorRed, height: 1.4, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionHeader(title: 'Member Breakdown'),
        AppCard(
          child: Column(
            children: [
              _row('Approved deposits', formatMoney(p.totalDeposits, c)),
              _row('Ownership of deposits', '${p.ownershipPercent.toStringAsFixed(2)}%'),
              _row(p.profitShare >= 0 ? 'Share of profit' : 'Share of loss', _signed(p.profitShare, c),
                  valueColor: p.profitShare >= 0 ? AppTheme.darkGreen : AppTheme.errorRed),
              const Divider(height: 20),
              _row('Calculated payout', formatMoney(p.calculatedAmount, c), bold: true),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'How profit was calculated'),
        AppCard(
          child: Column(
            children: [
              _row('Total income', formatMoney(p.totalIncome, c)),
              _row('Total expenses', '- ${formatMoney(p.totalExpense, c)}'),
              _row('Realized investment returns', formatMoney(p.realizedReturns, c)),
              _row('Unrealized gain / loss', _signed(p.unrealizedGainLoss, c)),
              const Divider(height: 20),
              _row('Net profit', _signed(p.orgNetProfit, c), bold: true),
              if (p.profitAlreadyPaid != 0) _row('Already paid to earlier leavers', '- ${formatMoney(p.profitAlreadyPaid, c)}'),
              _row('Distributable profit', _signed(p.distributableProfit, c), bold: true),
              _row('All members\' deposits', formatMoney(p.stakeDeposits, c)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Profit is split by each member\'s share of total deposits. Members who left without settlement are not included.',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
        ),
        if (p.canSettle) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Payout'),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Final payout amount ($c)',
              prefixIcon: const Icon(Icons.payments_outlined),
              helperText: adjustment == 0
                  ? 'Matches the calculated amount'
                  : 'Adjustment: ${_signed(adjustment, c)} — a note is required',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
            items: _methods.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _trxController,
            decoration: InputDecoration(
              labelText: _method == 'cash' ? 'Transaction / receipt ID (optional)' : 'Transaction ID',
              prefixIcon: const Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded), alignLabelWithHint: true),
            onChanged: (_) => setState(() {}),
          ),
          if (amount > p.availableCash) ...[
            const SizedBox(height: 12),
            AppCard(
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The payout is more than the cash on record (${formatMoney(p.availableCash, c)}). '
                      'Make sure the organization actually has the funds before paying.',
                      style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.handshake_outlined),
            label: Text(_submitting ? 'Settling…' : 'Settle & Pay ${formatMoney(amount, c)}'),
          ),
          const SizedBox(height: 8),
          const Text(
            'The member will be marked as left, the payout is recorded as an outflow, and they are notified.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
          ),
        ],
      ],
    );
  }

  String _signed(double v, String c) => v < 0 ? '- ${formatMoney(-v, c)}' : '+ ${formatMoney(v, c)}';

  Widget _row(String label, String value, {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: bold ? AppTheme.textDark : AppTheme.textMuted, fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: valueColor ?? AppTheme.textDark)),
        ],
      ),
    );
  }
}
