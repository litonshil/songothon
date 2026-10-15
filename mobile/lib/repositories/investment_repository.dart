import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../models/investment_model.dart';

class InvestmentRepository {
  final ApiClient apiClient;

  InvestmentRepository({required this.apiClient});

  // Read-only for all members & admins
  Future<List<InvestmentModel>> getInvestments() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.investments);
      final list = response.data['data'] as List<dynamic>? ?? [];
      return list.map((e) => InvestmentModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  // Simple Create Investment (Title, Amount, Duration)
  Future<InvestmentModel> createInvestment({
    required String title,
    required double amount,
    required String duration,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminCreateInvestment,
        data: {
          'title': title,
          'name': title,
          'amount': amount,
          'amount_invested': amount,
          'duration': duration,
          'notes': notes ?? '',
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return InvestmentModel.fromJson(data);
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }
}
