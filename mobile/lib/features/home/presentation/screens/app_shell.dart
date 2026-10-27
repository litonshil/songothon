import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../contributions/presentation/screens/deposits_tab.dart';
import '../../../investments/presentation/screens/investments_tab.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../organization/presentation/screens/members_tab.dart';
import '../../../organization/presentation/screens/select_or_create_org_screen.dart';
import '../../../organization/data/repositories/org_repository.dart';
import '../widgets/dashboard_tab.dart';
import '../widgets/more_tab.dart';

class AppShell extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;

  const AppShell({super.key, required this.orgSlug, required this.isAdmin});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _refreshTick = 0;

  void _refreshShell() => setState(() => _refreshTick++);

  void _switchOrg() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SelectOrCreateOrgScreen(orgRepository: context.read<OrgRepository>())),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardTab(
        key: ValueKey('home-${widget.orgSlug}-$_refreshTick'),
        orgSlug: widget.orgSlug,
        onRefreshShell: _refreshShell,
      ),
      DepositsTab(
        key: ValueKey('deposits-${widget.orgSlug}'),
        orgSlug: widget.orgSlug,
        isAdmin: widget.isAdmin,
        onRefreshShell: _refreshShell,
      ),
      MembersTab(
        key: ValueKey('members-${widget.orgSlug}'),
        orgSlug: widget.orgSlug,
        isAdmin: widget.isAdmin,
        onRefreshShell: _refreshShell,
      ),
      InvestmentsTab(
        key: ValueKey('investments-${widget.orgSlug}'),
        orgSlug: widget.orgSlug,
        isAdmin: widget.isAdmin,
        onRefreshShell: _refreshShell,
      ),
      MoreTab(
        key: ValueKey('more-${widget.orgSlug}'),
        orgSlug: widget.orgSlug,
        isAdmin: widget.isAdmin,
        onSwitchOrg: _switchOrg,
        onRefreshShell: _refreshShell,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 17, color: AppTheme.accentGreen),
            ),
            const SizedBox(width: 10),
            const Text('Songothon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (_, _, _) => const NotificationsScreen(),
                transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
              ),
            ),
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        height: 66,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: AppTheme.primaryNavy.withValues(alpha: 0.08),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Deposits'),
          NavigationDestination(icon: Icon(Icons.groups_2_outlined), selectedIcon: Icon(Icons.groups_2_rounded), label: 'Members'),
          NavigationDestination(icon: Icon(Icons.show_chart_rounded), selectedIcon: Icon(Icons.insert_chart_rounded), label: 'Invest'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), selectedIcon: Icon(Icons.more_rounded), label: 'More'),
        ],
      ),
    );
  }
}
