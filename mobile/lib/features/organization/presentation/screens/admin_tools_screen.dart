import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/data/repositories/dashboard_repository.dart';
import '../../../notifications/data/models/notification_model.dart';
import '../../../notifications/data/repositories/notification_repository.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/organization_model.dart';
import '../../data/repositories/org_repository.dart';

class AdminToolsScreen extends StatefulWidget {
  final String orgSlug;

  const AdminToolsScreen({super.key, required this.orgSlug});

  @override
  State<AdminToolsScreen> createState() => _AdminToolsScreenState();
}

class _AdminToolsScreenState extends State<AdminToolsScreen> {
  bool _loading = true;
  String? _error;
  bool _allowList = true;
  bool _allowFinancial = true;
  bool _allowCollection = true;
  double _basePrice = 1000;
  String _frequency = 'monthly';
  int _dueDay = 10;
  List<OrganizationInvitationModel> _invitations = [];
  List<OrgMemberModel> _members = [];
  List<DownPaymentSchemeModel> _schemes = [];
  List<ScheduledNotificationModel> _scheduled = [];

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
      final dashboardRepo = context.read<DashboardRepository>();
      final orgRepo = context.read<OrgRepository>();
      final notifRepo = context.read<NotificationRepository>();
      final dashboard = await dashboardRepo.getMemberDashboard(widget.orgSlug);
      final invitations = await orgRepo.listInvitations(widget.orgSlug);
      final members = await orgRepo.listMembers(widget.orgSlug);
      final schemes = await orgRepo.listDownPaymentSchemes(widget.orgSlug);
      final scheduled = await notifRepo.listScheduled(widget.orgSlug);
      if (!mounted) return;
      setState(() {
        _allowList = dashboard.allowPeerListVisibility;
        _allowFinancial = dashboard.allowPeerFinancialVisibility;
        _allowCollection = dashboard.allowMemberCollectionVisibility;
        _basePrice = dashboard.basePricePerShare;
        _frequency = dashboard.contributionFrequency;
        _dueDay = dashboard.dueDayOfPeriod;
        _invitations = invitations;
        _members = members;
        _schemes = schemes;
        _scheduled = scheduled;
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

  Future<void> _savePrivacy({bool? list, bool? financial, bool? collection}) async {
    final newList = list ?? _allowList;
    final newFinancial = financial ?? _allowFinancial;
    final newCollection = collection ?? _allowCollection;
    setState(() {
      _allowList = newList;
      _allowFinancial = newFinancial;
      _allowCollection = newCollection;
    });
    try {
      await context.read<OrgRepository>().updatePrivacy(
        slug: widget.orgSlug,
        allowList: newList,
        allowFinancial: newFinancial,
        allowCollection: newCollection,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Privacy settings saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
      _load();
    }
  }

  Future<void> _configureShares() async {
    final price = TextEditingController(text: _basePrice.toStringAsFixed(0));
    final dueDay = TextEditingController(text: _dueDay.toString());
    String frequency = _frequency;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Share Configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Set the value of one share and how often contributions are due.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Base price per share',
                    prefixText: '৳ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Contribution frequency',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) => setSheetState(() => frequency = value ?? 'monthly'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: dueDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Due day of period',
                    helperText: 'Enter a day between 1 and 31',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save Configuration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      await context.read<OrgRepository>().configureShares(
        slug: widget.orgSlug,
        basePricePerShare: double.tryParse(price.text) ?? _basePrice,
        frequency: frequency,
        dueDayOfPeriod: int.tryParse(dueDay.text) ?? _dueDay,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share configuration updated.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _addScheme() async {
    final title = TextEditingController();
    final amount = TextEditingController();
    final startDate = TextEditingController(text: DateTime.now().toIso8601String().split('T').first);
    String type = 'mandatory';
    String frequency = 'one_time';
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                const Text('Down Payment Scheme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Create a separate recurring deposit with its own payment tracking.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g. Annual Development Fund',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '৳ ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Scheme type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'mandatory', child: Text('Mandatory')),
                    DropdownMenuItem(value: 'optional', child: Text('Optional')),
                  ],
                  onChanged: (value) => setSheetState(() => type = value ?? 'mandatory'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'one_time', child: Text('One time')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                  ],
                  onChanged: (value) => setSheetState(() => frequency = value ?? 'one_time'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: startDate,
                  decoration: const InputDecoration(
                    labelText: 'Start date',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create Scheme'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      await context.read<OrgRepository>().createDownPaymentScheme(
        slug: widget.orgSlug,
        title: title.text.trim(),
        amount: double.tryParse(amount.text) ?? 0,
        schemeType: type,
        frequency: frequency,
        startDate: startDate.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Down payment scheme created.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _broadcast() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final selected = <String>{};
    var sendToAll = true;
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                const Text('Broadcast Notification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Send an announcement to everyone or choose specific members.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: body,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sendToAll,
                  activeThumbColor: AppTheme.darkGreen,
                  title: const Text('Send to all members', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Turn off to select individual members', style: TextStyle(fontSize: 11)),
                  onChanged: (value) => setSheetState(() => sendToAll = value),
                ),
                if (!sendToAll)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      shrinkWrap: true,
                      children: _members.map((member) => CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(member.userId),
                        activeColor: AppTheme.darkGreen,
                        title: Text(member.fullName, style: const TextStyle(fontSize: 12.5)),
                        subtitle: Text(member.email, style: const TextStyle(fontSize: 10.5)),
                        onChanged: (value) => setSheetState(() {
                          if (value == true) {
                            selected.add(member.userId);
                          } else {
                            selected.remove(member.userId);
                          }
                        }),
                      )).toList(),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (!sendToAll && selected.isEmpty) ? null : () => Navigator.pop(ctx, true),
                  child: const Text('Send Notification'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (send != true || !mounted) return;
    try {
      await context.read<OrgRepository>().broadcastNotification(
        slug: widget.orgSlug,
        title: title.text.trim(),
        body: body.text.trim(),
        targetUserIds: sendToAll ? null : selected.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(sendToAll ? 'Notification sent to all members.' : 'Notification sent to ${selected.length} members.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _schedule() async {
    final title = TextEditingController();
    final body = TextEditingController();
    DateTime scheduledAt = DateTime.now().add(const Duration(hours: 1));
    String repeat = 'once';
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
                const Text('Schedule Notification', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Choose when to send this message and whether it repeats.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: body,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: scheduledAt,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date == null) return;
                    if (!ctx.mounted) return;
                    final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(scheduledAt));
                    if (time == null) return;
                    setSheetState(() {
                      scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Send at',
                      prefixIcon: Icon(Icons.schedule_rounded),
                      suffixIcon: Icon(Icons.chevron_right_rounded),
                    ),
                    child: Text(formatDateTime(scheduledAt), style: const TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: repeat,
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                    prefixIcon: Icon(Icons.event_repeat_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'once', child: Text('Once')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) => setSheetState(() => repeat = value ?? 'once'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Schedule Notification'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    try {
      await context.read<NotificationRepository>().scheduleNotification(
        slug: widget.orgSlug,
        title: title.text.trim(),
        body: body.text.trim(),
        scheduledAt: scheduledAt,
        repeatRule: repeat,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification scheduled.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _deleteScheduled(ScheduledNotificationModel item) async {
    try {
      await context.read<NotificationRepository>().deleteScheduled(widget.orgSlug, item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule removed.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Tools')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load settings', message: _error!, actionLabel: 'Retry', onAction: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SectionHeader(title: 'Contribution Rules'),
                    AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune_rounded, color: AppTheme.primaryNavy),
                        title: Text(formatMoney(_basePrice)),
                        subtitle: Text('${humanize(_frequency)} • Due day $_dueDay'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _configureShares,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Privacy'),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _allowList,
                            onChanged: (value) => _savePrivacy(list: value),
                            activeThumbColor: AppTheme.darkGreen,
                            title: const Text('Peer list visibility', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Members can see who else belongs to the organization', style: TextStyle(fontSize: 11)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _allowFinancial,
                            onChanged: (value) => _savePrivacy(financial: value),
                            activeThumbColor: AppTheme.darkGreen,
                            title: const Text('Peer financial visibility', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Members can see each other\'s savings totals', style: TextStyle(fontSize: 11)),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _allowCollection,
                            onChanged: (value) => _savePrivacy(collection: value),
                            activeThumbColor: AppTheme.darkGreen,
                            title: const Text('Collection list visibility', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Members can see cycle-wise collection list and payment status', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Invitations',
                      actionLabel: 'Manage in Members',
                      onAction: () => Navigator.pop(context),
                    ),
                    if (_invitations.isEmpty)
                      const AppCard(child: Text('No invitations yet.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)))
                    else
                      ..._invitations.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListRow(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEEF2F7),
                            child: Icon(Icons.mail_outline_rounded, size: 18, color: AppTheme.primaryNavy),
                          ),
                          title: item.email ?? item.phone ?? 'Invitation',
                          subtitle: '${humanize(item.role)} • ${item.sharesCount} shares • ${formatDate(item.createdAt)}',
                          trailing: StatusPill.forStatus(item.status),
                        ),
                      )),
                    const SizedBox(height: 20),
                    SectionHeader(title: 'Down Payment Schemes', actionLabel: 'Add', onAction: _addScheme),
                    if (_schemes.isEmpty)
                      const AppCard(child: Text('No down payment schemes.', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)))
                    else
                      ..._schemes.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListRow(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF0F7F5),
                            child: Icon(Icons.account_balance_outlined, size: 18, color: AppTheme.darkGreen),
                          ),
                          title: item.title,
                          subtitle: '${formatMoney(item.amount)} • ${humanize(item.schemeType)} • ${humanize(item.frequency)}',
                          trailing: StatusPill(label: item.isActive ? 'Active' : 'Inactive',
                              color: item.isActive ? AppTheme.accentGreen : AppTheme.textMuted),
                        ),
                      )),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Communications'),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.campaign_outlined, color: AppTheme.primaryNavy),
                            title: const Text('Broadcast now', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Send an instant notification to all members', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _broadcast,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.schedule_send_outlined, color: AppTheme.primaryNavy),
                            title: const Text('Schedule notification', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Create recurring reminders and announcements', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: _schedule,
                          ),
                        ],
                      ),
                    ),
                    if (_scheduled.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._scheduled.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_rounded, color: AppTheme.warningOrange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    Text('${formatDateTime(item.scheduledAt)} • ${humanize(item.repeatRule)}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteScheduled(item),
                                icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.errorRed),
                              ),
                            ],
                          ),
                        ),
                      )),
                    ],
                    const SizedBox(height: 28),
                  ],
                ),
    );
  }
}
