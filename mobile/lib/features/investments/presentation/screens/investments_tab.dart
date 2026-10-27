import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/investment_model.dart';
import '../../data/repositories/investment_repository.dart';

class InvestmentsTab extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;
  final VoidCallback onRefreshShell;

  const InvestmentsTab({super.key, required this.orgSlug, required this.isAdmin, required this.onRefreshShell});

  @override
  State<InvestmentsTab> createState() => _InvestmentsTabState();
}

class _InvestmentsTabState extends State<InvestmentsTab> {
  List<InvestmentModel> _items = [];
  PortfolioMetricsModel? _metrics;
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
      final repo = context.read<InvestmentRepository>();
      final items = await repo.listInvestments(widget.orgSlug);
      PortfolioMetricsModel? metrics;
      try {
        metrics = await repo.getPortfolioMetrics(widget.orgSlug);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _items = items;
        _metrics = metrics;
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

  Future<void> _showForm({InvestmentModel? existing}) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final category = TextEditingController(text: existing?.category ?? '');
    final capital = TextEditingController(text: existing?.investedCapital.toStringAsFixed(0) ?? '');
    final valuation = TextEditingController(text: existing?.currentValuation.toStringAsFixed(0) ?? '');
    final roi = TextEditingController(text: existing?.expectedRoi.toStringAsFixed(1) ?? '10');
    final tenure = TextEditingController(text: existing?.tenure ?? '12 months');
    final startDate = TextEditingController(
      text: existing?.investmentDate.toIso8601String().split('T').first ??
          DateTime.now().toIso8601String().split('T').first,
    );
    final maturityDate = TextEditingController(
      text: existing?.maturityDate?.toIso8601String().split('T').first ?? '',
    );
    final notes = TextEditingController(text: existing?.notes ?? '');
    String status = existing?.status ?? 'ACTIVE';
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(existing == null ? 'Record Investment' : 'Update Investment',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Dairy Farm Project')),
                const SizedBox(height: 12),
                TextField(controller: category, decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Agriculture')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: capital, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capital'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: valuation, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Valuation'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: roi, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Expected ROI %'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: tenure, decoration: const InputDecoration(labelText: 'Tenure'))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startDate,
                        enabled: existing == null,
                        decoration: const InputDecoration(labelText: 'Start date', hintText: 'YYYY-MM-DD'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: maturityDate,
                        decoration: const InputDecoration(labelText: 'End date', hintText: 'YYYY-MM-DD'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(value: 'MATURED', child: Text('Matured')),
                    DropdownMenuItem(value: 'LIQUIDATED', child: Text('Liquidated')),
                  ],
                  onChanged: (value) => setSheetState(() => status = value ?? 'ACTIVE'),
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
                const SizedBox(height: 18),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing == null ? 'Add Investment' : 'Save Changes')),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      final repo = context.read<InvestmentRepository>();
      if (existing == null) {
        await repo.createInvestment(
          slug: widget.orgSlug,
          title: title.text.trim(),
          category: category.text.trim(),
          investedCapital: double.tryParse(capital.text) ?? 0,
          expectedRoi: double.tryParse(roi.text) ?? 0,
          tenure: tenure.text.trim(),
          investmentDate: startDate.text.trim().isEmpty
              ? DateTime.now().toIso8601String().split('T').first
              : startDate.text.trim(),
          maturityDate: maturityDate.text.trim().isEmpty ? null : maturityDate.text.trim(),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        );
      } else {
        await repo.updateInvestment(
          slug: widget.orgSlug,
          id: existing.id,
          title: title.text.trim(),
          category: category.text.trim(),
          investedCapital: double.tryParse(capital.text) ?? existing.investedCapital,
          currentValuation: double.tryParse(valuation.text) ?? existing.currentValuation,
          expectedRoi: double.tryParse(roi.text) ?? existing.expectedRoi,
          tenure: tenure.text.trim(),
          status: status,
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          maturityDate: maturityDate.text.trim().isEmpty ? null : maturityDate.text.trim(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existing == null ? 'Investment added.' : 'Investment updated.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _delete(InvestmentModel item) async {
    final ok = await confirmAction(
      context,
      title: 'Delete investment?',
      message: '${item.title} will be permanently removed from the portfolio.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<InvestmentRepository>().deleteInvestment(widget.orgSlug, item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Investment deleted.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    if (_error != null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load investments', message: _error!, actionLabel: 'Retry', onAction: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          PageHeader(
            title: 'Investments',
            subtitle: '${_items.length} portfolio projects',
            actions: [
              if (widget.isAdmin)
                IconButton(
                  onPressed: () => _showForm(),
                  tooltip: 'Add investment',
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryNavy),
                ),
            ],
          ),
          if (_metrics != null) ...[
            AppCard(
              color: AppTheme.primaryNavy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Portfolio Value', style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(formatMoney(_metrics!.totalCurrentValuation), style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MetricPill(label: 'Invested', value: formatCompactMoney(_metrics!.totalInvestedCapital)),
                      const SizedBox(width: 8),
                      _MetricPill(label: 'Returns', value: formatCompactMoney(_metrics!.totalRealizedReturns)),
                      const SizedBox(width: 8),
                      _MetricPill(label: 'Active', value: '${_metrics!.activeInvestmentsCount}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          const SectionHeader(title: 'Portfolio'),
          if (_items.isEmpty)
            const EmptyState(icon: Icons.show_chart_rounded, title: 'No investments yet', message: 'Admins can record organization investments to grow the community vault.')
          else
            ..._items.map((item) {
              final gain = item.currentValuation - item.investedCapital;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: widget.isAdmin ? () => _showForm(existing: item) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: AppTheme.accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.trending_up_rounded, size: 18, color: AppTheme.darkGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                Text('${humanize(item.category)} • ${item.tenure}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                              ],
                            ),
                          ),
                          StatusPill.forStatus(item.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _MiniStat(label: 'Capital', value: formatCompactMoney(item.investedCapital)),
                          _MiniStat(label: 'Valuation', value: formatCompactMoney(item.currentValuation)),
                          _MiniStat(
                            label: 'Gain/Loss',
                            value: '${gain >= 0 ? '+' : ''}${formatCompactMoney(gain)}',
                            color: gain >= 0 ? AppTheme.accentGreen : AppTheme.errorRed,
                          ),
                          _MiniStat(label: 'ROI', value: '${item.expectedRoi.toStringAsFixed(1)}%'),
                        ],
                      ),
                      if (widget.isAdmin)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _delete(item),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorRed),
                            label: const Text('Delete', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.55))),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? AppTheme.textDark)),
        ],
      ),
    );
  }
}
