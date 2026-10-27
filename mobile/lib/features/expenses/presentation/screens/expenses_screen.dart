import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../shared/presentation/widgets/app_widgets.dart';
import '../../data/models/expense_model.dart';
import '../../data/repositories/expense_repository.dart';

class ExpensesScreen extends StatefulWidget {
  final String orgSlug;
  final bool isAdmin;
  final String currency;

  const ExpensesScreen({super.key, required this.orgSlug, required this.isAdmin, this.currency = 'BDT'});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<ExpenseModel> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      if (_items.isEmpty) _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<ExpenseRepository>().listExpenses(widget.orgSlug);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _total => _items.fold(0.0, (sum, item) => sum + item.amount);

  Future<void> _showForm() async {
    final title = TextEditingController();
    final category = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    String? titleError;
    String? amountError;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Add Expense', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: title,
                  decoration: InputDecoration(labelText: 'Title', hintText: 'e.g. Office rent', errorText: titleError),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: category,
                  decoration: const InputDecoration(labelText: 'Category', hintText: 'e.g. Rent, Utilities'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: 'Amount', errorText: amountError),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setSheetState(() => date = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_month_outlined, size: 18)),
                          child: Text(DateFormat('dd MMM yyyy').format(date)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () {
                    final parsedAmount = double.tryParse(amount.text.trim()) ?? 0;
                    setSheetState(() {
                      titleError = title.text.trim().isEmpty ? 'Enter a title' : null;
                      amountError = parsedAmount <= 0 ? 'Enter an amount greater than zero' : null;
                    });
                    if (titleError == null && amountError == null) Navigator.pop(ctx, true);
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await context.read<ExpenseRepository>().createExpense(
            slug: widget.orgSlug,
            title: title.text.trim(),
            category: category.text.trim().isEmpty ? 'general' : category.text.trim(),
            amount: double.tryParse(amount.text.trim()) ?? 0,
            expenseDate: DateFormat('yyyy-MM-dd').format(date),
            notes: notes.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense recorded.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.errorRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              onPressed: _showForm,
              tooltip: 'Add expense',
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryNavy))
          : _error != null
              ? EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load expenses', message: _error!, actionLabel: 'Retry', onAction: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.primaryNavy,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Expense', style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      formatMoney(_total, widget.currency),
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.warningOrange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text('${_items.length} entries', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_items.isEmpty)
                        const SizedBox(
                          height: 320,
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No expenses yet',
                            message: 'Organization expenses recorded by admins will appear here.',
                          ),
                        )
                      else
                        ..._items.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningOrange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.payments_outlined, size: 18, color: AppTheme.warningOrange),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${humanize(item.category)} • ${DateFormat('dd MMM yyyy').format(item.expenseDate)}',
                                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                          ),
                                          if (item.notes.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(item.notes, style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.35)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      formatMoney(item.amount, widget.currency),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
