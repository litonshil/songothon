import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/contribution_model.dart';
import '../../state/dashboard/dashboard_cubit.dart';
import '../../state/dashboard/dashboard_state.dart';

class MonthlyDepositsScreen extends StatefulWidget {
  final bool isAdmin;

  const MonthlyDepositsScreen({super.key, required this.isAdmin});

  @override
  State<MonthlyDepositsScreen> createState() => _MonthlyDepositsScreenState();
}

class _MonthlyDepositsScreenState extends State<MonthlyDepositsScreen> {
  String? _selectedPeriodId;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Savings Register'),
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardLoaded) {
            final reports = state.monthlyReports;
            if (reports.isEmpty) {
              return const Center(
                child: Text('No monthly deposit reports available.'),
              );
            }

            // Default to first report if none selected
            final currentReport = _selectedPeriodId == null
                ? reports.first
                : reports.firstWhere(
                    (r) => r.periodId == _selectedPeriodId,
                    orElse: () => reports.first,
                  );

            return RefreshIndicator(
              onRefresh: () => context.read<DashboardCubit>().loadDashboard(isAdmin: widget.isAdmin),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Month Picker Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: currentReport.periodId,
                        isExpanded: true,
                        icon: const Icon(Icons.calendar_month, color: AppTheme.primaryNavy),
                        items: reports.map((r) {
                          return DropdownMenuItem<String>(
                            value: r.periodId,
                            child: Text(
                              r.periodTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          setState(() {
                            _selectedPeriodId = newId;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Month Summary Statistics Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryNavy, Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                currentReport.periodTitle.toUpperCase(),
                                style: const TextStyle(
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
                                'Due: ${currency.format(currentReport.amountDue)}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Paid Collected', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(currentReport.totalCollected),
                                  style: const TextStyle(
                                    color: AppTheme.accentGreen,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${currentReport.paidCount} Paid',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Pending Approval', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(
                                  currency.format(currentReport.totalPending),
                                  style: TextStyle(
                                    color: currentReport.totalPending > 0 ? AppTheme.warningOrange : Colors.white70,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${currentReport.pendingCount} Pending',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Deposit Entries for the selected month
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Who Paid This Month',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      Text(
                        '${currentReport.deposits.length} Entries',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (currentReport.deposits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text('No deposits recorded for this month yet.'),
                      ),
                    )
                  else
                    ...currentReport.deposits.map(
                      (d) => _buildDepositCard(context, d, currency, dateFormat),
                    ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDepositCard(
    BuildContext context,
    ContributionModel d,
    NumberFormat currency,
    DateFormat dateFormat,
  ) {
    final isPaid = d.isPaid;
    final isPending = d.isPending;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isPaid
                      ? AppTheme.accentGreen.withValues(alpha: 0.15)
                      : AppTheme.warningOrange.withValues(alpha: 0.15),
                  child: Icon(
                    isPaid ? Icons.check_circle_outline : Icons.hourglass_top,
                    color: isPaid ? AppTheme.darkGreen : AppTheme.warningOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.memberName ?? 'Member',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.paymentMethod.toUpperCase()} • TrxID: ${d.transactionId}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFormat.format(d.paidAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.format(d.amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isPaid ? AppTheme.darkGreen : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPaid
                            ? AppTheme.accentGreen.withValues(alpha: 0.12)
                            : isPending
                                ? AppTheme.warningOrange.withValues(alpha: 0.12)
                                : AppTheme.errorRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isPaid ? 'PAID' : (isPending ? 'PENDING' : 'REJECTED'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPaid
                              ? AppTheme.darkGreen
                              : (isPending ? AppTheme.warningOrange : AppTheme.errorRed),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // If Admin and deposit is pending approval: show 1-tap Approve & Reject buttons
            if (widget.isAdmin && isPending) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: const BorderSide(color: AppTheme.errorRed),
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      context.read<DashboardCubit>().rejectDeposit(d.id, reason: 'TrxID could not be verified');
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    ),
                    onPressed: () {
                      context.read<DashboardCubit>().approveDeposit(d.id);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
