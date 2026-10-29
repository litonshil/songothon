import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/contribution_model.dart';

class ContributionRepository {
  final ApiClient apiClient;

  ContributionRepository({required this.apiClient});

  Future<ContributionModel> submitDeposit({
    required String slug,
    required String type,
    required double amount,
    required String paymentMethod,
    required String trxId,
    required String senderAccount,
    required String targetCycle,
    String? notes,
    String? userId,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.submitDepositForOrg(slug),
        data: {
          'type': type,
          'amount': amount,
          'payment_method': paymentMethod,
          'trx_id': trxId.trim(),
          'sender_account': senderAccount.trim(),
          'target_cycle': targetCycle.trim(),
          if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
          // Admins may submit on behalf of another member.
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      return ContributionModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<ContributionModel>> getMyHistory(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.myHistoryForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => ContributionModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<ContributionModel>> getAllContributions(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminAllContributionsForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => ContributionModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<ContributionModel>> getPendingDeposits(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminPendingDepositsForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => ContributionModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<ContributionModel> approveDeposit({required String slug, required String id}) async {
    try {
      final response = await apiClient.dio.post(ApiConstants.adminApproveDepositForOrg(slug, id));
      final data = response.data['data'] as Map<String, dynamic>;
      return ContributionModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<ContributionModel> rejectDeposit({
    required String slug,
    required String id,
    required String reason,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminRejectDepositForOrg(slug, id),
        data: {'rejection_reason': reason.trim(), 'status': 'REJECTED'},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ContributionModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
