import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../models/contribution_model.dart';
import '../models/pool_metrics_model.dart';
import '../models/user_model.dart';

class DashboardRepository {
  final ApiClient apiClient;

  DashboardRepository({required this.apiClient});

  // Get Aggregate Pool Overview
  Future<PoolMetricsModel> getPoolOverview() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.overview);
      final data = response.data['data'] as Map<String, dynamic>;
      return PoolMetricsModel.fromJson(data);
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Get Member Personal Dues & History
  Future<MemberFinancialSummaryModel> getMyFinancialSummary() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.myDues);
      final data = response.data['data'] as Map<String, dynamic>;
      return MemberFinancialSummaryModel.fromJson(data);
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Get Contribution Periods
  Future<List<ContributionPeriodModel>> getPeriods({bool activeOnly = false}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.periods,
        queryParameters: {'active': activeOnly},
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ContributionPeriodModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Member submits their monthly deposit (Status: Pending admin approval)
  Future<ContributionModel> submitMemberDeposit({
    String? periodId,
    double? amount,
    required String paymentMethod,
    required String transactionId,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.submitDeposit,
        data: {
          if (periodId != null && periodId.isNotEmpty) 'period_id': periodId,
          if (amount != null && amount > 0) 'amount': amount,
          'payment_method': paymentMethod,
          'transaction_id': transactionId,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ContributionModel.fromJson(data);
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Admin: Get list of pending deposit approvals
  Future<List<ContributionModel>> getPendingApprovals() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminPendingDeposits);
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => ContributionModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Admin: Approve pending deposit
  Future<void> approveDeposit(String id) async {
    try {
      await apiClient.dio.post(ApiConstants.adminApproveDeposit(id));
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Admin: Reject pending deposit
  Future<void> rejectDeposit(String id, {String? reason}) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminRejectDeposit(id),
        data: {
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Month-wise deposit reports (who paid for the month)
  Future<MonthlyDepositReportModel> getMonthlyReport({String? periodId}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.monthlyReport,
        queryParameters: periodId != null && periodId.isNotEmpty ? {'period_id': periodId} : null,
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return MonthlyDepositReportModel.fromJson(data);
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // All monthly deposit reports
  Future<List<MonthlyDepositReportModel>> getAllMonthlyReports() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.allMonthlyReports);
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => MonthlyDepositReportModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Admin: Get Member List
  Future<List<UserModel>> getMembers({String? status}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.adminMembers,
        queryParameters: status != null ? {'status': status} : null,
      );
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Admin: Record Direct Deposit
  Future<void> recordDeposit({
    required String userId,
    String? periodId,
    required double amount,
    required String paymentMethod,
    String? referenceNo,
    String? notes,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminRecordDeposit,
        data: {
          'user_id': userId,
          'period_id': periodId,
          'amount': amount,
          'payment_method': paymentMethod,
          'transaction_id': referenceNo,
          'reference_no': referenceNo,
          'notes': notes,
        },
      );
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }
}
