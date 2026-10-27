import 'package:equatable/equatable.dart';

class ContributionModel extends Equatable {
  final String id;
  final String orgId;
  final String userId;
  final String type; // 'share_installment', 'down_payment', 'ad_hoc'
  final double amount;
  final String paymentMethod; // 'bkash', 'nagad', 'rocket', 'bank_transfer', 'cash'
  final String trxId;
  final String senderAccount;
  final String? receiptUrl;
  final String targetCycle;
  final String status; // 'PENDING', 'APPROVED', 'REJECTED'
  final String? rejectionReason;
  final DateTime paidAt;
  final String? notes;
  final String? memberName;
  final String? memberEmail;

  const ContributionModel({
    required this.id,
    required this.orgId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.trxId,
    required this.senderAccount,
    this.receiptUrl,
    required this.targetCycle,
    required this.status,
    this.rejectionReason,
    required this.paidAt,
    this.notes,
    this.memberName,
    this.memberEmail,
  });

  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';

  factory ContributionModel.fromJson(Map<String, dynamic> json) {
    return ContributionModel(
      id: json['id']?.toString() ?? '',
      orgId: json['org_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'share_installment',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method']?.toString() ?? 'bkash',
      trxId: json['trx_id']?.toString() ?? '',
      senderAccount: json['sender_account']?.toString() ?? '',
      receiptUrl: json['receipt_url']?.toString(),
      targetCycle: json['target_cycle']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      rejectionReason: json['rejection_reason']?.toString(),
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString(),
      memberName: json['member_name']?.toString(),
      memberEmail: json['member_email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'org_id': orgId,
        'user_id': userId,
        'type': type,
        'amount': amount,
        'payment_method': paymentMethod,
        'trx_id': trxId,
        'sender_account': senderAccount,
        'receipt_url': receiptUrl,
        'target_cycle': targetCycle,
        'status': status,
        'rejection_reason': rejectionReason,
        'paid_at': paidAt.toIso8601String(),
        'notes': notes,
      };

  @override
  List<Object?> get props => [
        id,
        orgId,
        userId,
        type,
        amount,
        paymentMethod,
        trxId,
        senderAccount,
        receiptUrl,
        targetCycle,
        status,
        rejectionReason,
        paidAt,
        notes,
        memberName,
        memberEmail,
      ];
}
