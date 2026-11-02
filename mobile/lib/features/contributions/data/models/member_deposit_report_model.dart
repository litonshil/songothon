/// Admin report: total deposits of each member.
class MemberDepositTotalModel {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final int sharesCount;
  final double installmentTotal;
  final double downPaymentTotal;
  final double otherTotal;
  final double totalDeposit; // approved only
  final double pendingAmount;
  final int depositCount;
  final String? firstCycle;
  final String? lastCycle;
  final DateTime? lastPaidAt;

  const MemberDepositTotalModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.sharesCount,
    required this.installmentTotal,
    required this.downPaymentTotal,
    required this.otherTotal,
    required this.totalDeposit,
    required this.pendingAmount,
    required this.depositCount,
    this.firstCycle,
    this.lastCycle,
    this.lastPaidAt,
  });

  String get displayName => fullName.isNotEmpty ? fullName : email;

  factory MemberDepositTotalModel.fromJson(Map<String, dynamic> json) {
    double num0(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return MemberDepositTotalModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      status: json['status']?.toString() ?? 'active',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      installmentTotal: num0('installment_total'),
      downPaymentTotal: num0('down_payment_total'),
      otherTotal: num0('other_total'),
      totalDeposit: num0('total_deposit'),
      pendingAmount: num0('pending_amount'),
      depositCount: (json['deposit_count'] as num?)?.toInt() ?? 0,
      firstCycle: json['first_cycle']?.toString(),
      lastCycle: json['last_cycle']?.toString(),
      lastPaidAt: DateTime.tryParse(json['last_paid_at']?.toString() ?? ''),
    );
  }
}

class MemberDepositReportModel {
  final String currency;
  final int memberCount;
  final double totalDeposit;
  final double installmentTotal;
  final double downPaymentTotal;
  final double otherTotal;
  final double pendingAmount;
  final List<MemberDepositTotalModel> members;

  const MemberDepositReportModel({
    required this.currency,
    required this.memberCount,
    required this.totalDeposit,
    required this.installmentTotal,
    required this.downPaymentTotal,
    required this.otherTotal,
    required this.pendingAmount,
    required this.members,
  });

  factory MemberDepositReportModel.fromJson(Map<String, dynamic> json) {
    double num0(String k) => (json[k] as num?)?.toDouble() ?? 0;
    return MemberDepositReportModel(
      currency: json['currency']?.toString() ?? 'BDT',
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      totalDeposit: num0('total_deposit'),
      installmentTotal: num0('installment_total'),
      downPaymentTotal: num0('down_payment_total'),
      otherTotal: num0('other_total'),
      pendingAmount: num0('pending_amount'),
      members: (json['members'] as List? ?? [])
          .map((e) => MemberDepositTotalModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
