import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import 'api_constants.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService storageService;

  ApiClient({Dio? customDio, required this.storageService})
      : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = ApiConstants.baseUrl;
          final token = await storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          final orgSlug = await storageService.getCurrentOrgSlug();
          if (orgSlug != null && orgSlug.isNotEmpty) {
            options.headers['X-Org-Slug'] = orgSlug;
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expired or invalid: purge local session
            await storageService.clearSession();
          }
          return handler.next(error);
        },
      ),
    );
  }

  String extractErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.response?.data != null && error.response?.data is Map) {
        final data = error.response!.data as Map;
        if (data.containsKey('error') && data['error'] != null) {
          return data['error'].toString();
        }
        if (data.containsKey('message') && data['message'] != null) {
          return data['message'].toString();
        }
      }
      return error.message ?? 'Network connection error';
    }
    return error.toString();
  }
}
