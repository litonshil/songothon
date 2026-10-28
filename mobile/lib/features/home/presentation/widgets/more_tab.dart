import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../collections/presentation/screens/collections_screen.dart';
import '../../../dashboard/data/models/member_dashboard_model.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../income/presentation/screens/incomes_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../organization/presentation/screens/admin_tools_screen.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';

class MoreTab extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;
  final VoidCallback onSwitchOrg;
  final VoidCallback onRefreshShell;

  const MoreTab({
    super.key,
    required this.orgSlug,
    required this.isAdmin,
    required this.onSwitchOrg,
    required this.onRefreshShell,
  });

  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  MemberDashboardModel? _dashboard;
  String? _email;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dashboardRepo = context.read<DashboardRepository>();
    final storage = context.read<SecureStorageService>();
    try {
      final dashboard = await dashboardRepo.getMemberDashboard(widget.orgSlug);
      final email = await storage.getUserEmail();
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _email = email;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to access your organization.',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (!ok) return;
    if (!mounted) return;
    final authCubit = context.read<AuthCubit>();
    await authCubit.logout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    final dashboard = _dashboard;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        const PageHeader(title: 'More', subtitle: 'Profile, settings, and organization tools'),
        AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryNavy,
                child: Text(
                  (dashboard?.organizationName ?? 'S').characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dashboard?.organizationName ?? widget.orgSlug,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('@${widget.orgSlug} • ${dashboard?.currency ?? 'BDT'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    if ((dashboard?.organizationDescription ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(dashboard!.organizationDescription, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35)),
                    ],
                  ],
                ),
              ),
              StatusPill(label: widget.isAdmin ? 'Admin' : 'Member',
                  color: widget.isAdmin ? AppTheme.primaryBlue : AppTheme.accentGreen),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            children: [
              _InfoRow(icon: Icons.mail_outline_rounded, label: 'Signed in as', value: _email ?? '—'),
              const Divider(height: 20),
              _InfoRow(icon: Icons.groups_2_outlined, label: 'Members', value: '${dashboard?.memberCount ?? 0}'),
              const Divider(height: 20),
              _InfoRow(icon: Icons.pie_chart_outline_rounded, label: 'My shares', value: '${dashboard?.assignedShares ?? 0}'),
              const Divider(height: 20),
              _InfoRow(icon: Icons.savings_outlined, label: 'My savings',
                  value: formatMoney(dashboard?.personalSavings ?? 0, dashboard?.currency ?? 'BDT')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Organization'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Payment updates and announcements',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              const Divider(height: 1),
              if (widget.isAdmin || (dashboard?.allowMemberCollectionVisibility ?? false)) ...[
                _MenuTile(
                  icon: Icons.view_list_rounded,
                  title: 'Collection List',
                  subtitle: 'Cycle-wise payment status of members',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CollectionsScreen(
                      orgSlug: widget.orgSlug,
                      currency: dashboard?.currency ?? 'BDT',
                    ),
                  )),
                ),
                const Divider(height: 1),
              ],
              _MenuTile(
                icon: Icons.payments_outlined,
                title: 'Expenses',
                subtitle: widget.isAdmin ? 'Record and review organization spending' : 'Review organization spending',
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExpensesScreen(
                      orgSlug: widget.orgSlug,
                      isAdmin: widget.isAdmin,
                      currency: dashboard?.currency ?? 'BDT',
                    ),
                  ));
                  widget.onRefreshShell();
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.trending_up_rounded,
                title: 'Income',
                subtitle: widget.isAdmin ? 'Record and review organization income' : 'Review organization income',
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => IncomesScreen(
                      orgSlug: widget.orgSlug,
                      isAdmin: widget.isAdmin,
                      currency: dashboard?.currency ?? 'BDT',
                    ),
                  ));
                  widget.onRefreshShell();
                },
              ),
              const Divider(height: 1),
              _MenuTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Switch organization',
                subtitle: 'Open another community or join a new one',
                onTap: widget.onSwitchOrg,
              ),
              if (widget.isAdmin) ...[
                const Divider(height: 1),
                _MenuTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Admin tools',
                  subtitle: 'Shares, privacy, invitations, down payments',
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AdminToolsScreen(orgSlug: widget.orgSlug),
                    ));
                    widget.onRefreshShell();
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppCard(
          padding: EdgeInsets.zero,
          child: _MenuTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'End your session on this device',
            color: AppTheme.errorRed,
            onTap: _logout,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text('Songothon • Community savings made simple',
              style: TextStyle(fontSize: 10.5, color: AppTheme.textMuted.withValues(alpha: 0.8))),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textMuted))),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.primaryNavy, size: 21),
      title: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: color)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: color ?? AppTheme.textMuted),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
