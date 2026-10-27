import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  AuthRepository({required this.apiClient, required this.storageService});

  Future<UserModel> login({required String email, required String password}) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.login,
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userMap = data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userMap);

      await storageService.saveAuthSession(
        token: token,
        role: 'member',
        name: user.fullName,
        email: user.email,
      );

      return user;
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.register,
        data: {
          'email': email.trim(),
          'password': password,
          'full_name': fullName.trim(),
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        },
      );

      final data = response.data['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userMap = data['user'] as Map<String, dynamic>;
      final user = UserModel.fromJson(userMap);

      await storageService.saveAuthSession(
        token: token,
        role: 'member',
        name: user.fullName,
        email: user.email,
      );

      return user;
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<UserModel> getMe() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.me);
      final data = response.data['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> logout() async {
    try {
      // Notify backend to clear FCM token so push notifications stop for this device.
      // Fire-and-forget: we still clear local session even if the API call fails.
      await apiClient.dio.post(ApiConstants.logout);
    } catch (_) {
      // Silently ignore — network errors shouldn't block the user from logging out.
    } finally {
      await storageService.clearSession();
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await storageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> forgotPassword(String email) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.forgotPassword,
        data: {'email': email.trim()},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      return data?['reset_token']?.toString();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await apiClient.dio.post(
        ApiConstants.resetPassword,
        data: {'token': token.trim(), 'new_password': newPassword},
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
