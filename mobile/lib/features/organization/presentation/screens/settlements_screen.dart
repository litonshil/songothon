import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/settlement_model.dart';
import '../../data/repositories/org_repository.dart';

/// Admin history of every member settlement in the organization.
class SettlementsScreen extends StatefulWidget {
  final String orgSlug;

  const SettlementsScreen({super.key, required this.orgSlug});

  static Future<void> open(BuildContext context, {required String orgSlug}) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettlementsScreen(orgSlug: orgSlug)));
  }

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  List<MemberSettlementModel> _items = [];
  bool _loading = true;
  String? _error;

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
      final items = await context.read<OrgRepository>().listSettlements(widget.orgSlug);
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

  @override
  Widget build(BuildContext context) {
    final totalPaid = _items.fold<double>(0, (sum, s) => sum + s.finalAmount);
    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load settlements', message: _error!, actionLabel: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryNavy,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_items.isEmpty)
                        const EmptyState(
                          icon: Icons.handshake_outlined,
                          title: 'No settlements yet',
                          message: 'Settle a member from the Members tab when they leave with their deposit.',
                        )
                      else ...[
                        Text('${_items.length} settled • ${formatMoney(totalPaid)} paid out',
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ..._items.map(_tile),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _tile(MemberSettlementModel s) {
    final details = <String>[
      'Deposits ${formatMoney(s.totalDeposits)}',
      '${s.profitShare >= 0 ? 'Profit' : 'Loss'} ${formatMoney(s.profitShare.abs())}',
      if (s.adjustment != 0) 'Adjusted ${s.adjustment > 0 ? '+' : '-'}${formatMoney(s.adjustment.abs())}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.12),
                  child: const Icon(Icons.handshake_outlined, color: AppTheme.darkGreen, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(formatDate(s.settledAt), style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Text(formatMoney(s.finalAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Text(details.join(' • '), style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
            const SizedBox(height: 2),
            Text(
              '${humanize(s.paymentMethod)}${s.trxId.isNotEmpty ? ' • ${s.trxId}' : ''}'
              '${s.settledByName.isNotEmpty ? ' • by ${s.settledByName}' : ''}',
              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
            ),
            if (s.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(s.notes, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
