import 'package:intl/intl.dart';

final NumberFormat _currencyFormat = NumberFormat('#,##0', 'en');

String formatMoney(num amount, [String currency = 'BDT']) {
  return '$currency ${_currencyFormat.format(amount)}';
}

String formatCompactMoney(num amount, [String currency = 'BDT']) {
  if (amount >= 10000000) return '$currency ${(amount / 10000000).toStringAsFixed(2)} Cr';
  if (amount >= 100000) return '$currency ${(amount / 100000).toStringAsFixed(2)} L';
  if (amount >= 1000) return '$currency ${(amount / 1000).toStringAsFixed(1)}K';
  return formatMoney(amount, currency);
}

String formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date.toLocal());

String formatDateTime(DateTime date) => DateFormat('dd MMM yyyy, h:mm a').format(date.toLocal());

String relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(date);
}

String formatCycle(String cycle) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(cycle);
  if (match == null) return cycle;
  final year = int.tryParse(match.group(1)!) ?? 0;
  final month = int.tryParse(match.group(2)!) ?? 1;
  if (month < 1 || month > 12) return cycle;
  return '${DateFormat('MMMM').format(DateTime(year, month))} $year';
}

String humanize(String value) {
  if (value.isEmpty) return '';
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
      .join(' ');
}
