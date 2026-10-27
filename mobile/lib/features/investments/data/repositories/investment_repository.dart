import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../models/investment_model.dart';

class InvestmentRepository {
  final ApiClient apiClient;

  InvestmentRepository({required this.apiClient});

  Future<List<InvestmentModel>> listInvestments(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.investmentsForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => InvestmentModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<InvestmentModel> getInvestmentDetail(String slug, String id) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.investmentDetail(slug, id));
      final data = response.data['data'] as Map<String, dynamic>;
      return InvestmentModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<PortfolioMetricsModel> getPortfolioMetrics(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.portfolioMetrics(slug));
      final data = response.data['data'] as Map<String, dynamic>;
      return PortfolioMetricsModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<InvestmentModel> updateInvestment({
    required String slug,
    required String id,
    String? title,
    String? category,
    double? investedCapital,
    double? currentValuation,
    double? expectedRoi,
    double? realizedReturns,
    String? tenure,
    String? status,
    String? notes,
    String? maturityDate,
  }) async {
    try {
      final response = await apiClient.dio.put(
        ApiConstants.adminUpdateInvestmentForOrg(slug, id),
        data: {
          'title': ?title,
          'category': ?category,
          'invested_capital': ?investedCapital,
          'current_valuation': ?currentValuation,
          'expected_roi': ?expectedRoi,
          'realized_returns': ?realizedReturns,
          'tenure': ?tenure,
          'status': ?status,
          'notes': ?notes,
          'maturity_date': ?maturityDate,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return InvestmentModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> deleteInvestment(String slug, String id) async {
    try {
      await apiClient.dio.delete(ApiConstants.adminUpdateInvestmentForOrg(slug, id));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<InvestmentModel> createInvestment({
    required String slug,
    required String title,
    required String category,
    required double investedCapital,
    required double expectedRoi,
    required String tenure,
    required String investmentDate,
    String? maturityDate,
    String? notes,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminCreateInvestmentForOrg(slug),
        data: {
          'title': title.trim(),
          'category': category.trim(),
          'invested_capital': investedCapital,
          'expected_roi': expectedRoi,
          'tenure': tenure.trim(),
          'investment_date': investmentDate,
          if (maturityDate != null && maturityDate.isNotEmpty) 'maturity_date': maturityDate,
          if (notes != null && notes.isNotEmpty) 'notes': notes.trim(),
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return InvestmentModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
