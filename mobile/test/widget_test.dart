import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:songothon_mobile/core/api/api_client.dart';
import 'package:songothon_mobile/core/storage/secure_storage_service.dart';
import 'package:songothon_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:songothon_mobile/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:songothon_mobile/features/contributions/data/models/contribution_model.dart';
import 'package:songothon_mobile/features/dashboard/data/models/admin_dashboard_model.dart';
import 'package:songothon_mobile/features/dashboard/data/models/member_dashboard_model.dart';
import 'package:songothon_mobile/screens/auth/login_screen.dart';

void main() {
  testWidgets('Renders Login Screen with branding and fields', (WidgetTester tester) async {
    final storage = SecureStorageService();
    final client = ApiClient(storageService: storage);
    final authRepo = AuthRepository(apiClient: client, storageService: storage);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepository: authRepo),
          child: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('SONGOTHON'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  test('ContributionModel JSON deserialization and calculation properties', () {
    final json = {
      'id': 'c1111111-1111-1111-1111-111111111111',
      'org_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'user_id': '22222222-2222-2222-2222-222222222222',
      'type': 'share_installment',
      'amount': 3000.0,
      'payment_method': 'bkash',
      'trx_id': 'BKASH99281X',
      'sender_account': '01711223344',
      'target_cycle': '2026-10',
      'status': 'APPROVED',
      'paid_at': '2026-10-25T10:00:00Z',
    };

    final model = ContributionModel.fromJson(json);

    expect(model.id, 'c1111111-1111-1111-1111-111111111111');
    expect(model.amount, 3000.0);
    expect(model.trxId, 'BKASH99281X');
    expect(model.isApproved, true);
    expect(model.isPending, false);
    expect(model.isRejected, false);
  });

  test('MemberDashboardModel parses privacy and directory accurately', () {
    final json = {
      'organization_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'organization_name': 'Ekota Shomiti',
      'organization_slug': 'ekota',
      'currency': 'BDT',
      'allow_peer_financial_visibility': true,
      'personal_savings': 6000.0,
      'assigned_shares': 3,
      'base_price_per_share': 1000.0,
      'periodic_fee': 3000.0,
      'current_cycle': '2026-10',
      'is_current_cycle_paid': true,
      'vault_balance': 9000.0,
      'invested_capital': 350000.0,
      'liquidity_reserve': 9000.0,
      'active_investments_count': 2,
      'members_directory': [
        {
          'user_id': '22222222-2222-2222-2222-222222222222',
          'full_name': 'Alice Rahman',
          'role': 'member',
          'joined_at': '2026-01-01T00:00:00Z',
          'shares_count': 3,
          'total_savings': 6000.0,
          'current_status': 'Paid',
        }
      ],
    };

    final model = MemberDashboardModel.fromJson(json);

    expect(model.organizationSlug, 'ekota');
    expect(model.personalSavings, 6000.0);
    expect(model.assignedShares, 3);
    expect(model.periodicFee, 3000.0);
    expect(model.isCurrentCyclePaid, true);
    expect(model.membersDirectory.length, 1);
    expect(model.membersDirectory.first.fullName, 'Alice Rahman');
    expect(model.membersDirectory.first.sharesCount, 3);
  });

  test('AdminDashboardModel tolerates empty nullable collections', () {
    final json = {
      'organization_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'organization_name': 'Ekota Shomiti',
      'organization_slug': 'ekota',
      'currency': 'BDT',
      'total_deposits': 11000.0,
      'total_vault_balance': 13000.0,
      'total_invested_capital': 350000.0,
      'available_liquidity': 0.0,
      'current_cycle': '2026-10',
      'cycle_collection_rate': 46.3,
      'pending_approvals_count': 0,
      'pending_join_requests_count': 0,
      'member_count': 5,
      'pending_deposits': null,
      'pending_join_requests': null,
      'collection_summary': [
        {
          'user_id': '22222222-2222-2222-2222-222222222222',
          'full_name': 'Alice Rahman',
          'shares_count': 3,
          'expected_amount': 3600.0,
          'paid_amount': 3000.0,
          'pending_amount': 0.0,
          'status': 'Paid',
        }
      ],
    };

    final model = AdminDashboardModel.fromJson(json);

    expect(model.organizationSlug, 'ekota');
    expect(model.pendingDeposits, isEmpty);
    expect(model.pendingJoinRequests, isEmpty);
    expect(model.collectionSummary.single.status, 'Paid');
    expect(model.memberCount, 5);
  });

  test('MemberDashboardModel handles hidden peer directory from API', () {
    final model = MemberDashboardModel.fromJson({
      'organization_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'organization_name': 'Ekota Shomiti',
      'organization_slug': 'ekota',
      'currency': 'BDT',
      'allow_peer_list_visibility': false,
      'allow_peer_financial_visibility': false,
      'current_user_role': 'member',
      'personal_savings': 2000.0,
      'assigned_shares': 2,
      'base_price_per_share': 1200.0,
      'periodic_fee': 2400.0,
      'current_cycle': '2026-10',
      'current_cycle_status': 'Unpaid',
      'is_current_cycle_paid': false,
      'members_directory': null,
      'down_payments': null,
    });

    expect(model.allowPeerListVisibility, false);
    expect(model.allowPeerFinancialVisibility, false);
    expect(model.membersDirectory, isEmpty);
    expect(model.downPayments, isEmpty);
    expect(model.currentCycleStatus, 'Unpaid');
  });
}
