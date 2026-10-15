import '../core/api/api_client.dart';
import '../core/api/api_constants.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  AuthRepository({required this.apiClient, required this.storageService});

  Future<UserModel> login({required String email, required String password}) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userJson);

      await storageService.saveAuthSession(
        token: token,
        role: user.role,
        name: user.fullName,
        email: user.email,
      );

      return user;
    } catch (e) {
      throw Exception(apiClient.extractErrorMessage(e));
    }
  }

  Future<UserModel?> checkAuthStatus() async {
    try {
      final token = await storageService.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      final response = await apiClient.dio.get(ApiConstants.me);
      if (response.statusCode == 200) {
        final data = response.data['data'] as Map<String, dynamic>;
        return UserModel.fromJson(data);
      }
      return null;
    } catch (_) {
      await storageService.clearSession();
      return null;
    }
  }

  Future<void> logout() async {
    await storageService.clearSession();
  }
}
