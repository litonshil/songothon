import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final ApiClient apiClient;

  ExpenseRepository({required this.apiClient});

  Future<List<ExpenseModel>> listExpenses(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.expensesForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => ExpenseModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<ExpenseModel> createExpense({
    required String slug,
    required String title,
    required String category,
    required double amount,
    required String expenseDate,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminCreateExpenseForOrg(slug),
        data: {
          'title': title.trim(),
          'category': category.trim(),
          'amount': amount,
          'expense_date': expenseDate,
          if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return ExpenseModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
