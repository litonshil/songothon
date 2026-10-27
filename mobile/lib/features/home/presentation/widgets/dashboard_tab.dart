import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../contributions/presentation/widgets/submit_payment_bottom_sheet.dart';
import '../../../dashboard/data/models/admin_dashboard_model.dart';
import '../../../dashboard/data/models/member_dashboard_model.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';

class DashboardTab extends StatefulWidget {
  final String orgSlug;
  final VoidCallback onRefreshShell;

  const DashboardTab({
    super.key,
    required this.orgSlug,
    required this.onRefreshShell,
  });

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  MemberDashboardModel? _member;
  AdminDashboardModel? _admin;
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
      final repo = context.read<DashboardRepository>();
      final member = await repo.getMemberDashboard(widget.orgSlug);
      AdminDashboardModel? admin;
      if (member.isAdmin) {
        admin = await repo.getAdminDashboard(widget.orgSlug);
      }
      if (!mounted) return;
      setState(() {
        _member = member;
        _admin = admin;
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

  String get _currency => _member?.currency ?? 'BDT';

  void _openDeposit() {
    final member = _member;
    if (member == null) return;
    SubmitPaymentBottomSheet.show(
      context,
      orgSlug: widget.orgSlug,
      currentCycle: member.currentCycle,
      defaultAmount: member.periodicFee,
      onSuccess: () {
        _load();
        widget.onRefreshShell();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load dashboard',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    final member = _member!;
    final admin = _admin;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _HeroCard(member: member, admin: admin),
          const SizedBox(height: 18),
          if (admin != null) ...[
            SectionHeader(title: 'Admin Overview'),
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'Pending Approvals', value: '${admin.pendingApprovalsCount}',
                  icon: Icons.fact_check_outlined, accent: AppTheme.warningOrange,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'Join Requests', value: '${admin.pendingJoinRequestsCount}',
                  icon: Icons.person_add_alt_1_outlined, accent: AppTheme.primaryBlue,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'Active Members', value: '${admin.memberCount}',
                  icon: Icons.groups_2_outlined, accent: AppTheme.darkGreen,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'Collection Rate', value: '${admin.cycleCollectionRate.toStringAsFixed(0)}%',
                  icon: Icons.trending_up_rounded, accent: AppTheme.accentGreen,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'Total Deposits', value: formatCompactMoney(admin.totalDeposits, _currency),
                  icon: Icons.receipt_long_outlined, accent: AppTheme.primaryBlue,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'Total Investment', value: formatCompactMoney(admin.totalInvestedCapital, _currency),
                  icon: Icons.trending_up_rounded, accent: AppTheme.accentGreen,
                )),
              ],
            ),
            const SizedBox(height: 20),
          ] else ...[
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'My Total Savings', value: formatCompactMoney(member.personalSavings, _currency),
                  icon: Icons.savings_outlined, accent: AppTheme.darkGreen,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'My Shares', value: '${member.assignedShares}',
                  icon: Icons.pie_chart_outline_rounded, accent: AppTheme.primaryBlue,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'Available Funds', value: formatCompactMoney(member.vaultBalance, _currency),
                  icon: Icons.account_balance_outlined, accent: AppTheme.primaryNavy,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'Invested Capital', value: formatCompactMoney(member.investedCapital, _currency),
                  icon: Icons.show_chart_rounded, accent: AppTheme.accentGreen,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(
                  label: 'Total Org Deposits', value: formatCompactMoney(member.totalOrgDeposits, _currency),
                  icon: Icons.account_balance_outlined, accent: AppTheme.primaryBlue,
                )),
                const SizedBox(width: 10),
                Expanded(child: StatTile(
                  label: 'Active Investments', value: '${member.activeInvestmentsCount}',
                  icon: Icons.pie_chart_outline_rounded, accent: AppTheme.darkGreen,
                )),
              ],
            ),
            const SizedBox(height: 20),
          ],
          _CycleCard(member: member, onDeposit: _openDeposit),
          if (member.downPayments.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'Down Payments'),
            ...member.downPayments.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_outlined, size: 18, color: AppTheme.primaryNavy),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(
                            '${humanize(item.frequency)} • Due ${formatMoney(item.pendingAmount, _currency)}',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    StatusPill.forStatus(item.status),
                  ],
                ),
              ),
            )),
          ],
          if (admin != null && admin.collectionSummary.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader(title: 'Cycle Collection', actionLabel: admin.currentCycle),
            ...admin.collectionSummary.take(5).map((item) {
              final ratio = item.expectedAmount <= 0 ? 0.0 : (item.paidAmount / item.expectedAmount).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                          StatusPill.forStatus(item.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppTheme.borderLight,
                          valueColor: AlwaysStoppedAnimation(ratio >= 1 ? AppTheme.accentGreen : AppTheme.warningOrange),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatMoney(item.paidAmount, _currency)} of ${formatMoney(item.expectedAmount, _currency)}',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (member.isAdmin && member.allowPeerListVisibility && member.membersDirectory.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader(title: 'Community Members'),
            ...member.membersDirectory.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListRow(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  child: Text(
                    item.fullName.isEmpty ? '?' : item.fullName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryNavy),
                  ),
                ),
                title: item.fullName,
                subtitle: member.allowPeerFinancialVisibility && item.totalSavings != null
                    ? '${humanize(item.role)} • Saved ${formatMoney(item.totalSavings!, _currency)}'
                    : humanize(item.role),
                trailing: item.currentStatus != null ? StatusPill.forStatus(item.currentStatus!) : null,
              ),
            )),
          ],
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${member.organizationName} • @${member.organizationSlug}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final MemberDashboardModel member;
  final AdminDashboardModel? admin;

  const _HeroCard({required this.member, this.admin});

  @override
  Widget build(BuildContext context) {
    final isAdmin = admin != null;
    final title = isAdmin ? 'Vault Balance' : 'My Savings';
    final amount = isAdmin ? admin!.totalVaultBalance : member.personalSavings;
    final subtitle = isAdmin
        ? '${admin!.memberCount} members • ${formatMoney(admin!.availableLiquidity, member.currency)} liquid'
        : '${formatCycle(member.currentCycle)} • ${member.currentCycleStatus}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [AppTheme.primaryNavy, Color(0xFF1D3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryNavy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.organizationName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('@${member.organizationSlug}', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAdmin ? 'ADMIN' : 'MEMBER',
                  style: const TextStyle(color: AppTheme.accentGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(amount, member.currency),
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          if (member.organizationDescription.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              member.organizationDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final MemberDashboardModel member;
  final VoidCallback onDeposit;

  const _CycleCard({required this.member, required this.onDeposit});

  @override
  Widget build(BuildContext context) {
    final paid = member.isCurrentCyclePaid;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: (paid ? AppTheme.accentGreen : AppTheme.warningOrange).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  paid ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                  size: 19,
                  color: paid ? AppTheme.accentGreen : AppTheme.warningOrange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(formatCycle(member.currentCycle), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      paid ? 'Contribution complete for this cycle' : 'Due ${formatMoney(member.periodicFee, member.currency)} • Day ${member.dueDayOfPeriod}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill.forStatus(paid ? 'Paid' : 'Pending'),
            ],
          ),
          if (!paid) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDeposit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                child: const Text('Submit Contribution'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
