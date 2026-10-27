import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../data/models/organization_model.dart';
import '../../data/repositories/org_repository.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';

class MembersTab extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;
  final VoidCallback onRefreshShell;

  const MembersTab({super.key, required this.orgSlug, required this.isAdmin, required this.onRefreshShell});

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  List<OrgMemberModel> _members = [];
  List<PendingJoinRequestModel> _requests = [];
  double _basePrice = 0;
  String _frequency = 'monthly';
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
      final repo = context.read<OrgRepository>();
      final dashboardRepo = context.read<DashboardRepository>();
      final members = await repo.listMembers(widget.orgSlug);
      List<PendingJoinRequestModel> requests = [];
      if (widget.isAdmin) {
        try {
          requests = await repo.listJoinRequests(widget.orgSlug);
        } catch (_) {}
      }
      double basePrice = 0;
      String frequency = 'monthly';
      try {
        final dashboard = await dashboardRepo.getMemberDashboard(widget.orgSlug);
        basePrice = dashboard.basePricePerShare;
        frequency = dashboard.contributionFrequency;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _members = members;
        _requests = requests;
        _basePrice = basePrice;
        _frequency = frequency;
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

  Future<void> _invite() async {
    final emailController = TextEditingController();
    final sharesController = TextEditingController(text: '1');
    String role = 'member';
    final period = _frequency == 'weekly' ? 'week' : _frequency == 'yearly' ? 'year' : 'month';
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Invite Member', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Add someone by email or phone. Existing accounts join instantly.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 18),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email or phone', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sharesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Number of shares',
                  prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
                  helperText: _basePrice > 0 ? 'Each share adds ${formatMoney(_basePrice)} to the $period deposit' : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'org_admin', child: Text('Organization Admin')),
                ],
                onChanged: (value) => setSheetState(() => role = value ?? 'member'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send Invitation'),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    try {
      await context.read<OrgRepository>().inviteMember(
        slug: widget.orgSlug,
        emailOrPhone: emailController.text.trim(),
        role: role,
        sharesCount: int.tryParse(sharesController.text.trim()) ?? 1,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _reviewRequest(PendingJoinRequestModel item, bool approve) async {
    try {
      final repo = context.read<OrgRepository>();
      if (approve) {
        await repo.approveJoinRequest(widget.orgSlug, item.userId);
      } else {
        await repo.rejectJoinRequest(widget.orgSlug, item.userId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Request approved.' : 'Request rejected.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _editMember(OrgMemberModel member) async {
    final sharesController = TextEditingController(text: (member.sharesCount ?? 1).toString());
    int shares = member.sharesCount ?? 1;
    String role = member.role;
    String status = member.status;
    final period = _frequency == 'weekly' ? 'week' : _frequency == 'yearly' ? 'year' : 'month';
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
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Assign Shares', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Set how many shares ${member.fullName} holds.', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.darkGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$shares ${shares == 1 ? 'share' : 'shares'} assigned',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                            const SizedBox(height: 2),
                            Text(
                              _basePrice > 0
                                  ? '${formatMoney(_basePrice)} per share • ${formatMoney(shares * _basePrice)} due per $period'
                                  : 'Assign shares to calculate the member\'s periodic deposit.',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: sharesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Number of shares',
                    prefixIcon: const Icon(Icons.pie_chart_outline_rounded),
                    helperText: _basePrice > 0 ? 'Each share costs ${formatMoney(_basePrice)} per $period' : null,
                  ),
                  onChanged: (value) => setSheetState(() => shares = int.tryParse(value) ?? 0),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'org_admin', child: Text('Organization Admin')),
                  ],
                  onChanged: (value) => setSheetState(() => role = value ?? 'member'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.verified_user_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'invited', child: Text('Invited')),
                  ],
                  onChanged: (value) => setSheetState(() => status = value ?? 'active'),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: shares < 1 ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Save Assignment'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _removeMember(member);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
                  icon: const Icon(Icons.person_remove_outlined, size: 18),
                  label: const Text('Remove from organization'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      await context.read<OrgRepository>().updateMember(
        slug: widget.orgSlug,
        userId: member.userId,
        role: role,
        sharesCount: shares,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$shares share${shares == 1 ? '' : 's'} assigned to ${member.fullName}.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _removeMember(OrgMemberModel member) async {
    final ok = await confirmAction(
      context,
      title: 'Remove member?',
      message: '${member.fullName} will lose access to this organization. This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<OrgRepository>().removeMember(widget.orgSlug, member.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed.')));
      _load();
      widget.onRefreshShell();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  String _memberSubtitle(OrgMemberModel member, String period) {
    final shares = member.sharesCount ?? 0;
    final due = _basePrice > 0
        ? 'Due ${formatMoney(shares * _basePrice)} / $period'
        : 'Share value not configured';
    return '${humanize(member.role)} • $shares shares\n$due • Joined ${formatDate(member.joinedAt)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy));
    if (_error != null) {
      return EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load members', message: _error!, actionLabel: 'Retry', onAction: _load);
    }
    final period = _frequency == 'weekly' ? 'week' : _frequency == 'yearly' ? 'year' : 'month';
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.primaryNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          PageHeader(
            title: 'Members',
            subtitle: '${_members.length} people in this organization',
            actions: [
              if (widget.isAdmin)
                IconButton(
                  onPressed: _invite,
                  tooltip: 'Invite member',
                  icon: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.primaryNavy),
                ),
            ],
          ),
          if (widget.isAdmin) ...[
            AppCard(
              color: AppTheme.accentGreen.withValues(alpha: 0.1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.darkGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _basePrice > 0
                          ? 'Tap a member to assign shares. Each share adds ${formatMoney(_basePrice)} to their $period deposit.'
                          : 'Tap a member to assign shares. Set the share price under Admin Tools → Contribution Rules first.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.darkGreen, height: 1.4, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (widget.isAdmin && _requests.isNotEmpty) ...[
            const SectionHeader(title: 'Join Requests'),
            ..._requests.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.warningOrange.withValues(alpha: 0.12),
                          child: const Icon(Icons.person_add_alt_rounded, color: AppTheme.warningOrange, size: 19),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text('${item.email} • ${item.sharesCount} shares', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        StatusPill.forStatus(item.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _reviewRequest(item, false),
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.borderLight)),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _reviewRequest(item, true),
                            style: FilledButton.styleFrom(backgroundColor: AppTheme.accentGreen, foregroundColor: AppTheme.primaryNavy),
                            child: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 8),
          ],
          const SectionHeader(title: 'Directory'),
          if (_members.isEmpty)
            const EmptyState(icon: Icons.groups_outlined, title: 'No members yet', message: 'Invite members to start building your community.')
          else
            ..._members.map((member) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListRow(
                  leading: CircleAvatar(
                    backgroundColor: member.role == 'org_admin'
                        ? AppTheme.primaryNavy.withValues(alpha: 0.1)
                        : AppTheme.accentGreen.withValues(alpha: 0.12),
                    child: Text(
                      member.fullName.isEmpty ? '?' : member.fullName[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: member.role == 'org_admin' ? AppTheme.primaryNavy : AppTheme.darkGreen,
                      ),
                    ),
                  ),
                  title: member.fullName,
                  subtitle: _memberSubtitle(member, period),
                  onTap: widget.isAdmin ? () => _editMember(member) : null,
                  trailing: widget.isAdmin
                      ? Tooltip(
                          message: 'Assign shares',
                          child: OutlinedButton.icon(
                            onPressed: () => _editMember(member),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.darkGreen,
                              backgroundColor: AppTheme.accentGreen.withValues(alpha: 0.12),
                              side: BorderSide(color: AppTheme.accentGreen.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              minimumSize: const Size(0, 34),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.pie_chart_outline_rounded, size: 15),
                            label: Text('${member.sharesCount ?? 0}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                          ),
                        )
                      : StatusPill.forStatus(member.status),
                ),
              );
            }),
        ],
      ),
    );
  }
}
