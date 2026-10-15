import 'package:equatable/equatable.dart';
import '../../models/contribution_model.dart';
import '../../models/pool_metrics_model.dart';
import '../../models/user_model.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final PoolMetricsModel poolMetrics;
  final MemberFinancialSummaryModel? memberSummary;
  final List<UserModel> members;
  final List<ContributionPeriodModel> periods;
  final List<ContributionModel> pendingApprovals;
  final List<MonthlyDepositReportModel> monthlyReports;

  const DashboardLoaded({
    required this.poolMetrics,
    this.memberSummary,
    this.members = const [],
    this.periods = const [],
    this.pendingApprovals = const [],
    this.monthlyReports = const [],
  });

  @override
  List<Object?> get props => [
        poolMetrics,
        memberSummary,
        members,
        periods,
        pendingApprovals,
        monthlyReports,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
