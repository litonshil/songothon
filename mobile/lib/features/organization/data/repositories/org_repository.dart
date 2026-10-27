import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/organization_model.dart';

class OrgRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  OrgRepository({required this.apiClient, required this.storageService});

  Future<List<UserOrgMembershipModel>> listMyOrganizations() async {
    try {
      final response = await apiClient.dio.get(ApiConstants.organizations);
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => UserOrgMembershipModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<OrganizationModel> createOrganization({
    required String name,
    required String slug,
    String description = '',
    String currency = 'BDT',
    required double basePricePerShare,
    String contributionFrequency = 'monthly',
    int initialAdminShares = 1,
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.organizations,
        data: {
          'name': name.trim(),
          'slug': slug.trim().toLowerCase(),
          'description': description.trim(),
          'currency': currency,
          'base_price_per_share': basePricePerShare,
          'contribution_frequency': contributionFrequency,
          'initial_admin_shares': initialAdminShares,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final org = OrganizationModel.fromJson(data);
      await storageService.saveCurrentOrgSlug(org.slug);
      await storageService.saveCurrentOrgId(org.id);
      return org;
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<String> joinOrganization(String slug) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.joinOrganization,
        data: {'slug': slug.trim().toLowerCase()},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final status = data?['status']?.toString() ?? 'pending';
      if (status == 'active') {
        await storageService.saveCurrentOrgSlug(slug.trim().toLowerCase());
      }
      return status;
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> selectActiveOrganization(String slug, String id) async {
    await storageService.saveCurrentOrgSlug(slug);
    await storageService.saveCurrentOrgId(id);
  }

  Future<String?> getActiveOrganizationSlug() async {
    return await storageService.getCurrentOrgSlug();
  }

  Future<List<OrgMemberModel>> listMembers(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.membersForOrg(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => OrgMemberModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> inviteMember({
    required String slug,
    required String emailOrPhone,
    required String role,
    required int sharesCount,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminInviteMember(slug),
        data: {
          'email_or_phone': emailOrPhone.trim(),
          'role': role,
          'shares_count': sharesCount,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> updatePrivacy({
    required String slug,
    required bool allowList,
    required bool allowFinancial,
  }) async {
    try {
      await apiClient.dio.patch(
        ApiConstants.adminUpdatePrivacy(slug),
        data: {
          'allow_peer_list_visibility': allowList,
          'allow_peer_financial_visibility': allowFinancial,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<PendingJoinRequestModel>> listJoinRequests(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminJoinRequests(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => PendingJoinRequestModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> approveJoinRequest(String slug, String userId) async {
    try {
      await apiClient.dio.post(ApiConstants.adminApproveJoinRequest(slug, userId));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> rejectJoinRequest(String slug, String userId) async {
    try {
      await apiClient.dio.post(ApiConstants.adminRejectJoinRequest(slug, userId));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> updateMember({
    required String slug,
    required String userId,
    String? role,
    int? sharesCount,
    String? status,
  }) async {
    try {
      await apiClient.dio.patch(
        ApiConstants.adminUpdateMember(slug, userId),
        data: {
          'role': ?role,
          'shares_count': ?sharesCount,
          'status': ?status,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> removeMember(String slug, String userId) async {
    try {
      await apiClient.dio.delete(ApiConstants.adminRemoveMember(slug, userId));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<OrganizationInvitationModel>> listInvitations(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminInvitations(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => OrganizationInvitationModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> createDownPaymentScheme({
    required String slug,
    required String title,
    required double amount,
    required String schemeType,
    required String frequency,
    String? startDate,
    String? dueDate,
  }) async {
    try {
      await apiClient.dio.post(
        '/organizations/$slug/admin/down-payments',
        data: {
          'title': title.trim(),
          'amount': amount,
          'scheme_type': schemeType,
          'frequency': frequency,
          if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
          if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<DownPaymentSchemeModel>> listDownPaymentSchemes(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.downPayments(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => DownPaymentSchemeModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> configureShares({
    required String slug,
    required double basePricePerShare,
    required String frequency,
    required int dueDayOfPeriod,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminShareConfig(slug),
        data: {
          'base_price_per_share': basePricePerShare,
          'frequency': frequency,
          'due_day_of_period': dueDayOfPeriod,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<void> broadcastNotification({
    required String slug,
    required String title,
    required String body,
    List<String>? targetUserIds,
  }) async {
    try {
      await apiClient.dio.post(
        ApiConstants.adminBroadcast(slug),
        data: {
          'title': title.trim(),
          'body': body.trim(),
          if (targetUserIds != null && targetUserIds.isNotEmpty) 'target_user_ids': targetUserIds,
        },
      );
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
