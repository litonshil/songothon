import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/admin_dashboard_model.dart';
import '../models/collection_model.dart';
import '../models/member_dashboard_model.dart';

class DashboardRepository {
  final ApiClient apiClient;

  DashboardRepository({required this.apiClient});

  Future<MemberDashboardModel> getMemberDashboard(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.memberDashboard(slug));
      final data = response.data['data'] as Map<String, dynamic>;
      return MemberDashboardModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<AdminDashboardModel> getAdminDashboard(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminDashboard(slug));
      final data = response.data['data'] as Map<String, dynamic>;
      return AdminDashboardModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<CycleCollectionSummaryModel>> getCollectionCycles(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.collections(slug));
      final data = response.data['data'] as List? ?? [];
      return data
          .map((item) => CycleCollectionSummaryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<CycleCollectionDetailModel> getCollectionCycle(String slug, String cycle) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.collectionCycle(slug, cycle));
      final data = response.data['data'] as Map<String, dynamic>;
      return CycleCollectionDetailModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
