import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/contribution_model.dart';
import '../../models/user_model.dart';
import '../../state/auth/auth_cubit.dart';
import '../../state/dashboard/dashboard_cubit.dart';
import '../../state/dashboard/dashboard_state.dart';
import '../investment/investment_portfolio_screen.dart';
import '../member/monthly_deposits_screen.dart';
import 'record_deposit_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<DashboardCubit>().loadDashboard(isAdmin: true);
  }

  void _openRecordDepositModal(DashboardLoaded state) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<DashboardCubit>(),
        child: RecordDepositDialog(
          members: state.members,
          periods: state.periods,
        ),
      ),
    );
  }

  Future<void> _approveDeposit(String id) async {
    final success = await context.read<DashboardCubit>().approveDeposit(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Deposit approved and posted to ledger!' : 'Failed to approve deposit.'),
          backgroundColor: success ? AppTheme.darkGreen : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _rejectDeposit(String id) async {
    final success = await context.read<DashboardCubit>().rejectDeposit(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Deposit rejected.' : 'Failed to reject deposit.'),
          backgroundColor: success ? AppTheme.warningOrange : AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Financial Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign Out',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                    const SizedBox(height: 12),
                    Text(state.message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<DashboardCubit>().loadDashboard(isAdmin: true),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is DashboardLoaded) {
            final pool = state.poolMetrics;
            final pendingApprovals = state.pendingApprovals;

            return RefreshIndicator(
              onRefresh: () => context.read<DashboardCubit>().loadDashboard(isAdmin: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Admin Overview Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryNavy,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'TOTAL COMMUNITY CAPITAL',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${pool.activeMembersCount} Members',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          currency.format(pool.totalFundsCollected),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Investments', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(pool.totalInvested),
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Liquid Balance', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(pool.availableLiquidity),
                                  style: const TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _openRecordDepositModal(state),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: const Text('Record Deposit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: AppTheme.primaryNavy),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<DashboardCubit>(),
                                  child: const MonthlyDepositsScreen(isAdmin: true),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.calendar_month, size: 18, color: AppTheme.primaryNavy),
                          label: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(color: AppTheme.primaryNavy),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const InvestmentPortfolioScreen()),
                            );
                          },
                          icon: const Icon(Icons.business_center_outlined, size: 18, color: AppTheme.primaryNavy),
                          label: const Text('Investments', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pending Approvals Section (Shown prominently when members submitted deposits)
                  if (pendingApprovals.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.warningOrange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.pending_actions, color: AppTheme.warningOrange, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pending Approvals (${pendingApprovals.length})',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<DashboardCubit>(),
                                        child: const MonthlyDepositsScreen(isAdmin: true),
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('View All', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...pendingApprovals.map((c) => _buildPendingApprovalCard(c, currency, dateFormat)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Members Management List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enrolled Club Members',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        '${state.members.length} Total',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (state.members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(child: Text('No members found.')),
                    )
                  else
                    ...state.members.map((m) => _buildMemberTile(m)),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildPendingApprovalCard(ContributionModel c, NumberFormat currency, DateFormat dateFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.memberName ?? c.memberEmail ?? 'Member',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  currency.format(c.amount),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.darkGreen),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${c.paymentMethod.toUpperCase()} • TrxID: ${c.transactionId.isNotEmpty ? c.transactionId : 'N/A'}${c.periodTitle != null ? ' • ${c.periodTitle}' : ''}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            if (c.notes != null && c.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Note: ${c.notes}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _rejectDeposit(c.id),
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Reject', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _approveDeposit(c.id),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(UserModel member) {
    final isActive = member.status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryNavy.withValues(alpha: 0.1),
          child: Text(
            member.fullName.isNotEmpty ? member.fullName[0].toUpperCase() : 'M',
            style: const TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(member.fullName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(member.email, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.accentGreen.withValues(alpha: 0.12) : AppTheme.warningOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            member.status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive ? AppTheme.darkGreen : AppTheme.warningOrange,
            ),
          ),
        ),
      ),
    );
  }
}
