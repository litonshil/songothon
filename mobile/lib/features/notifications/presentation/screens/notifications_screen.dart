import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_items.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<NotificationRepository>().listNotifications();
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

  Future<void> _markAllRead() async {
    try {
      await context.read<NotificationRepository>().markAllAsRead();
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  Future<void> _open(NotificationModel item) async {
    if (!item.isRead) {
      try {
        await context.read<NotificationRepository>().markAsRead(item.id);
        _load();
      } catch (_) {}
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: Text(item.body, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    final value = type.toLowerCase();
    if (value.contains('deposit') || value.contains('payment')) return Icons.payments_outlined;
    if (value.contains('join') || value.contains('member')) return Icons.group_add_outlined;
    if (value.contains('invest')) return Icons.show_chart_rounded;
    if (value.contains('remind')) return Icons.alarm_rounded;
    return Icons.notifications_none_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((e) => !e.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load notifications', message: _error!, actionLabel: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryNavy,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(
                              height: 480,
                              child: EmptyState(
                                icon: Icons.notifications_off_outlined,
                                title: 'You are all caught up',
                                message: 'Payment updates, reminders, and organization announcements will appear here.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return AppCard(
                              onTap: () => _open(item),
                              color: item.isRead ? Colors.white : const Color(0xFFF4FAF8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: (item.isRead ? AppTheme.textMuted : AppTheme.darkGreen).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(_iconFor(item.type), size: 18,
                                        color: item.isRead ? AppTheme.textMuted : AppTheme.darkGreen),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(item.title, style: TextStyle(
                                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                                fontSize: 13.5,
                                              )),
                                            ),
                                            if (!item.isRead)
                                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(item.body, maxLines: 3, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4)),
                                        const SizedBox(height: 6),
                                        Text(relativeTime(item.createdAt), style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
