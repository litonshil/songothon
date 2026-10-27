import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/income_model.dart';

class IncomeRepository {
  final ApiClient apiClient;

  IncomeRepository({required this.apiClient});

  Future<List<IncomeModel>> listIncomes(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.incomesForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => IncomeModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<IncomeModel> createIncome({
    required String slug,
    required String title,
    required String category,
    required double amount,
    required String incomeDate,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminCreateIncomeForOrg(slug),
        data: {
          'title': title.trim(),
          'category': category.trim(),
          'amount': amount,
          'income_date': incomeDate,
          if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return IncomeModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
