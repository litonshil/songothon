double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

/// What a member would be paid if settled now (admin preview).
class SettlementPreviewModel {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String status;
  final int sharesCount;
  final String currency;
  final bool canSettle;
  final String? blockReason;
  final int pendingCount;

  final double totalDeposits;
  final double ownershipPercent;
  final double profitShare;
  final double calculatedAmount;

  final double totalIncome;
  final double totalExpense;
  final double realizedReturns;
  final double unrealizedGainLoss;
  final double orgNetProfit;
  final double profitAlreadyPaid;
  final double distributableProfit;
  final double stakeDeposits;
  final double availableCash;

  const SettlementPreviewModel({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.sharesCount,
    required this.currency,
    required this.canSettle,
    this.blockReason,
    required this.pendingCount,
    required this.totalDeposits,
    required this.ownershipPercent,
    required this.profitShare,
    required this.calculatedAmount,
    required this.totalIncome,
    required this.totalExpense,
    required this.realizedReturns,
    required this.unrealizedGainLoss,
    required this.orgNetProfit,
    required this.profitAlreadyPaid,
    required this.distributableProfit,
    required this.stakeDeposits,
    required this.availableCash,
  });

  factory SettlementPreviewModel.fromJson(Map<String, dynamic> json) {
    final reason = json['block_reason']?.toString();
    return SettlementPreviewModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'member',
      status: json['status']?.toString() ?? 'active',
      sharesCount: (json['shares_count'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'BDT',
      canSettle: json['can_settle'] == true,
      blockReason: (reason == null || reason.isEmpty) ? null : reason,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      totalDeposits: _d(json['total_deposits']),
      ownershipPercent: _d(json['ownership_percent']),
      profitShare: _d(json['profit_share']),
      calculatedAmount: _d(json['calculated_amount']),
      totalIncome: _d(json['total_income']),
      totalExpense: _d(json['total_expense']),
      realizedReturns: _d(json['realized_returns']),
      unrealizedGainLoss: _d(json['unrealized_gain_loss']),
      orgNetProfit: _d(json['org_net_profit']),
      profitAlreadyPaid: _d(json['profit_already_paid']),
      distributableProfit: _d(json['distributable_profit']),
      stakeDeposits: _d(json['stake_deposits']),
      availableCash: _d(json['available_cash']),
    );
  }
}

/// A completed settlement payout.
class MemberSettlementModel {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final double totalDeposits;
  final double profitShare;
  final double calculatedAmount;
  final double adjustment;
  final double finalAmount;
  final String paymentMethod;
  final String trxId;
  final String notes;
  final String settledByName;
  final DateTime settledAt;

  const MemberSettlementModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.totalDeposits,
    required this.profitShare,
    required this.calculatedAmount,
    required this.adjustment,
    required this.finalAmount,
    required this.paymentMethod,
    required this.trxId,
    required this.notes,
    required this.settledByName,
    required this.settledAt,
  });

  factory MemberSettlementModel.fromJson(Map<String, dynamic> json) {
    return MemberSettlementModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      totalDeposits: _d(json['total_deposits']),
      profitShare: _d(json['profit_share']),
      calculatedAmount: _d(json['calculated_amount']),
      adjustment: _d(json['adjustment']),
      finalAmount: _d(json['final_amount']),
      paymentMethod: json['payment_method']?.toString() ?? '',
      trxId: json['trx_id']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      settledByName: json['settled_by_name']?.toString() ?? '',
      settledAt: DateTime.tryParse(json['settled_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
