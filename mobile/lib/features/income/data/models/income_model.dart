import 'package:equatable/equatable.dart';

class IncomeModel extends Equatable {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime incomeDate;
  final String notes;
  final DateTime createdAt;

  const IncomeModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.incomeDate,
    required this.notes,
    required this.createdAt,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    return IncomeModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      incomeDate: DateTime.tryParse(json['income_date']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, category, amount, incomeDate, notes, createdAt];
}
