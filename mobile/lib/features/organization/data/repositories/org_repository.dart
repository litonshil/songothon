import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../models/organization_model.dart';
import '../models/settlement_model.dart';

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

  Future<OrganizationModel> renameOrganization({
    required String slug,
    required String name,
    String? description,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        ApiConstants.adminUpdateOrg(slug),
        data: {
          'name': name.trim(),
          'description': ?description?.trim(),
        },
      );
      return OrganizationModel.fromJson(response.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  /// Leaves the organization. Membership history is kept on the server; only
  /// the status changes. The last admin must pass [successorUserId] when other
  /// active members remain.
  Future<void> leaveOrganization(String slug, {String? successorUserId}) async {
    try {
      await apiClient.dio.post(
        ApiConstants.leaveOrg(slug),
        data: {'successor_user_id': ?successorUserId},
      );
      if (await storageService.getCurrentOrgSlug() == slug) {
        await storageService.clearCurrentOrg();
      }
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
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
    bool? allowCollection,
  }) async {
    try {
      await apiClient.dio.patch(
        ApiConstants.adminUpdatePrivacy(slug),
        data: {
          'allow_peer_list_visibility': allowList,
          'allow_peer_financial_visibility': allowFinancial,
          'allow_member_collection_visibility': ?allowCollection,
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

  /// Calculates what [userId] would be paid if settled now. Changes nothing.
  Future<SettlementPreviewModel> getSettlementPreview(String slug, String userId) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminMemberSettlement(slug, userId));
      return SettlementPreviewModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  /// Pays the member out and ends their membership. [finalAmount] defaults to
  /// the calculated amount on the server; a different amount needs [notes].
  Future<MemberSettlementModel> settleMember({
    required String slug,
    required String userId,
    double? finalAmount,
    required String paymentMethod,
    String trxId = '',
    String notes = '',
  }) async {
    try {
      final response = await apiClient.dio.post(
        ApiConstants.adminMemberSettlement(slug, userId),
        data: {
          'final_amount': ?finalAmount,
          'payment_method': paymentMethod,
          'trx_id': trxId.trim(),
          'notes': notes.trim(),
        },
      );
      return MemberSettlementModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }

  Future<List<MemberSettlementModel>> listSettlements(String slug) async {
    try {
      final response = await apiClient.dio.get(ApiConstants.adminSettlements(slug));
      final list = response.data['data'] as List? ?? [];
      return list.map((item) => MemberSettlementModel.fromJson(item as Map<String, dynamic>)).toList();
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

  Future<void> updateDownPaymentScheme({
    required String slug,
    required String schemeId,
    required String title,
    required double amount,
    required String schemeType,
    required String frequency,
    String? startDate,
    String? dueDate,
  }) async {
    try {
      await apiClient.dio.put(
        '/organizations/$slug/admin/down-payments/$schemeId',
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

  Future<SchemePeriodReportModel> getDownPaymentStatus(String slug, String schemeId, {String? period}) async {
    try {
      final response = await apiClient.dio.get(
        ApiConstants.adminDownPaymentStatus(slug, schemeId),
        queryParameters: {if (period != null && period.isNotEmpty) 'period': period},
      );
      return SchemePeriodReportModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
    } catch (e) {
      throw apiClient.extractErrorMessage(e);
    }
  }
}
