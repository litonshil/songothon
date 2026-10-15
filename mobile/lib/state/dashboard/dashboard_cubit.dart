import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/contribution_model.dart';
import '../../repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository dashboardRepository;

  DashboardCubit({required this.dashboardRepository}) : super(DashboardInitial());

  Future<void> loadDashboard({required bool isAdmin}) async {
    emit(DashboardLoading());
    try {
      final poolMetrics = await dashboardRepository.getPoolOverview();
      final periods = await dashboardRepository.getPeriods();
      List<MonthlyDepositReportModel> monthlyReports = [];
      try {
        monthlyReports = await dashboardRepository.getAllMonthlyReports();
      } catch (_) {}

      if (isAdmin) {
        final members = await dashboardRepository.getMembers();
        List<ContributionModel> pending = [];
        try {
          pending = await dashboardRepository.getPendingApprovals();
        } catch (_) {}

        emit(DashboardLoaded(
          poolMetrics: poolMetrics,
          members: members,
          periods: periods,
          pendingApprovals: pending,
          monthlyReports: monthlyReports,
        ));
      } else {
        final memberSummary = await dashboardRepository.getMyFinancialSummary();
        emit(DashboardLoaded(
          poolMetrics: poolMetrics,
          memberSummary: memberSummary,
          periods: periods,
          monthlyReports: monthlyReports,
        ));
      }
    } catch (e) {
      emit(DashboardError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  // Member submits their monthly deposit (Status: Pending)
  Future<bool> submitMemberDeposit({
    String? periodId,
    double? amount,
    required String paymentMethod,
    required String transactionId,
    String? notes,
  }) async {
    try {
      await dashboardRepository.submitMemberDeposit(
        periodId: periodId,
        amount: amount,
        paymentMethod: paymentMethod,
        transactionId: transactionId,
        notes: notes,
      );
      await loadDashboard(isAdmin: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin approves a pending deposit
  Future<bool> approveDeposit(String id) async {
    try {
      await dashboardRepository.approveDeposit(id);
      await loadDashboard(isAdmin: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin rejects a pending deposit
  Future<bool> rejectDeposit(String id, {String? reason}) async {
    try {
      await dashboardRepository.rejectDeposit(id, reason: reason);
      await loadDashboard(isAdmin: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Admin directly records a deposit
  Future<bool> recordDeposit({
    required String userId,
    String? periodId,
    required double amount,
    required String paymentMethod,
    String? referenceNo,
    String? notes,
  }) async {
    try {
      await dashboardRepository.recordDeposit(
        userId: userId,
        periodId: periodId,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNo: referenceNo,
        notes: notes,
      );
      await loadDashboard(isAdmin: true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
