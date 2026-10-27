import 'package:equatable/equatable.dart';

class ExpenseModel extends Equatable {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime expenseDate;
  final String notes;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.expenseDate,
    required this.notes,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      expenseDate: DateTime.tryParse(json['expense_date']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, category, amount, expenseDate, notes, createdAt];
}
