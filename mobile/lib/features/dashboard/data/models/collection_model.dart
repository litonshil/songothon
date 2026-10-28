import 'package:equatable/equatable.dart';

double _toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

class CycleCollectionSummaryModel extends Equatable {
  final String cycle;
  final double expectedAmount;
  final double collectedAmount;
  final double pendingAmount;
  final double collectionRate;

  const CycleCollectionSummaryModel({
    required this.cycle,
    required this.expectedAmount,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.collectionRate,
  });

  factory CycleCollectionSummaryModel.fromJson(Map<String, dynamic> json) {
    return CycleCollectionSummaryModel(
      cycle: json['cycle']?.toString() ?? '',
      expectedAmount: _toDouble(json['expected_amount']),
      collectedAmount: _toDouble(json['collected_amount']),
      pendingAmount: _toDouble(json['pending_amount']),
      collectionRate: _toDouble(json['collection_rate']),
    );
  }

  @override
  List<Object?> get props => [
    cycle,
    expectedAmount,
    collectedAmount,
    pendingAmount,
    collectionRate,
  ];
}

class MemberCycleCollectionModel extends Equatable {
  final String userId;
  final String fullName;
  final bool isCurrentUser;
  final int? sharesCount;
  final double? expectedAmount;
  final double? paidAmount;
  final double? pendingAmount;
  final String? status;

  const MemberCycleCollectionModel({
    required this.userId,
    required this.fullName,
    required this.isCurrentUser,
    this.sharesCount,
    this.expectedAmount,
    this.paidAmount,
    this.pendingAmount,
    this.status,
  });

  bool get hasFinancials => status != null;

  factory MemberCycleCollectionModel.fromJson(Map<String, dynamic> json) {
    return MemberCycleCollectionModel(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      sharesCount: (json['shares_count'] as num?)?.toInt(),
      expectedAmount: (json['expected_amount'] as num?)?.toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble(),
      pendingAmount: (json['pending_amount'] as num?)?.toDouble(),
      status: json['status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    userId,
    fullName,
    isCurrentUser,
    sharesCount,
    expectedAmount,
    paidAmount,
    pendingAmount,
    status,
  ];
}

class CycleCollectionDetailModel extends Equatable {
  final String cycle;
  final double expectedAmount;
  final double collectedAmount;
  final double pendingAmount;
  final double collectionRate;
  final List<MemberCycleCollectionModel> members;

  const CycleCollectionDetailModel({
    required this.cycle,
    required this.expectedAmount,
    required this.collectedAmount,
    required this.pendingAmount,
    required this.collectionRate,
    required this.members,
  });

  factory CycleCollectionDetailModel.fromJson(Map<String, dynamic> json) {
    final members = json['members'] as List? ?? [];
    return CycleCollectionDetailModel(
      cycle: json['cycle']?.toString() ?? '',
      expectedAmount: _toDouble(json['expected_amount']),
      collectedAmount: _toDouble(json['collected_amount']),
      pendingAmount: _toDouble(json['pending_amount']),
      collectionRate: _toDouble(json['collection_rate']),
      members: members
          .map(
            (item) => MemberCycleCollectionModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    cycle,
    expectedAmount,
    collectedAmount,
    pendingAmount,
    collectionRate,
    members,
  ];
}
