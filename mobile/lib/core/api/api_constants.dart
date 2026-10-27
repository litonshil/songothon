import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String? _customBaseUrl;
  static String activeSlug = 'ekota';

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
  static const String logout = '/auth/logout';
  static const String fcmToken = '/auth/fcm-token';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // User-level Organization Endpoints
  static const String organizations = '/organizations';
  static const String joinOrganization = '/organizations/join';

  // Multi-tenant Tenant Scoped Parameterized Builders
  static String memberDashboard(String slug) => '/organizations/$slug/dashboard/member';
  static String adminDashboard(String slug) => '/organizations/$slug/admin/dashboard';
  static String submitDepositForOrg(String slug) => '/organizations/$slug/contributions/submit';
  static String myHistoryForOrg(String slug) => '/organizations/$slug/contributions/my-history';
  static String adminPendingDepositsForOrg(String slug) => '/organizations/$slug/admin/contributions/pending';
  static String adminAllContributionsForOrg(String slug) => '/organizations/$slug/admin/contributions';
  static String adminApproveDepositForOrg(String slug, String id) => '/organizations/$slug/admin/contributions/$id/approve';
  static String adminRejectDepositForOrg(String slug, String id) => '/organizations/$slug/admin/contributions/$id/reject';
  static String investmentsForOrg(String slug) => '/organizations/$slug/investments';
  static String investmentDetail(String slug, String id) => '/organizations/$slug/investments/$id';
  static String portfolioMetrics(String slug) => '/organizations/$slug/investments/metrics';
  static String adminCreateInvestmentForOrg(String slug) => '/organizations/$slug/admin/investments';
  static String adminUpdateInvestmentForOrg(String slug, String id) => '/organizations/$slug/admin/investments/$id';
  static String expensesForOrg(String slug) => '/organizations/$slug/expenses';
  static String adminCreateExpenseForOrg(String slug) => '/organizations/$slug/admin/expenses';
  static String incomesForOrg(String slug) => '/organizations/$slug/incomes';
  static String adminCreateIncomeForOrg(String slug) => '/organizations/$slug/admin/incomes';
  static String membersForOrg(String slug) => '/organizations/$slug/members';
  static String adminInviteMember(String slug) => '/organizations/$slug/admin/members/invite';
  static String adminUpdateMember(String slug, String userId) => '/organizations/$slug/admin/members/$userId';
  static String adminRemoveMember(String slug, String userId) => '/organizations/$slug/admin/members/$userId';
  static String adminJoinRequests(String slug) => '/organizations/$slug/admin/join-requests';
  static String adminApproveJoinRequest(String slug, String userId) => '/organizations/$slug/admin/join-requests/$userId/approve';
  static String adminRejectJoinRequest(String slug, String userId) => '/organizations/$slug/admin/join-requests/$userId/reject';
  static String adminInvitations(String slug) => '/organizations/$slug/admin/invitations';
  static String adminUpdatePrivacy(String slug) => '/organizations/$slug/admin/privacy';
  static String adminShareConfig(String slug) => '/organizations/$slug/admin/share-config';
  static String downPayments(String slug) => '/organizations/$slug/down-payments';
  static String adminBroadcast(String slug) => '/organizations/$slug/admin/notifications/broadcast';
  static String adminScheduleNotification(String slug) => '/organizations/$slug/admin/notifications/schedule';
  static String adminScheduledNotifications(String slug) => '/organizations/$slug/admin/notifications/scheduled';
  static String adminDeleteScheduledNotification(String slug, String id) => '/organizations/$slug/admin/notifications/scheduled/$id';
  static const String notifications = '/notifications';
  static const String notificationsReadAll = '/notifications/read-all';
  static String markNotificationRead(String id) => '/notifications/$id/read';

  // Compatibility aliases returning String
  static String get investments => '/organizations/$activeSlug/investments';
  static String get adminCreateInvestment => '/organizations/$activeSlug/admin/investments';
  static String get submitDeposit => '/organizations/$activeSlug/contributions/submit';
  static String get myHistory => '/organizations/$activeSlug/contributions/my-history';
  static String get adminPendingDeposits => '/organizations/$activeSlug/admin/contributions/pending';
  static String get adminAllContributions => '/organizations/$activeSlug/admin/contributions';
  static String adminApproveDeposit(String id) => '/organizations/$activeSlug/admin/contributions/$id/approve';
  static String adminRejectDeposit(String id) => '/organizations/$activeSlug/admin/contributions/$id/reject';
  static String get members => '/organizations/$activeSlug/members';
  static String get overview => '/organizations/$activeSlug/dashboard/member';
  static String get myDues => '/organizations/$activeSlug/dashboard/member';
  static String get periods => '/organizations/$activeSlug/down-payments';
  static String get monthlyReport => '/organizations/$activeSlug/contributions/my-history';
  static String get allMonthlyReports => '/organizations/$activeSlug/admin/contributions';
  static String get adminMembers => '/organizations/$activeSlug/members';
  static String get adminRecordDeposit => '/organizations/$activeSlug/contributions/submit';
  static String get adminFinancialSummary => '/organizations/$activeSlug/admin/dashboard';
}
