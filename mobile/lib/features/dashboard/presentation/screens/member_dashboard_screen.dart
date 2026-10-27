import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/dashboard_state.dart';
import '../../data/models/member_dashboard_model.dart';
import '../../../contributions/presentation/widgets/submit_payment_bottom_sheet.dart';
import '../../../contributions/presentation/screens/admin_verification_screen.dart';
import '../../../contributions/presentation/bloc/contribution_cubit.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../organization/data/repositories/org_repository.dart';
import '../../../investments/data/repositories/investment_repository.dart';

class MemberDashboardScreen extends StatefulWidget {
  final String orgSlug;

  const MemberDashboardScreen({super.key, required this.orgSlug});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    final storage = context.read<SecureStorageService>();
    final role = await storage.getUserRole();
    setState(() {
      _userRole = role;
    });
    _refresh();
  }

  void _refresh() {
    context.read<DashboardCubit>().fetchMemberDashboard(widget.orgSlug);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Songothon',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        actions: [
          if (_userRole == 'org_admin' || _userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
              tooltip: 'Admin Verification Queue',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => BlocProvider.value(
                      value: BlocProvider.of<ContributionCubit>(context),
                      child: AdminVerificationScreen(orgSlug: widget.orgSlug),
                    ),
                  ),
                ).then((_) => _refresh());
              },
            ),
          _buildProfileMenu(context),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state is DashboardError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red.shade800),
            );
          } else if (state is MemberDashboardLoaded) {
            if (state.dashboard.currentUserRole != _userRole) {
              setState(() {
                _userRole = state.dashboard.currentUserRole;
              });
              context.read<SecureStorageService>().saveUserRole(state.dashboard.currentUserRole);
            }
          }
        },
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MemberDashboardLoaded) {
            final data = state.dashboard;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Card
                    _buildOrgHeader(data),
                    const SizedBox(height: 16),

                    // Admin Pending Approvals Callout (If any)
                    if (data.isAdmin && data.pendingApprovalsCount > 0) ...[
                      _buildAdminPendingAlert(context, data),
                      const SizedBox(height: 16),
                    ],

                    // Admin Control & Configuration Suite (If admin)
                    if (data.isAdmin) ...[
                      _buildAdminControlCenter(context, data, currencyFormatter),
                      const SizedBox(height: 16),
                    ],

                    // Current Cycle Status Banner
                    _buildCycleStatusBanner(context, data, currencyFormatter),
                    const SizedBox(height: 16),

                    // Aggregate Metric Cards
                    _buildVaultMetrics(data, currencyFormatter),
                    const SizedBox(height: 16),

                    _buildPersonalMetrics(data, currencyFormatter),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildQuickActionButtons(context, data),
                    const SizedBox(height: 24),

                    // Member Directory Section (Responsive to allow_peer_financial_visibility)
                    _buildMembersDirectory(data, currencyFormatter),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Failed to load dashboard data.'),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Deposit'),
        onPressed: () {
          final state = context.read<DashboardCubit>().state;
          if (state is MemberDashboardLoaded) {
            SubmitPaymentBottomSheet.show(
              context,
              orgSlug: widget.orgSlug,
              currentCycle: state.dashboard.currentCycle,
              defaultAmount: state.dashboard.periodicFee,
              onSuccess: _refresh,
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    return FutureBuilder<List<String?>>(
      future: Future.wait([
        context.read<SecureStorageService>().getUserName(),
        context.read<SecureStorageService>().getUserEmail(),
      ]),
      builder: (context, snapshot) {
        final name = snapshot.data?[0] ?? 'User';
        final email = snapshot.data?[1] ?? '';
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (value) async {
            if (value == 'logout') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                context.read<AuthCubit>().logout();
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF0F766E),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withAlpha(50),
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrgHeader(MemberDashboardModel data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withAlpha(60),
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
              Expanded(
                child: Text(
                  data.organizationName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '@${data.organizationSlug}',
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (data.isAdmin) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade400,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, size: 12, color: Color(0xFF78350F)),
                          SizedBox(width: 3),
                          Text(
                            'ADMIN',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Currency: ${data.currency} • Cycle: ${data.currentCycle}',
            style: TextStyle(fontSize: 13, color: Colors.teal.shade100),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleStatusBanner(
    BuildContext context,
    MemberDashboardModel data,
    NumberFormat currencyFormatter,
  ) {
    final isPaid = data.isCurrentCyclePaid;

    if (isPaid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cycle ${data.currentCycle} Status: PAID',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                  ),
                  const Text(
                    'Your periodic share contribution is up to date.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFFD97706), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Due: ${currencyFormatter.format(data.periodicFee)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF92400E)),
                ),
                Text(
                  'Cycle: ${data.currentCycle} (${data.assignedShares} Share${data.assignedShares > 1 ? 's' : ''})',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              SubmitPaymentBottomSheet.show(
                context,
                orgSlug: widget.orgSlug,
                currentCycle: data.currentCycle,
                defaultAmount: data.periodicFee,
                onSuccess: _refresh,
              );
            },
            child: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultMetrics(MemberDashboardModel data, NumberFormat currencyFormatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'Organization Treasury & Vault',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Vault Balance', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(data.vaultBalance),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Available Liquidity', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(data.liquidityReserve),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invested Capital: ${currencyFormatter.format(data.investedCapital)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${data.activeInvestmentsCount} Active Project${data.activeInvestmentsCount == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalMetrics(MemberDashboardModel data, NumberFormat currencyFormatter) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text(
                'My Savings & Equity Portfolio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Cumulative Deposits', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormatter.format(data.personalSavings),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      '${data.assignedShares} Share${data.assignedShares > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F766E)),
                    ),
                    Text(
                      '${currencyFormatter.format(data.basePricePerShare)} / share',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context, MemberDashboardModel data) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.payment, size: 18),
            label: const Text('Submit Payment'),
            onPressed: () {
              SubmitPaymentBottomSheet.show(
                context,
                orgSlug: widget.orgSlug,
                currentCycle: data.currentCycle,
                defaultAmount: data.periodicFee,
                onSuccess: _refresh,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMembersDirectory(MemberDashboardModel data, NumberFormat currencyFormatter) {
    final allowVisibility = data.allowPeerFinancialVisibility;
    final members = data.membersDirectory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Members Directory (${members.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: allowVisibility ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: allowVisibility ? Colors.green.shade200 : Colors.amber.shade300),
              ),
              child: Text(
                allowVisibility ? 'Peer Visibility: ON' : 'Confidential: OFF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: allowVisibility ? Colors.green.shade800 : Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Privacy alert notice if visibility is disabled
        if (!allowVisibility)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 20, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Personal finances are strictly confidential in this organization as configured by administrators.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),

        // Members list
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final m = members[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF0F766E).withAlpha(30),
                    child: Text(
                      m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : 'M',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.fullName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (m.role == 'org_admin')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          'Joined: ${DateFormat("MMM yyyy").format(m.joinedAt)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),

                  // Financial metrics conditionally shown
                  if (allowVisibility) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (m.totalSavings != null)
                          Text(
                            currencyFormatter.format(m.totalSavings),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F766E)),
                          ),
                        Row(
                          children: [
                            if (m.sharesCount != null)
                              Text(
                                '${m.sharesCount} share${m.sharesCount! > 1 ? 's' : ''} • ',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            Text(
                              m.currentStatus ?? 'Unpaid',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: m.currentStatus == 'Paid' ? Colors.green.shade700 : Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // --- ADMIN CAPABILITIES & CONFIGURATION SUITE ---

  Widget _buildAdminPendingAlert(BuildContext context, MemberDashboardModel data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFB45309), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.pendingApprovalsCount} Deposit${data.pendingApprovalsCount > 1 ? 's' : ''} Awaiting Approval',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Members submitted deposit slips that need verification.',
                  style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => BlocProvider.value(
                    value: BlocProvider.of<ContributionCubit>(context),
                    child: AdminVerificationScreen(orgSlug: widget.orgSlug),
                  ),
                ),
              ).then((_) => _refresh());
            },
            child: const Text('Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminControlCenter(
    BuildContext context,
    MemberDashboardModel data,
    NumberFormat currencyFormatter,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F766E).withAlpha(40), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withAlpha(15),
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
              const Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0F766E), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Admin Control Suite',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Manager Tools',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.fact_check_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  title: 'Verification',
                  subtitle: '${data.pendingApprovalsCount} Pending',
                  badgeText: data.pendingApprovalsCount > 0 ? '${data.pendingApprovalsCount}' : null,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BlocProvider.value(
                          value: BlocProvider.of<ContributionCubit>(context),
                          child: AdminVerificationScreen(orgSlug: widget.orgSlug),
                        ),
                      ),
                    ).then((_) => _refresh());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFF0F766E),
                  iconBg: const Color(0xFFCCFBF1),
                  title: 'Share Config',
                  subtitle: '${currencyFormatter.format(data.basePricePerShare)} / share',
                  onTap: () => _showShareConfigDialog(context, data),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.visibility_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  iconBg: const Color(0xFFEEF2FF),
                  title: 'Privacy Policy',
                  subtitle: data.allowPeerFinancialVisibility ? 'Peer Visibility ON' : 'Confidential OFF',
                  onTap: () => _showPrivacyDialog(context, data),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.person_add_alt_1_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBg: const Color(0xFFD1FAE5),
                  title: 'Invite Member',
                  subtitle: 'Add to organisation',
                  onTap: () => _showInviteMemberDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFEDD5),
                  title: 'Broadcast',
                  subtitle: 'Push alert to members',
                  onTap: () => _showBroadcastDialog(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAdminActionTile(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF9333EA),
                  iconBg: const Color(0xFFF3E8FF),
                  title: 'Record Investment',
                  subtitle: '${data.activeInvestmentsCount} Active Project${data.activeInvestmentsCount == 1 ? '' : 's'}',
                  onTap: () => _showRecordInvestmentDialog(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showShareConfigDialog(BuildContext context, MemberDashboardModel data) {
    final priceController = TextEditingController(text: data.basePricePerShare.toStringAsFixed(0));
    final dueDayController = TextEditingController(text: '10');
    String frequency = 'monthly';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF0F766E)),
              SizedBox(width: 8),
              Text('Share & Dues Config', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure the periodic dues schedule and per-share price for all members of this organization.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Base Price Per Share (BDT)',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Contribution Frequency',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frequency = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dueDayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due Day of Period (1-31)',
                    hintText: 'e.g. 10',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final price = double.tryParse(priceController.text.trim());
                final dueDay = int.tryParse(dueDayController.text.trim());
                if (price == null || price <= 0 || dueDay == null || dueDay < 1 || dueDay > 31) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid numeric values.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await context.read<OrgRepository>().configureShares(
                        slug: widget.orgSlug,
                        basePricePerShare: price,
                        frequency: frequency,
                        dueDayOfPeriod: dueDay,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share and dues configuration updated successfully!'),
                        backgroundColor: Color(0xFF0F766E),
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
                    );
                  }
                }
              },
              child: const Text('Save Config'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context, MemberDashboardModel data) {
    bool allow = data.allowPeerFinancialVisibility;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.visibility_rounded, color: Color(0xFF4F46E5)),
              SizedBox(width: 8),
              Text('Privacy Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Control whether organization members can see fellow members\' savings and dues records.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Peer Financial Visibility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  allow
                      ? 'Members CAN see savings balances and payment statuses.'
                      : 'Members CANNOT see fellow members\' financial details.',
                  style: const TextStyle(fontSize: 12),
                ),
                value: allow,
                activeTrackColor: const Color(0xFF0F766E),
                onChanged: (val) => setDialogState(() => allow = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await context.read<OrgRepository>().updatePrivacy(
                        slug: widget.orgSlug,
                        allowList: allow,
                        allowFinancial: allow,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Privacy updated: Peer visibility is now ${allow ? "ENABLED" : "CONFIDENTIAL"}.'),
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
                    );
                  }
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteMemberDialog(BuildContext context) {
    final contactController = TextEditingController();
    final sharesController = TextEditingController(text: '1');
    String role = 'member';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Text('Invite / Add Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(
                    labelText: 'Member Email or Phone',
                    hintText: 'e.g. member@songothon.org',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Standard Member', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'org_admin', child: Text('Organization Administrator', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => role = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Assigned Shares Count',
                    hintText: 'e.g. 1',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final contact = contactController.text.trim();
                final shares = int.tryParse(sharesController.text.trim()) ?? 1;
                if (contact.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an email or phone number.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await context.read<OrgRepository>().inviteMember(
                        slug: widget.orgSlug,
                        emailOrPhone: contact,
                        role: role,
                        sharesCount: shares,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully added / invited $contact!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
                    );
                  }
                }
              },
              child: const Text('Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.campaign_rounded, color: Color(0xFFEA580C)),
            SizedBox(width: 8),
            Text('Broadcast Alert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send a real-time push notification announcement to all active members of this organization.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Announcement Title',
                hintText: 'e.g. Monthly Meeting Scheduled',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                hintText: 'Please review deposit schedule before Friday.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              if (title.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and body cannot be empty.')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              try {
                await context.read<OrgRepository>().broadcastNotification(
                      slug: widget.orgSlug,
                      title: title,
                      body: body,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Broadcast notification dispatched to all members!'),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
                  );
                }
              }
            },
            child: const Text('Broadcast Now'),
          ),
        ],
      ),
    );
  }

  void _showRecordInvestmentDialog(BuildContext context) {
    final titleController = TextEditingController();
    final capitalController = TextEditingController();
    final roiController = TextEditingController(text: '15.0');
    final tenureController = TextEditingController(text: '2 Years');
    final notesController = TextEditingController();
    String category = 'Real Estate / Land';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Color(0xFF9333EA)),
              SizedBox(width: 8),
              Text('Record Investment', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Investment Project Name',
                    hintText: 'e.g. Commercial Plot 42',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Asset Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Real Estate / Land', child: Text('Real Estate / Land', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Agro-Business', child: Text('Agro-Business', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Retail & Commerce', child: Text('Retail & Commerce', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Fixed Deposit / Sukuk', child: Text('Fixed Deposit / Sukuk', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Other', child: Text('Other', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capitalController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capital Invested (BDT)',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roiController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expected ROI (%)',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tenureController,
                  decoration: const InputDecoration(
                    labelText: 'Investment Tenure',
                    hintText: 'e.g. 2 Years',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes & Reference',
                    hintText: 'Deed number, broker, etc.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9333EA),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final capital = double.tryParse(capitalController.text.trim());
                final roi = double.tryParse(roiController.text.trim()) ?? 0.0;
                final tenure = tenureController.text.trim();
                if (title.isEmpty || capital == null || capital <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter project name and valid invested capital.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await context.read<InvestmentRepository>().createInvestment(
                        slug: widget.orgSlug,
                        title: title,
                        category: category,
                        investedCapital: capital,
                        expectedRoi: roi,
                        tenure: tenure.isEmpty ? '1 Year' : tenure,
                        investmentDate: DateTime.now().toIso8601String().split('T')[0],
                        notes: notesController.text.trim(),
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Recorded investment "$title" successfully!'),
                        backgroundColor: const Color(0xFF0F766E),
                      ),
                    );
                    _refresh();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade800),
                    );
                  }
                }
              },
              child: const Text('Save Investment'),
            ),
          ],
        ),
      ),
    );
  }
}
