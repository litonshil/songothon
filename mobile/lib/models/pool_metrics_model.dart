import 'package:equatable/equatable.dart';

class PoolMetricsModel extends Equatable {
  final double totalFundsCollected;
  final double totalInvested;
  final double totalReturns;
  final double availableLiquidity;
  final double portfolioValuation;
  final int activeMembersCount;
  final int investmentsCount;

  const PoolMetricsModel({
    required this.totalFundsCollected,
    required this.totalInvested,
    required this.totalReturns,
    required this.availableLiquidity,
    required this.portfolioValuation,
    required this.activeMembersCount,
    required this.investmentsCount,
  });

  factory PoolMetricsModel.fromJson(Map<String, dynamic> json) {
    return PoolMetricsModel(
      totalFundsCollected: (json['total_funds_collected'] as num?)?.toDouble() ?? 0.0,
      totalInvested: (json['total_invested'] as num?)?.toDouble() ?? 0.0,
      totalReturns: (json['total_returns'] as num?)?.toDouble() ?? 0.0,
      availableLiquidity: (json['available_liquidity'] as num?)?.toDouble() ?? 0.0,
      portfolioValuation: (json['portfolio_valuation'] as num?)?.toDouble() ?? 0.0,
      activeMembersCount: (json['active_members_count'] as num?)?.toInt() ?? 0,
      investmentsCount: (json['investments_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        totalFundsCollected,
        totalInvested,
        totalReturns,
        availableLiquidity,
        portfolioValuation,
        activeMembersCount,
        investmentsCount,
      ];
}
