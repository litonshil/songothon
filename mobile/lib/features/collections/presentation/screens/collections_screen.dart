import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/data/models/collection_model.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';

class CollectionsScreen extends StatefulWidget {
  final String orgSlug;
  final String currency;

  const CollectionsScreen({
    super.key,
    required this.orgSlug,
    this.currency = 'BDT',
  });

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  List<CycleCollectionSummaryModel> _cycles = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_cycles.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final cycles = await context
          .read<DashboardRepository>()
          .getCollectionCycles(widget.orgSlug);
      if (!mounted) return;
      setState(() {
        _cycles = cycles;
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

  void _openCycle(CycleCollectionSummaryModel cycle) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CycleCollectionDetailScreen(
          orgSlug: widget.orgSlug,
          cycle: cycle.cycle,
          currency: widget.currency,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collection List')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryNavy),
            )
          : _error != null
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load collections',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            )
          : _cycles.isEmpty
          ? const EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No cycles yet',
              message: 'Collection cycles will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryNavy,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  for (final cycle in _cycles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CycleCard(
                        cycle: cycle,
                        currency: widget.currency,
                        onTap: () => _openCycle(cycle),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final CycleCollectionSummaryModel cycle;
  final String currency;
  final VoidCallback onTap;

  const _CycleCard({
    required this.cycle,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = cycle.expectedAmount <= 0
        ? 0.0
        : (cycle.collectedAmount / cycle.expectedAmount).clamp(0.0, 1.0);
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatCycle(cycle.cycle),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '${cycle.collectionRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: cycle.collectionRate >= 100
                      ? AppTheme.accentGreen
                      : AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation(
                ratio >= 1 ? AppTheme.accentGreen : AppTheme.warningOrange,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatMoney(cycle.collectedAmount, currency)} of ${formatMoney(cycle.expectedAmount, currency)} collected'
            '${cycle.pendingAmount > 0 ? ' • ${formatMoney(cycle.pendingAmount, currency)} pending' : ''}',
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class CycleCollectionDetailScreen extends StatefulWidget {
  final String orgSlug;
  final String cycle;
  final String currency;

  const CycleCollectionDetailScreen({
    super.key,
    required this.orgSlug,
    required this.cycle,
    this.currency = 'BDT',
  });

  @override
  State<CycleCollectionDetailScreen> createState() =>
      _CycleCollectionDetailScreenState();
}

class _CycleCollectionDetailScreenState
    extends State<CycleCollectionDetailScreen> {
  CycleCollectionDetailModel? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_detail == null) _loading = true;
      _error = null;
    });
    try {
      final detail = await context
          .read<DashboardRepository>()
          .getCollectionCycle(widget.orgSlug, widget.cycle);
      if (!mounted) return;
      setState(() {
        _detail = detail;
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
    final detail = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(formatCycle(widget.cycle))),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryNavy),
            )
          : _error != null
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this cycle',
              message: _error!,
              actionLabel: 'Retry',
              onAction: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppTheme.primaryNavy,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _MiniStat(
                              label: 'Collected',
                              value: formatMoney(
                                detail!.collectedAmount,
                                widget.currency,
                              ),
                            ),
                            _MiniStat(
                              label: 'Expected',
                              value: formatMoney(
                                detail.expectedAmount,
                                widget.currency,
                              ),
                            ),
                            _MiniStat(
                              label: 'Pending',
                              value: formatMoney(
                                detail.pendingAmount,
                                widget.currency,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${detail.collectionRate.toStringAsFixed(0)}% collected',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(title: 'Members'),
                  if (detail.members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No members to show.',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ...detail.members.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: ListRow(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryNavy.withValues(
                              alpha: 0.08,
                            ),
                            child: Text(
                              item.fullName.isEmpty
                                  ? '?'
                                  : item.fullName[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                          ),
                          title: item.isCurrentUser
                              ? '${item.fullName} (You)'
                              : item.fullName,
                          subtitle: item.hasFinancials
                              ? '${formatMoney(item.paidAmount ?? 0, widget.currency)} of ${formatMoney(item.expectedAmount ?? 0, widget.currency)}'
                                    '${(item.pendingAmount ?? 0) > 0 ? ' • ${formatMoney(item.pendingAmount!, widget.currency)} pending' : ''}'
                              : 'Payment details hidden',
                          trailing: item.status != null
                              ? StatusPill.forStatus(item.status!)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
