import 'package:equatable/equatable.dart';

class ContributionModel extends Equatable {
  final String id;
  final String userId;
  final String? memberName;
  final String? memberEmail;
  final String? periodId;
  final String? periodTitle;
  final double amount;
  final String paymentMethod;
  final String transactionId;
  final String status; // 'pending', 'paid', 'rejected'
  final DateTime paidAt;
  final String? notes;

  const ContributionModel({
    required this.id,
    required this.userId,
    this.memberName,
    this.memberEmail,
    this.periodId,
    this.periodTitle,
    required this.amount,
    required this.paymentMethod,
    required this.transactionId,
    required this.status,
    required this.paidAt,
    this.notes,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory ContributionModel.fromJson(Map<String, dynamic> json) {
    final ref = json['transaction_id']?.toString() ??
        json['reference_no']?.toString() ??
        '';

    return ContributionModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      memberName: json['member_name']?.toString(),
      memberEmail: json['member_email']?.toString(),
      periodId: json['period_id']?.toString(),
      periodTitle: json['period_title']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'bkash',
      transactionId: ref,
      status: json['status']?.toString() ?? 'pending',
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, userId, amount, status, paidAt, transactionId];
}

class ContributionPeriodModel extends Equatable {
  final String id;
  final String title;
  final String frequency;
  final double amountDue;
  final DateTime dueDate;
  final bool isActive;

  const ContributionPeriodModel({
    required this.id,
    required this.title,
    required this.frequency,
    required this.amountDue,
    required this.dueDate,
    required this.isActive,
  });

  factory ContributionPeriodModel.fromJson(Map<String, dynamic> json) {
    return ContributionPeriodModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? 'monthly',
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, title, frequency, amountDue, dueDate, isActive];
}

class MemberFinancialSummaryModel extends Equatable {
  final String userId;
  final String fullName;
  final String email;
  final double totalContributed;
  final double pendingDues;
  final int totalCycles;
  final int paidCycles;
  final int pendingCycles;
  final List<ContributionModel> recentContributions;

  const MemberFinancialSummaryModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.totalContributed,
    required this.pendingDues,
    required this.totalCycles,
    required this.paidCycles,
    this.pendingCycles = 0,
    required this.recentContributions,
  });

  factory MemberFinancialSummaryModel.fromJson(Map<String, dynamic> json) {
    final listRaw = json['recent_contributions'] as List<dynamic>? ?? [];
    return MemberFinancialSummaryModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      totalContributed: (json['total_contributed'] as num?)?.toDouble() ?? 0.0,
      pendingDues: (json['pending_dues'] as num?)?.toDouble() ?? 0.0,
      totalCycles: (json['total_cycles'] as num?)?.toInt() ?? 0,
      paidCycles: (json['paid_cycles'] as num?)?.toInt() ?? 0,
      pendingCycles: (json['pending_cycles'] as num?)?.toInt() ?? 0,
      recentContributions: listRaw.map((e) => ContributionModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  List<Object?> get props => [userId, totalContributed, pendingDues, totalCycles, paidCycles, pendingCycles];
}

class MonthlyDepositReportModel extends Equatable {
  final String periodId;
  final String periodTitle;
  final double amountDue;
  final DateTime dueDate;
  final double totalCollected;
  final double totalPending;
  final int paidCount;
  final int pendingCount;
  final List<ContributionModel> deposits;

  const MonthlyDepositReportModel({
    required this.periodId,
    required this.periodTitle,
    required this.amountDue,
    required this.dueDate,
    required this.totalCollected,
    required this.totalPending,
    required this.paidCount,
    required this.pendingCount,
    required this.deposits,
  });

  factory MonthlyDepositReportModel.fromJson(Map<String, dynamic> json) {
    final listRaw = json['deposits'] as List<dynamic>? ?? [];
    return MonthlyDepositReportModel(
      periodId: json['period_id']?.toString() ?? '',
      periodTitle: json['period_title']?.toString() ?? 'Monthly Cycle',
      amountDue: (json['amount_due'] as num?)?.toDouble() ?? 0.0,
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? '') ?? DateTime.now(),
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      totalPending: (json['total_pending'] as num?)?.toDouble() ?? 0.0,
      paidCount: (json['paid_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      deposits: listRaw.map((e) => ContributionModel.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  @override
  List<Object?> get props => [periodId, periodTitle, totalCollected, totalPending, paidCount, pendingCount, deposits];
}
