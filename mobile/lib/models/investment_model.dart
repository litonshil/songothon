import 'package:equatable/equatable.dart';

class InvestmentModel extends Equatable {
  final String id;
  final String name; // Where we invest (Title)
  final double amountInvested; // How much amount we invest
  final String duration; // For how long (e.g., "6 Months", "1 Year")
  final String status;
  final DateTime investmentDate;
  final String? notes;
  final String? creatorName;

  const InvestmentModel({
    required this.id,
    required this.name,
    required this.amountInvested,
    required this.duration,
    required this.status,
    required this.investmentDate,
    this.notes,
    this.creatorName,
  });

  factory InvestmentModel.fromJson(Map<String, dynamic> json) {
    return InvestmentModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      amountInvested: (json['amount'] as num?)?.toDouble() ??
          (json['amount_invested'] as num?)?.toDouble() ??
          0.0,
      duration: json['duration']?.toString().isNotEmpty == true
          ? json['duration'].toString()
          : '1 Year',
      status: json['status']?.toString() ?? 'active',
      investmentDate: DateTime.tryParse(json['investment_date']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString(),
      creatorName: json['creator_name']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, name, amountInvested, duration, status, investmentDate];
}
