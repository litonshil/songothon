import 'package:equatable/equatable.dart';
import '../../../contributions/data/models/contribution_model.dart';

class PendingJoinRequestModel extends Equatable {
  final String memberId;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final int sharesCount;
  final String status;
  final DateTime requestedAt;

  const PendingJoinRequestModel({
    required this.memberId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.sharesCount,
    required this.status,
    required this.requestedAt,
  });

  factory PendingJoinRequestModel.fromJson(Map<String, dynamic> json) {
    return PendingJoinRequestModel(
      memberId: json['member_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'pending',
      requestedAt: DateTime.tryParse(json['requested_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [memberId, userId, fullName, email, phone, sharesCount, status, requestedAt];
}

class MemberCollectionStatusModel extends Equatable {
  final String userId;
  final String fullName;
  final int sharesCount;
  final double expectedAmount;
  final double paidAmount;
  final double pendingAmount;
  final String status;

  const MemberCollectionStatusModel({
    required this.userId,
    required this.fullName,
    required this.sharesCount,
    required this.expectedAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.status,
  });

  factory MemberCollectionStatusModel.fromJson(Map<String, dynamic> json) {
    return MemberCollectionStatusModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      expectedAmount: (json['expected_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'Unpaid',
    );
  }

  @override
  List<Object?> get props => [userId, fullName, sharesCount, expectedAmount, paidAmount, pendingAmount, status];
}

class AdminDashboardModel extends Equatable {
  final String organizationId;
  final String organizationName;
  final String organizationSlug;
  final String currency;
  final double totalDeposits;
  final double totalVaultBalance;
  final double totalInvestedCapital;
  final double availableLiquidity;
  final String currentCycle;
  final double cycleCollectionRate;
  final double totalExpectedForCycle;
  final double totalCollectedForCycle;
  final int pendingApprovalsCount;
  final int pendingJoinRequestsCount;
  final int memberCount;
  final List<ContributionModel> pendingDeposits;
  final List<PendingJoinRequestModel> pendingJoinRequests;
  final List<MemberCollectionStatusModel> collectionSummary;

  const AdminDashboardModel({
    required this.organizationId,
    required this.organizationName,
    required this.organizationSlug,
    required this.currency,
    required this.totalDeposits,
    required this.totalVaultBalance,
    required this.totalInvestedCapital,
    required this.availableLiquidity,
    required this.currentCycle,
    required this.cycleCollectionRate,
    required this.totalExpectedForCycle,
    required this.totalCollectedForCycle,
    required this.pendingApprovalsCount,
    required this.pendingJoinRequestsCount,
    required this.memberCount,
    required this.pendingDeposits,
    required this.pendingJoinRequests,
    required this.collectionSummary,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    final deposits = json['pending_deposits'] as List? ?? [];
    final joins = json['pending_join_requests'] as List? ?? [];
    final collection = json['collection_summary'] as List? ?? [];
    return AdminDashboardModel(
      organizationId: json['organization_id']?.toString() ?? '',
      organizationName: json['organization_name']?.toString() ?? '',
      organizationSlug: json['organization_slug']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'BDT',
      totalDeposits: (json['total_deposits'] as num?)?.toDouble() ?? 0.0,
      totalVaultBalance: (json['total_vault_balance'] as num?)?.toDouble() ?? 0.0,
      totalInvestedCapital: (json['total_invested_capital'] as num?)?.toDouble() ?? 0.0,
      availableLiquidity: (json['available_liquidity'] as num?)?.toDouble() ?? 0.0,
      currentCycle: json['current_cycle']?.toString() ?? '',
      cycleCollectionRate: (json['cycle_collection_rate'] as num?)?.toDouble() ?? 0.0,
      totalExpectedForCycle: (json['total_expected_for_cycle'] as num?)?.toDouble() ?? 0.0,
      totalCollectedForCycle: (json['total_collected_for_cycle'] as num?)?.toDouble() ?? 0.0,
      pendingApprovalsCount: (json['pending_approvals_count'] as num?)?.toInt() ?? 0,
      pendingJoinRequestsCount: (json['pending_join_requests_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      pendingDeposits: deposits
          .map((item) => ContributionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      pendingJoinRequests: joins
          .map((item) => PendingJoinRequestModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      collectionSummary: collection
          .map((item) => MemberCollectionStatusModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        organizationId,
        organizationName,
        organizationSlug,
        currency,
        totalDeposits,
        totalVaultBalance,
        totalInvestedCapital,
        availableLiquidity,
        currentCycle,
        cycleCollectionRate,
        totalExpectedForCycle,
        totalCollectedForCycle,
        pendingApprovalsCount,
        pendingJoinRequestsCount,
        memberCount,
        pendingDeposits,
        pendingJoinRequests,
        collectionSummary,
      ];
}
