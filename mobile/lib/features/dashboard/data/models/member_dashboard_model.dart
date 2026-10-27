import 'package:equatable/equatable.dart';

class PeerMemberOverviewModel extends Equatable {
  final String userId;
  final String fullName;
  final String role;
  final DateTime joinedAt;
  final int? sharesCount;
  final double? totalSavings;
  final String? currentStatus;

  const PeerMemberOverviewModel({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.joinedAt,
    this.sharesCount,
    this.totalSavings,
    this.currentStatus,
  });

  factory PeerMemberOverviewModel.fromJson(Map<String, dynamic> json) {
    return PeerMemberOverviewModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.now(),
      sharesCount: (json['shares_count'] as num?)?.toInt(),
      totalSavings: (json['total_savings'] as num?)?.toDouble(),
      currentStatus: json['current_status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [userId, fullName, role, joinedAt, sharesCount, totalSavings, currentStatus];
}

class DownPaymentStatusModel extends Equatable {
  final String schemeId;
  final String title;
  final double amount;
  final String frequency;
  final String? startDate;
  final String? dueDate;
  final String status;
  final double paidAmount;
  final double pendingAmount;

  const DownPaymentStatusModel({
    required this.schemeId,
    required this.title,
    required this.amount,
    required this.frequency,
    this.startDate,
    this.dueDate,
    required this.status,
    required this.paidAmount,
    required this.pendingAmount,
  });

  factory DownPaymentStatusModel.fromJson(Map<String, dynamic> json) {
    return DownPaymentStatusModel(
      schemeId: json['scheme_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      frequency: json['frequency']?.toString() ?? 'one_time',
      startDate: json['start_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      status: json['status']?.toString() ?? 'Unpaid',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [schemeId, title, amount, frequency, startDate, dueDate, status, paidAmount, pendingAmount];
}

class MemberDashboardModel extends Equatable {
  final String organizationId;
  final String organizationName;
  final String organizationSlug;
  final String organizationDescription;
  final String currency;
  final bool allowPeerListVisibility;
  final bool allowPeerFinancialVisibility;
  final double personalSavings;
  final int assignedShares;
  final double basePricePerShare;
  final double periodicFee;
  final String currentCycle;
  final String currentCycleStatus;
  final bool isCurrentCyclePaid;
  final double totalOrgDeposits;
  final double vaultBalance;
  final double investedCapital;
  final double liquidityReserve;
  final int activeInvestmentsCount;
  final int memberCount;
  final List<PeerMemberOverviewModel> membersDirectory;
  final List<DownPaymentStatusModel> downPayments;
  final String currentUserRole;
  final int pendingApprovalsCount;
  final String contributionFrequency;
  final int dueDayOfPeriod;

  bool get isAdmin => currentUserRole == 'org_admin' || currentUserRole == 'admin';
  bool get isCurrentCyclePending => currentCycleStatus == 'Pending';

  const MemberDashboardModel({
    required this.organizationId,
    required this.organizationName,
    required this.organizationSlug,
    this.organizationDescription = '',
    required this.currency,
    this.allowPeerListVisibility = true,
    required this.allowPeerFinancialVisibility,
    required this.personalSavings,
    required this.assignedShares,
    required this.basePricePerShare,
    required this.periodicFee,
    required this.currentCycle,
    required this.currentCycleStatus,
    required this.isCurrentCyclePaid,
    required this.totalOrgDeposits,
    required this.vaultBalance,
    required this.investedCapital,
    required this.liquidityReserve,
    required this.activeInvestmentsCount,
    required this.memberCount,
    required this.membersDirectory,
    this.downPayments = const [],
    this.currentUserRole = 'member',
    this.pendingApprovalsCount = 0,
    this.contributionFrequency = 'monthly',
    this.dueDayOfPeriod = 10,
  });

  factory MemberDashboardModel.fromJson(Map<String, dynamic> json) {
    final rawDirectory = json['members_directory'] as List? ?? [];
    final rawDownPayments = json['down_payments'] as List? ?? [];
    return MemberDashboardModel(
      organizationId: json['organization_id']?.toString() ?? '',
      organizationName: json['organization_name']?.toString() ?? '',
      organizationSlug: json['organization_slug']?.toString() ?? '',
      organizationDescription: json['organization_description']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'BDT',
      allowPeerListVisibility: json['allow_peer_list_visibility'] as bool? ?? true,
      allowPeerFinancialVisibility: json['allow_peer_financial_visibility'] as bool? ?? true,
      currentUserRole: json['current_user_role']?.toString() ?? 'member',
      pendingApprovalsCount: (json['pending_approvals_count'] as num?)?.toInt() ?? 0,
      personalSavings: (json['personal_savings'] as num?)?.toDouble() ?? 0.0,
      assignedShares: (json['assigned_shares'] as num?)?.toInt() ?? 1,
      basePricePerShare: (json['base_price_per_share'] as num?)?.toDouble() ?? 1000.0,
      periodicFee: (json['periodic_fee'] as num?)?.toDouble() ?? 1000.0,
      currentCycle: json['current_cycle']?.toString() ?? '',
      currentCycleStatus: json['current_cycle_status']?.toString() ??
          ((json['is_current_cycle_paid'] as bool? ?? false) ? 'Paid' : 'Unpaid'),
      isCurrentCyclePaid: json['is_current_cycle_paid'] as bool? ?? false,
      totalOrgDeposits: (json['total_org_deposits'] as num?)?.toDouble() ?? 0.0,
      vaultBalance: (json['vault_balance'] as num?)?.toDouble() ?? 0.0,
      investedCapital: (json['invested_capital'] as num?)?.toDouble() ?? 0.0,
      liquidityReserve: (json['liquidity_reserve'] as num?)?.toDouble() ?? 0.0,
      activeInvestmentsCount: (json['active_investments_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      contributionFrequency: json['contribution_frequency']?.toString() ?? 'monthly',
      dueDayOfPeriod: (json['due_day_of_period'] as num?)?.toInt() ?? 10,
      membersDirectory: rawDirectory
          .map((item) => PeerMemberOverviewModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      downPayments: rawDownPayments
          .map((item) => DownPaymentStatusModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        organizationId,
        organizationName,
        organizationSlug,
        organizationDescription,
        currency,
        allowPeerListVisibility,
        allowPeerFinancialVisibility,
        personalSavings,
        assignedShares,
        basePricePerShare,
        periodicFee,
        currentCycle,
        currentCycleStatus,
        isCurrentCyclePaid,
        totalOrgDeposits,
        vaultBalance,
        investedCapital,
        liquidityReserve,
        activeInvestmentsCount,
        memberCount,
        membersDirectory,
        downPayments,
        currentUserRole,
        pendingApprovalsCount,
        contributionFrequency,
        dueDayOfPeriod,
      ];
}
