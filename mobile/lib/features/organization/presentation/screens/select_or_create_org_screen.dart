import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../home/presentation/screens/app_shell.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/organization_model.dart';
import '../../data/repositories/org_repository.dart';

/// Slug rules: one word, 6-20 characters, letters/numbers with optional - or _.
final RegExp _orgSlugPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*[a-z0-9]$');

String? validateOrgSlug(String slug) {
  if (slug.isEmpty) return 'Organization slug is required';
  if (slug.length < 6 || slug.length > 20) {
    return 'Slug must be between 6 and 20 characters';
  }
  if (!_orgSlugPattern.hasMatch(slug)) {
    return 'Slug must be one word using only letters, numbers, - or _';
  }
  return null;
}

class SelectOrCreateOrgScreen extends StatefulWidget {
  final OrgRepository orgRepository;

  const SelectOrCreateOrgScreen({super.key, required this.orgRepository});

  @override
  State<SelectOrCreateOrgScreen> createState() => _SelectOrCreateOrgScreenState();
}

class _SelectOrCreateOrgScreenState extends State<SelectOrCreateOrgScreen> {
  bool _loading = true;
  List<UserOrgMembershipModel> _myOrgs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrgs();
  }

  Future<void> _loadOrgs({bool autoOpen = true}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.orgRepository.listMyOrganizations();
      if (!mounted) return;
      setState(() {
        _myOrgs = list;
        _loading = false;
      });
      final active = list.where((item) => item.status == 'active').toList();
      if (autoOpen && active.length == 1) {
        _selectOrg(active.first.organization.slug, active.first.role);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectOrg(String slug, [String role = 'member']) async {
    try {
      await widget.orgRepository.storageService.saveCurrentOrgSlug(slug);
      await widget.orgRepository.storageService.saveUserRole(role);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => AppShell(orgSlug: slug, isAdmin: role == 'org_admin'),
      ),
      (route) => false,
    );
  }

  void _showJoinDialog() {
    final slugController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Join an Organization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Ask your community admin for the organization slug. New requests require approval.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
            const SizedBox(height: 18),
            TextField(
              controller: slugController,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Organization slug',
                hintText: 'e.g. ekota',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                final slug = slugController.text.trim().toLowerCase();
                if (slug.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  final status = await widget.orgRepository.joinOrganization(slug);
                  if (!mounted) return;
                  if (status == 'active') {
                    _selectOrg(slug);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Join request submitted. An admin will review it shortly.')),
                    );
                    _loadOrgs(autoOpen: false);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
                  );
                }
              },
              child: const Text('Request to Join'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final slugController = TextEditingController();
    final descriptionController = TextEditingController();
    final priceController = TextEditingController(text: '1000');
    String frequency = 'monthly';
    String? slugError;
    showModalBottomSheet(
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
                const Text('Create an Organization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Set up your community savings pool. You will be the first admin.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 18),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Organization name', hintText: 'e.g. Ekota Shomiti', prefixIcon: Icon(Icons.groups_2_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: slugController,
                  autocorrect: false,
                  maxLength: 20,
                  onChanged: (_) {
                    if (slugError != null) setSheetState(() => slugError = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Unique slug',
                    hintText: 'e.g. ekota-dhaka',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    helperText: 'One word, 6-20 characters (letters, numbers, - or _)',
                    helperMaxLines: 2,
                    errorText: slugError,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Purpose and goals of your community'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Share price (BDT)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: frequency,
                        decoration: const InputDecoration(labelText: 'Frequency'),
                        items: const [
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                        ],
                        onChanged: (value) => setSheetState(() => frequency = value ?? 'monthly'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final slug = slugController.text.trim().toLowerCase();
                    final price = double.tryParse(priceController.text.trim()) ?? 1000;
                    if (name.isEmpty) return;
                    final validationError = validateOrgSlug(slug);
                    if (validationError != null) {
                      setSheetState(() => slugError = validationError);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      final org = await widget.orgRepository.createOrganization(
                        name: name,
                        slug: slug,
                        description: descriptionController.text.trim(),
                        basePricePerShare: price,
                        contributionFrequency: frequency,
                      );
                      await _selectOrg(org.slug, 'org_admin');
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed),
                      );
                    }
                  },
                  child: const Text('Create Organization'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to access your organizations.',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (ok && mounted) context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
            : RefreshIndicator(
                onRefresh: () => _loadOrgs(autoOpen: false),
                color: AppTheme.primaryNavy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: AppTheme.primaryNavy, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.accentGreen, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('SONGOTHON', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              Text('Community savings & investments', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _logout,
                          tooltip: 'Sign out',
                          icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text('Your Organizations', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    const Text('Open a community dashboard or join a new one.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                    const SizedBox(height: 18),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.errorRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                      ),
                    if (_myOrgs.isEmpty)
                      AppCard(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            const Icon(Icons.group_off_outlined, size: 44, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            const Text('No organizations yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('Join with a slug or create your own community.',
                                textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            const SizedBox(height: 12),
                          ],
                        ),
                      )
                    else
                      ..._myOrgs.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OrgCard(
                          membership: item,
                          onTap: item.status == 'active'
                              ? () => _selectOrg(item.organization.slug, item.role)
                              : null,
                        ),
                      )),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showJoinDialog,
                            icon: const Icon(Icons.login_rounded, size: 18),
                            label: const Text('Join via Slug'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryNavy,
                              side: const BorderSide(color: AppTheme.borderLight),
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _showCreateDialog,
                            icon: const Icon(Icons.add_business_rounded, size: 18),
                            label: const Text('Create Org'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryNavy,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  final UserOrgMembershipModel membership;
  final VoidCallback? onTap;

  const _OrgCard({required this.membership, this.onTap});

  @override
  Widget build(BuildContext context) {
    final org = membership.organization;
    final pending = membership.status != 'active';
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (pending ? AppTheme.warningOrange : AppTheme.primaryNavy).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              pending ? Icons.hourglass_top_rounded : Icons.groups_2_rounded,
              color: pending ? AppTheme.warningOrange : AppTheme.primaryNavy,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(org.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(
                  '@${org.slug} • ${membership.sharesCount} shares • ${humanize(membership.role)}',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                ),
                if (org.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(org.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ],
            ),
          ),
          if (pending)
            const StatusPill(label: 'Pending', color: AppTheme.warningOrange)
          else
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
