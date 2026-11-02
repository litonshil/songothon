import 'package:equatable/equatable.dart';

class OrganizationModel extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String currency;
  final bool allowPeerListVisibility;
  final bool allowPeerFinancialVisibility;

  const OrganizationModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description = '',
    required this.currency,
    this.allowPeerListVisibility = true,
    required this.allowPeerFinancialVisibility,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'BDT',
      allowPeerListVisibility: json['allow_peer_list_visibility'] as bool? ?? true,
      allowPeerFinancialVisibility: json['allow_peer_financial_visibility'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'currency': currency,
        'allow_peer_list_visibility': allowPeerListVisibility,
        'allow_peer_financial_visibility': allowPeerFinancialVisibility,
      };

  @override
  List<Object?> get props => [id, name, slug, description, currency, allowPeerListVisibility, allowPeerFinancialVisibility];
}

class UserOrgMembershipModel extends Equatable {
  final OrganizationModel organization;
  final String role; // 'org_admin' or 'member'
  final int sharesCount;
  final String status;

  const UserOrgMembershipModel({
    required this.organization,
    required this.role,
    required this.sharesCount,
    required this.status,
  });

  bool get isAdmin => role == 'org_admin';

  factory UserOrgMembershipModel.fromJson(Map<String, dynamic> json) {
    return UserOrgMembershipModel(
      organization: OrganizationModel.fromJson(json['organization'] as Map<String, dynamic>? ?? {}),
      role: json['role']?.toString() ?? 'member',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'active',
    );
  }

  @override
  List<Object?> get props => [organization, role, sharesCount, status];
}

class OrgMemberModel extends Equatable {
  final String id;
  final String orgId;
  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final int? sharesCount;
  final String status;
  final DateTime joinedAt;
  final double? totalSavings;
  final String? currentStatus;

  const OrgMemberModel({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    required this.role,
    this.sharesCount,
    required this.status,
    required this.joinedAt,
    this.totalSavings,
    this.currentStatus,
  });

  factory OrgMemberModel.fromJson(Map<String, dynamic> json) {
    return OrgMemberModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'member',
      sharesCount: (json['shares_count'] as num?)?.toInt(),
      status: json['status']?.toString() ?? 'active',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '') ?? DateTime.now(),
      totalSavings: (json['total_savings'] as num?)?.toDouble(),
      currentStatus: json['current_status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, orgId, userId, fullName, email, phone, role, sharesCount, status, joinedAt, totalSavings, currentStatus];
}


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

class OrganizationInvitationModel extends Equatable {
  final String id;
  final String orgId;
  final String? email;
  final String? phone;
  final String role;
  final int sharesCount;
  final String status;
  final DateTime createdAt;

  const OrganizationInvitationModel({
    required this.id,
    required this.orgId,
    this.email,
    this.phone,
    required this.role,
    required this.sharesCount,
    required this.status,
    required this.createdAt,
  });

  factory OrganizationInvitationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationInvitationModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      role: json['role']?.toString() ?? 'member',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 1,
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, orgId, email, phone, role, sharesCount, status, createdAt];
}

/// One billing period of a down payment scheme ("once", "2026-Q4", "2026").
class SchemePeriodModel extends Equatable {
  final String key;
  final String label;
  final String startDate;
  final String? endDate;
  final String dueDate;

  const SchemePeriodModel({
    required this.key,
    required this.label,
    required this.startDate,
    this.endDate,
    required this.dueDate,
  });

  factory SchemePeriodModel.fromJson(Map<String, dynamic> json) {
    return SchemePeriodModel(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString(),
      dueDate: json['due_date']?.toString() ?? '',
    );
  }

  static SchemePeriodModel? tryParse(dynamic json) =>
      json is Map ? SchemePeriodModel.fromJson(Map<String, dynamic>.from(json)) : null;

  @override
  List<Object?> get props => [key, label, startDate, endDate, dueDate];
}

class DownPaymentSchemeModel extends Equatable {
  final String id;
  final String orgId;
  final String title;
  final double amount;
  final String schemeType;
  final String frequency;
  final String? startDate;
  final String? dueDate;
  final bool isActive;
  final List<SchemePeriodModel> periods;
  final SchemePeriodModel? currentPeriod;

  const DownPaymentSchemeModel({
    required this.id,
    required this.orgId,
    required this.title,
    required this.amount,
    required this.schemeType,
    required this.frequency,
    this.startDate,
    this.dueDate,
    this.isActive = true,
    this.periods = const [],
    this.currentPeriod,
  });

  bool get isMandatory => schemeType == 'mandatory';

  factory DownPaymentSchemeModel.fromJson(Map<String, dynamic> json) {
    return DownPaymentSchemeModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      schemeType: json['scheme_type']?.toString() ?? 'mandatory',
      frequency: json['frequency']?.toString() ?? 'one_time',
      startDate: json['start_date']?.toString(),
      dueDate: json['due_date']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      periods: (json['periods'] as List? ?? [])
          .map((e) => SchemePeriodModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      currentPeriod: SchemePeriodModel.tryParse(json['current_period']),
    );
  }

  @override
  List<Object?> get props => [id, orgId, title, amount, schemeType, frequency, startDate, dueDate, isActive, periods, currentPeriod];
}

/// Admin view: every active member's standing on a scheme for one period.
class SchemeMemberStatusModel {
  final String userId;
  final String fullName;
  final String email;
  final double paidAmount;
  final double pendingAmount;
  final double amountDue;
  final String status;
  final double outstandingAmount;

  const SchemeMemberStatusModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.paidAmount,
    required this.pendingAmount,
    required this.amountDue,
    required this.status,
    required this.outstandingAmount,
  });

  factory SchemeMemberStatusModel.fromJson(Map<String, dynamic> json) {
    return SchemeMemberStatusModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0,
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? 'Unpaid',
      outstandingAmount: (json['outstanding_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SchemePeriodReportModel {
  final DownPaymentSchemeModel scheme;
  final SchemePeriodModel period;
  final bool isOverdue;
  final double expectedAmount;
  final double collectedAmount;
  final double pendingAmount;
  final int paidCount;
  final int partialCount;
  final int unpaidCount;
  final List<SchemeMemberStatusModel> members;

  const SchemePeriodReportModel({
    required this.scheme,
    required this.period,
    required this.isOverdue,
    required this.expectedAmount,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.paidCount,
    required this.partialCount,
    required this.unpaidCount,
    required this.members,
  });

  factory SchemePeriodReportModel.fromJson(Map<String, dynamic> json) {
    return SchemePeriodReportModel(
      scheme: DownPaymentSchemeModel.fromJson(Map<String, dynamic>.from(json['scheme'] as Map)),
      period: SchemePeriodModel.fromJson(Map<String, dynamic>.from(json['period'] as Map)),
      isOverdue: json['is_overdue'] == true,
      expectedAmount: (json['expected_amount'] as num?)?.toDouble() ?? 0,
      collectedAmount: (json['collected_amount'] as num?)?.toDouble() ?? 0,
      pendingAmount: (json['pending_amount'] as num?)?.toDouble() ?? 0,
      paidCount: (json['paid_count'] as num?)?.toInt() ?? 0,
      partialCount: (json['partial_count'] as num?)?.toInt() ?? 0,
      unpaidCount: (json['unpaid_count'] as num?)?.toInt() ?? 0,
      members: (json['members'] as List? ?? [])
          .map((e) => SchemeMemberStatusModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
