import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/contribution_model.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../widgets/submit_payment_bottom_sheet.dart';

class DepositsTab extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;
  final VoidCallback onRefreshShell;

  const DepositsTab({super.key, required this.orgSlug, required this.isAdmin, required this.onRefreshShell});

  @override
  State<DepositsTab> createState() => _DepositsTabState();
}

class _DepositsTabState extends State<DepositsTab> {
  List<ContributionModel> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = context.read<ContributionRepository>();
      final items = widget.isAdmin ? await repo.getAllContributions(widget.orgSlug) : await repo.getMyHistory(widget.orgSlug);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _openDeposit() async {
    String cycle = 'Current';
    double amount = 1000;
    try {
      final dashboard = await context.read<DashboardRepository>().getMemberDashboard(widget.orgSlug);
      cycle = dashboard.currentCycle;
      amount = dashboard.periodicFee;
    } catch (_) {}
    if (!mounted) return;
    await SubmitPaymentBottomSheet.show(
      context,
      orgSlug: widget.orgSlug,
      currentCycle: cycle,
      defaultAmount: amount,
      onSuccess: () {
        _load();
        widget.onRefreshShell();
      },
    );
  }

  Future<void> _approve(ContributionModel item) async {
    final ok = await confirmAction(context, title: 'Approve deposit?', message: 'Approve ${formatMoney(item.amount)} from ${item.memberName ?? 'member'}?', confirmLabel: 'Approve');
    if (!ok || !mounted) return;
    try {
      await context.read<ContributionRepository>().approveDeposit(slug: widget.orgSlug, id: item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit approved.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _reject(ContributionModel item) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject deposit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Transaction ID not found'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await context.read<ContributionRepository>().rejectDeposit(slug: widget.orgSlug, id: item.id, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit rejected.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  List<ContributionModel> get _filtered {
    if (_filter == 'pending') return _items.where((e) => e.isPending).toList();
    if (_filter == 'approved') return _items.where((e) => e.isApproved).toList();
    if (_filter == 'rejected') return _items.where((e) => e.isRejected).toList();
    return _items;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    if (_error != null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load deposits', message: _error!, actionLabel: 'Retry', onAction: _load);
    }
    final pendingCount = _items.where((e) => e.isPending).length;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          PageHeader(
            title: widget.isAdmin ? 'Deposits' : 'My Deposits',
            subtitle: widget.isAdmin
                ? '$pendingCount pending review • ${_items.length} total transactions'
                : '${_items.length} transactions recorded',
            actions: [
              IconButton(
                onPressed: _openDeposit,
                tooltip: 'Submit deposit',
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryNavy),
              ),
            ],
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'pending', label: Text('Pending')),
              ButtonSegment(value: 'approved', label: Text('Paid')),
              ButtonSegment(value: 'rejected', label: Text('Rejected')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) => setState(() => _filter = value.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 16),
          if (_filtered.isEmpty)
            const SizedBox(
              height: 300,
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No deposits here',
                message: 'Submitted contributions will appear in this list for tracking and verification.',
              ),
            )
          else
            ..._filtered.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DepositCard(
                item: item,
                showMember: widget.isAdmin,
                onApprove: widget.isAdmin && item.isPending ? () => _approve(item) : null,
                onReject: widget.isAdmin && item.isPending ? () => _reject(item) : null,
              ),
            )),
        ],
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final ContributionModel item;
  final bool showMember;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _DepositCard({required this.item, required this.showMember, this.onApprove, this.onReject});

  IconData get _methodIcon => switch (item.paymentMethod) {
        'bkash' || 'nagad' || 'rocket' => Icons.phone_android_rounded,
        'bank_transfer' => Icons.account_balance_rounded,
        _ => Icons.payments_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isApproved ? AppTheme.accentGreen : item.isRejected ? AppTheme.errorRed : AppTheme.warningOrange;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_methodIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatMoney(item.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      showMember ? (item.memberName ?? 'Member') : '${humanize(item.type)} • ${humanize(item.paymentMethod)}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill.forStatus(item.status),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Expanded(child: _MiniDetail(label: 'Cycle', value: item.targetCycle.isEmpty ? '—' : item.targetCycle)),
                Expanded(child: _MiniDetail(label: 'TrxID', value: item.trxId.isEmpty ? '—' : item.trxId)),
                Expanded(child: _MiniDetail(label: 'Date', value: formatDate(item.paidAt))),
              ],
            ),
          ),
          if (showMember && item.memberEmail != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(item.memberEmail!, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ),
          if (item.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Reason: ${item.rejectionReason}', style: const TextStyle(fontSize: 11.5, color: AppTheme.errorRed)),
            ),
          if (onApprove != null && onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.borderLight)),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: AppTheme.primaryNavy),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniDetail extends StatelessWidget {
  final String label;
  final String value;

  const _MiniDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
