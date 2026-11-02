import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/bulk_deposit_result_model.dart';
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

  /// Uploads a deposits .xlsx sheet. With [dryRun] the server only validates
  /// and returns a preview; otherwise the deposits are imported and approved.
  /// Throws [BulkDepositValidationException] when the sheet has row errors.
  Future<BulkDepositResultModel> bulkUploadDeposits({
    required String slug,
    required Uint8List bytes,
    required String fileName,
    required String paymentMethod,
    required bool dryRun,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'payment_method': paymentMethod,
        'dry_run': dryRun.toString(),
      });
      final response = await apiClient.dio.post(
        ApiConstants.adminBulkUploadDeposits(slug),
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return BulkDepositResultModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 422 && body is Map && body['data'] is Map) {
        throw BulkDepositValidationException(
          body['error']?.toString() ?? 'The spreadsheet has errors',
          BulkDepositResultModel.fromJson(Map<String, dynamic>.from(body['data'] as Map)),
        );
      }
      throw apiClient.extractErrorMessage(e);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
