import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/admin_dashboard_model.dart';
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
}
