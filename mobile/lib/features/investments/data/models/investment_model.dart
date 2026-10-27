import 'package:equatable/equatable.dart';

class InvestmentModel extends Equatable {
  final String id;
  final String orgId;
  final String title;
  final String category;
  final double investedCapital;
  final double currentValuation;
  final double expectedRoi;
  final double realizedReturns;
  final String tenure;
  final String? notes;
  final String status; // 'ACTIVE', 'MATURED', 'LIQUIDATED'
  final DateTime investmentDate;
  final DateTime? maturityDate;

  const InvestmentModel({
    required this.id,
    required this.orgId,
    required this.title,
    required this.category,
    required this.investedCapital,
    required this.currentValuation,
    required this.expectedRoi,
    required this.realizedReturns,
    required this.tenure,
    this.notes,
    required this.status,
    required this.investmentDate,
    this.maturityDate,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      investedCapital: (json['invested_capital'] as num?)?.toDouble() ?? 0.0,
      currentValuation: (json['current_valuation'] as num?)?.toDouble() ?? 0.0,
      expectedRoi: (json['expected_roi'] as num?)?.toDouble() ?? 0.0,
      realizedReturns: (json['realized_returns'] as num?)?.toDouble() ?? 0.0,
      tenure: json['tenure']?.toString() ?? '',
      notes: json['notes']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      investmentDate: DateTime.tryParse(json['investment_date']?.toString() ?? '') ?? DateTime.now(),
      maturityDate: json['maturity_date'] != null ? DateTime.tryParse(json['maturity_date'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'org_id': orgId,
        'title': title,
        'category': category,
        'invested_capital': investedCapital,
        'current_valuation': currentValuation,
        'expected_roi': expectedRoi,
        'realized_returns': realizedReturns,
        'tenure': tenure,
        'notes': notes,
        'status': status,
        'investment_date': investmentDate.toIso8601String(),
        'maturity_date': maturityDate?.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        orgId,
        title,
        category,
        investedCapital,
        currentValuation,
        expectedRoi,
        realizedReturns,
        tenure,
        notes,
        status,
        investmentDate,
        maturityDate,
      ];
}

class PortfolioMetricsModel extends Equatable {
  final double totalInvestedCapital;
  final double totalCurrentValuation;
  final double totalRealizedReturns;
  final int activeInvestmentsCount;
  final int maturedInvestmentsCount;
  final int liquidatedInvestmentsCount;
  final double unrealizedGainLoss;

  const PortfolioMetricsModel({
    required this.totalInvestedCapital,
    required this.totalCurrentValuation,
    required this.totalRealizedReturns,
    required this.activeInvestmentsCount,
    required this.maturedInvestmentsCount,
    required this.liquidatedInvestmentsCount,
    required this.unrealizedGainLoss,
  });

  factory PortfolioMetricsModel.fromJson(Map<String, dynamic> json) {
    return PortfolioMetricsModel(
      totalInvestedCapital: (json['total_invested_capital'] as num?)?.toDouble() ?? 0.0,
      totalCurrentValuation: (json['total_current_valuation'] as num?)?.toDouble() ?? 0.0,
      totalRealizedReturns: (json['total_realized_returns'] as num?)?.toDouble() ?? 0.0,
      activeInvestmentsCount: (json['active_investments_count'] as num?)?.toInt() ?? 0,
      maturedInvestmentsCount: (json['matured_investments_count'] as num?)?.toInt() ?? 0,
      liquidatedInvestmentsCount: (json['liquidated_investments_count'] as num?)?.toInt() ?? 0,
      unrealizedGainLoss: (json['unrealized_gain_loss'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [
        totalInvestedCapital,
        totalCurrentValuation,
        totalRealizedReturns,
        activeInvestmentsCount,
        maturedInvestmentsCount,
        liquidatedInvestmentsCount,
        unrealizedGainLoss,
      ];
}
