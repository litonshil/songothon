import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../state/investment/investment_cubit.dart';

class RecordInvestmentDialog extends StatefulWidget {
  const RecordInvestmentDialog({super.key});

  @override
  State<RecordInvestmentDialog> createState() => _RecordInvestmentDialogState();
}

class _RecordInvestmentDialogState extends State<RecordInvestmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _durationController = TextEditingController(text: '1 Year');
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _durationSuggestions = [
    '3 Months',
    '6 Months',
    '1 Year',
    '2 Years',
    '3 Years',
    '5 Years',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid investment amount'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await context.read<InvestmentCubit>().createInvestment(
          title: _titleController.text.trim(),
          amount: amount,
          duration: _durationController.text.trim().isNotEmpty
              ? _durationController.text.trim()
              : '1 Year',
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Investment recorded successfully!'),
            backgroundColor: AppTheme.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record investment. Please check funds.'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Record New Investment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Record where club funds are being deployed.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),

                // 1. Where we invest (Title)
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Where We Invest (Title) *',
                    hintText: 'e.g., National Savings Sukuk, Agro Project',
                    prefixIcon: Icon(Icons.business_center_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter investment title' : null,
                ),
                const SizedBox(height: 14),

                // 2. How much amount we invest
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Investment Amount (\$) *',
                    hintText: 'e.g., 5000',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter amount';
                    final val = double.tryParse(v.trim());
                    if (val == null || val <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. For how long for we invest (Duration)
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Investment Duration *',
                    hintText: 'e.g., 6 Months, 1 Year',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter duration' : null,
                ),
                const SizedBox(height: 8),

                // Duration suggestion chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _durationSuggestions.map((d) {
                    return ActionChip(
                      label: Text(d, style: const TextStyle(fontSize: 11)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() {
                          _durationController.text = d;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Notes / Description
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Details (Optional)',
                    hintText: 'Contract details, counterparty info, etc.',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save Investment',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
