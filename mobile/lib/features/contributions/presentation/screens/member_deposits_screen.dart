import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/contribution_model.dart';
import '../../data/models/member_deposit_report_model.dart';
import '../../data/repositories/contribution_repository.dart';
import 'deposits_tab.dart';

/// Admin screen: total deposits of every member, with drill-down to history.
class MemberDepositsScreen extends StatefulWidget {
  final String orgSlug;

  const MemberDepositsScreen({super.key, required this.orgSlug});

  static Future<void> open(BuildContext context, {required String orgSlug}) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberDepositsScreen(orgSlug: orgSlug)));
  }

  @override
  State<MemberDepositsScreen> createState() => _MemberDepositsScreenState();
}

class _MemberDepositsScreenState extends State<MemberDepositsScreen> {
  MemberDepositReportModel? _report;
  String? _error;
  bool _loading = true;
  String _query = '';
  String _sort = 'high';

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
      final report = await context.read<ContributionRepository>().getMemberDepositReport(widget.orgSlug);
      if (!mounted) return;
      setState(() {
        _report = report;
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

  List<MemberDepositTotalModel> get _visible {
    final q = _query.trim().toLowerCase();
    final list = (_report?.members ?? const <MemberDepositTotalModel>[])
        .where((m) => q.isEmpty || m.fullName.toLowerCase().contains(q) || m.email.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case 'low':
        list.sort((a, b) => a.totalDeposit.compareTo(b.totalDeposit));
      case 'name':
        list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      default:
        list.sort((a, b) => b.totalDeposit.compareTo(a.totalDeposit));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Member Deposits')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _report == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    }
    if (_error != null && _report == null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load totals', message: _error!, actionLabel: 'Retry', onAction: _load);
    }
    final r = _report!;
    final c = r.currency;
    final visible = _visible;

    return RefreshIndicator(
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
                const Text('Total deposits (approved)', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(formatMoney(r.totalDeposit, c), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  [
                    'Installments ${formatMoney(r.installmentTotal, c)}',
                    if (r.downPaymentTotal > 0) 'Down payments ${formatMoney(r.downPaymentTotal, c)}',
                    if (r.otherTotal > 0) 'Other ${formatMoney(r.otherTotal, c)}',
                  ].join(' • '),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textDark),
                ),
                if (r.pendingAmount > 0)
                  Text('${formatMoney(r.pendingAmount, c)} awaiting review',
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.warningOrange)),
                Text('${r.memberCount} members', style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search name or email',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                initialValue: _sort,
                icon: const Icon(Icons.sort_rounded, color: AppTheme.primaryNavy),
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'high', child: Text('Highest total first')),
                  PopupMenuItem(value: 'low', child: Text('Lowest total first')),
                  PopupMenuItem(value: 'name', child: Text('Name (A–Z)')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const AppCard(child: Text('No members match.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)))
          else
            ...visible.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemberTotalRow(
                    member: m,
                    currency: c,
                    onTap: () => _MemberDepositHistoryScreen.open(context, orgSlug: widget.orgSlug, member: m),
                  ),
                )),
        ],
      ),
    );
  }
}

class _MemberTotalRow extends StatelessWidget {
  final MemberDepositTotalModel member;
  final String currency;
  final VoidCallback onTap;

  const _MemberTotalRow({required this.member, required this.currency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final breakdown = <String>[
      if (member.installmentTotal > 0) 'Installments ${formatMoney(member.installmentTotal, currency)}',
      if (member.downPaymentTotal > 0) 'Down payments ${formatMoney(member.downPaymentTotal, currency)}',
      if (member.otherTotal > 0) 'Other ${formatMoney(member.otherTotal, currency)}',
    ];
    final activity = <String>[
      '${member.depositCount} deposit${member.depositCount == 1 ? '' : 's'}',
      if (member.firstCycle != null && member.lastCycle != null)
        member.firstCycle == member.lastCycle
            ? formatCycle(member.lastCycle!)
            : '${formatCycle(member.firstCycle!)} – ${formatCycle(member.lastCycle!)}',
      if (member.status != 'active') humanize(member.status),
    ];
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(member.email, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                if (breakdown.isNotEmpty) Text(breakdown.join(' • '), style: const TextStyle(fontSize: 12)),
                Text(activity.join(' • '), style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatMoney(member.totalDeposit, currency), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              if (member.pendingAmount > 0)
                Text('+${formatMoney(member.pendingAmount, currency)} pending',
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.warningOrange)),
            ],
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}

/// All deposits of one member (admin).
class _MemberDepositHistoryScreen extends StatefulWidget {
  final String orgSlug;
  final MemberDepositTotalModel member;

  const _MemberDepositHistoryScreen({required this.orgSlug, required this.member});

  static Future<void> open(BuildContext context, {required String orgSlug, required MemberDepositTotalModel member}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _MemberDepositHistoryScreen(orgSlug: orgSlug, member: member)),
    );
  }

  @override
  State<_MemberDepositHistoryScreen> createState() => _MemberDepositHistoryScreenState();
}

class _MemberDepositHistoryScreenState extends State<_MemberDepositHistoryScreen> {
  List<ContributionModel> _items = [];
  String? _error;
  bool _loading = true;

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
      final items = await context.read<ContributionRepository>().getAllContributions(widget.orgSlug, userId: widget.member.userId);
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
    final m = widget.member;
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: Text(m.displayName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load deposits', message: _error!, actionLabel: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryNavy,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: [
                      PageHeader(
                        title: formatMoney(m.totalDeposit),
                        subtitle: '${m.depositCount} approved deposits • ${m.sharesCount} share${m.sharesCount == 1 ? '' : 's'}',
                      ),
                      if (_items.isEmpty)
                        const AppCard(
                          child: Text('No deposits recorded for this member.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                        )
                      else
                        ..._items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DepositCard(item: item, showMember: false),
                            )),
                    ],
                  ),
                ),
    );
  }
}
