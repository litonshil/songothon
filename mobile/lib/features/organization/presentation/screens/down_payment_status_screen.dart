import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/organization_model.dart';
import '../../data/repositories/org_repository.dart';

/// Admin view of a down payment scheme: who has paid for a given period.
class DownPaymentStatusScreen extends StatefulWidget {
  final String orgSlug;
  final DownPaymentSchemeModel scheme;

  const DownPaymentStatusScreen({super.key, required this.orgSlug, required this.scheme});

  static Future<void> open(BuildContext context, {required String orgSlug, required DownPaymentSchemeModel scheme}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DownPaymentStatusScreen(orgSlug: orgSlug, scheme: scheme)),
    );
  }

  @override
  State<DownPaymentStatusScreen> createState() => _DownPaymentStatusScreenState();
}

class _DownPaymentStatusScreenState extends State<DownPaymentStatusScreen> {
  SchemePeriodReportModel? _report;
  String? _period;
  String? _error;
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _period = widget.scheme.currentPeriod?.key;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await context.read<OrgRepository>().getDownPaymentStatus(widget.orgSlug, widget.scheme.id, period: _period);
      if (!mounted) return;
      setState(() {
        _report = report;
        _period = report.period.key;
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

  List<SchemeMemberStatusModel> get _filtered {
    final members = _report?.members ?? const [];
    return switch (_filter) {
      'paid' => members.where((m) => m.status == 'Paid').toList(),
      'unpaid' => members.where((m) => m.status != 'Paid').toList(),
      _ => members,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: Text(widget.scheme.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _report == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    }
    if (_error != null && _report == null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load status', message: _error!, actionLabel: 'Retry', onAction: _load);
    }
    final r = _report!;
    final periods = r.scheme.periods.reversed.toList();
    final rate = r.expectedAmount > 0 ? (r.collectedAmount / r.expectedAmount).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text(
            '${formatMoney(r.scheme.amount)} per member • ${humanize(r.scheme.frequency)} • ${humanize(r.scheme.schemeType)}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          if (periods.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Period', prefixIcon: Icon(Icons.event_repeat_rounded)),
              items: periods.map((p) => DropdownMenuItem(value: p.key, child: Text(p.label))).toList(),
              onChanged: _loading
                  ? null
                  : (key) {
                      setState(() => _period = key);
                      _load();
                    },
            ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.period.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    StatusPill(
                      label: r.isOverdue ? 'Due date passed' : 'Due ${r.period.dueDate}',
                      color: r.isOverdue ? AppTheme.errorRed : AppTheme.primaryBlue,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: rate,
                    minHeight: 8,
                    color: AppTheme.accentGreen,
                    backgroundColor: AppTheme.borderLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatMoney(r.collectedAmount)} of ${formatMoney(r.expectedAmount)} collected'
                  '${r.pendingAmount > 0 ? ' • ${formatMoney(r.pendingAmount)} awaiting review' : ''}',
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Paid', value: '${r.paidCount}', icon: Icons.check_circle_outline_rounded)),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(label: 'Partial', value: '${r.partialCount}', icon: Icons.timelapse_rounded, accent: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(label: 'Not paid', value: '${r.unpaidCount}', icon: Icons.error_outline_rounded, accent: AppTheme.errorRed),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'all', label: Text('All')),
              ButtonSegment(value: 'unpaid', label: Text('Not fully paid')),
              ButtonSegment(value: 'paid', label: Text('Paid')),
            ],
            selected: {_filter},
            onSelectionChanged: (v) => setState(() => _filter = v.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            const AppCard(child: Text('No members in this view.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)))
          else
            ..._filtered.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemberRow(member: m, overdue: r.isOverdue),
                )),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final SchemeMemberStatusModel member;
  final bool overdue;

  const _MemberRow({required this.member, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (member.paidAmount > 0) 'Paid ${formatMoney(member.paidAmount)}',
      if (member.pendingAmount > 0) '${formatMoney(member.pendingAmount)} in review',
      if (member.amountDue > 0) 'Owes ${formatMoney(member.amountDue)}',
    ];
    final hasOtherDues = member.outstandingAmount > member.amountDue;
    final status = member.status != 'Paid' && overdue ? 'Overdue' : member.status;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.fullName.isEmpty ? member.email : member.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(member.email, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                if (details.isNotEmpty)
                  Text(details.join(' • '), style: const TextStyle(fontSize: 12, color: AppTheme.textDark)),
                if (hasOtherDues)
                  Text(
                    'Total outstanding, all periods: ${formatMoney(member.outstandingAmount)}',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.errorRed),
                  ),
              ],
            ),
          ),
          StatusPill.forStatus(status),
        ],
      ),
    );
  }
}
