/// Response of POST /admin/contributions/bulk-upload (preview or import).
class BulkDepositResultModel {
  final bool dryRun;
  final bool imported;
  final String paymentMethod;
  final List<String> cycles;
  final int memberCount;
  final int createCount;
  final double createAmount;
  final int skippedCount;
  final double skippedAmount;
  final List<BulkDepositErrorModel> errors;
  final List<BulkDepositItemModel> items;

  const BulkDepositResultModel({
    required this.dryRun,
    required this.imported,
    required this.paymentMethod,
    required this.cycles,
    required this.memberCount,
    required this.createCount,
    required this.createAmount,
    required this.skippedCount,
    required this.skippedAmount,
    required this.errors,
    required this.items,
  });

  bool get hasErrors => errors.isNotEmpty;

  factory BulkDepositResultModel.fromJson(Map<String, dynamic> json) {
    return BulkDepositResultModel(
      dryRun: json['dry_run'] == true,
      imported: json['imported'] == true,
      paymentMethod: json['payment_method']?.toString() ?? 'cash',
      cycles: (json['cycles'] as List? ?? []).map((e) => e.toString()).toList(),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      createCount: (json['create_count'] as num?)?.toInt() ?? 0,
      createAmount: (json['create_amount'] as num?)?.toDouble() ?? 0,
      skippedCount: (json['skipped_count'] as num?)?.toInt() ?? 0,
      skippedAmount: (json['skipped_amount'] as num?)?.toDouble() ?? 0,
      errors: (json['errors'] as List? ?? [])
          .map((e) => BulkDepositErrorModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List? ?? [])
          .map((e) => BulkDepositItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BulkDepositErrorModel {
  final int? row;
  final String? column;
  final String message;

  const BulkDepositErrorModel({this.row, this.column, required this.message});

  String get location {
    final parts = <String>[
      if (row != null && row! > 0) 'Row $row',
      if (column != null && column!.isNotEmpty) column!,
    ];
    return parts.join(' • ');
  }

  factory BulkDepositErrorModel.fromJson(Map<String, dynamic> json) {
    return BulkDepositErrorModel(
      row: (json['row'] as num?)?.toInt(),
      column: json['column']?.toString(),
      message: json['message']?.toString() ?? '',
    );
  }
}

class BulkDepositItemModel {
  final int row;
  final String email;
  final String memberName;
  final String cycle;
  final double amount;
  final String status; // will_create | created | already_recorded

  const BulkDepositItemModel({
    required this.row,
    required this.email,
    required this.memberName,
    required this.cycle,
    required this.amount,
    required this.status,
  });

  bool get isSkipped => status == 'already_recorded';

  factory BulkDepositItemModel.fromJson(Map<String, dynamic> json) {
    return BulkDepositItemModel(
      row: (json['row'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      memberName: json['member_name']?.toString() ?? '',
      cycle: json['cycle']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

/// Thrown when the server rejects a sheet with row-level validation errors (HTTP 422).
class BulkDepositValidationException implements Exception {
  final String message;
  final BulkDepositResultModel result;

  const BulkDepositValidationException(this.message, this.result);

  @override
  String toString() => message;
}
