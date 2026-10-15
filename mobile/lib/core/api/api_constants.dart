import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = url.trim().endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String get currentBaseUrl => _customBaseUrl ?? defaultBaseUrl;

  static String get defaultBaseUrl {
    if (kIsWeb) return 'http://localhost:8080/api/v1';
    if (Platform.isAndroid) {
      // 127.0.0.1 with 'adb reverse tcp:8080 tcp:8080' for USB device testing
      return 'http://127.0.0.1:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  static String get baseUrl => currentBaseUrl;

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';

  // Overview & Reports
  static const String overview = '/reports/overview';
  static const String adminFinancialSummary = '/admin/reports/financial-summary';

  // Member contributions
  static const String submitDeposit = '/contributions/submit';
  static const String periods = '/contributions/periods';
  static const String myHistory = '/contributions/my-history';
  static const String myDues = '/contributions/my-dues';
  static const String monthlyReport = '/contributions/monthly';
  static const String allMonthlyReports = '/contributions/monthly-all';

  // Admin operations
  static const String adminMembers = '/admin/members';
  static const String adminRecordDeposit = '/admin/contributions/deposit';
  static const String adminCreatePeriod = '/admin/contributions/periods';
  static const String adminAllContributions = '/admin/contributions';
  static const String adminPendingDeposits = '/admin/contributions/pending';

  static String adminApproveDeposit(String id) => '/admin/contributions/$id/approve';
  static String adminRejectDeposit(String id) => '/admin/contributions/$id/reject';

  // Investments
  static const String investments = '/investments';
  static const String adminCreateInvestment = '/admin/investments';
}
