import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../models/contribution_model.dart';
import '../../state/dashboard/dashboard_cubit.dart';

class SubmitDepositDialog extends StatefulWidget {
  final List<ContributionPeriodModel> periods;

  const SubmitDepositDialog({super.key, required this.periods});

  @override
  State<SubmitDepositDialog> createState() => _SubmitDepositDialogState();
}

class _SubmitDepositDialogState extends State<SubmitDepositDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedPeriodId;
  double _predefinedAmount = 200.00;
  final _trxIdController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'bkash';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.periods.isNotEmpty) {
      // Pick first active or latest period
      final active = widget.periods.firstWhere(
        (p) => p.isActive,
        orElse: () => widget.periods.first,
      );
      _selectedPeriodId = active.id;
      _predefinedAmount = active.amountDue;
    }
  }

  @override
  void dispose() {
    _trxIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPeriodChanged(String? periodId) {
    setState(() {
      _selectedPeriodId = periodId;
      if (periodId != null) {
        final period = widget.periods.firstWhere((p) => p.id == periodId);
        _predefinedAmount = period.amountDue;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    final success = await context.read<DashboardCubit>().submitMemberDeposit(
          periodId: _selectedPeriodId,
          amount: _predefinedAmount,
          paymentMethod: _paymentMethod,
          transactionId: _trxIdController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deposit submitted! Status is PENDING until Admin approves.'),
            backgroundColor: AppTheme.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit deposit. Please try again.'),
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
                        'Add Monthly Deposit',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                // Predefined Amount Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PREDEFINED AMOUNT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                            ),
                            Text(
                              'Monthly Savings Dues',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textDark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${_predefinedAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Month / Cycle Selector
                if (widget.periods.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPeriodId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Select Month / Cycle'),
                    items: widget.periods.map((p) {
                      return DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          '${p.title} (\$${p.amountDue.toStringAsFixed(0)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _onPeriodChanged,
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment Method (Bank / MFS)
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Payment Method (Bank / MFS)'),
                  items: const [
                    DropdownMenuItem(value: 'bkash', child: Text('bKash (MFS)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'nagad', child: Text('Nagad (MFS)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'bank', child: Text('Bank Transfer', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'cash', child: Text('Cash Handover', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setState(() => _paymentMethod = val ?? 'bkash'),
                ),
                const SizedBox(height: 16),

                // Transaction ID
                TextFormField(
                  controller: _trxIdController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction ID / TrxID *',
                    hintText: 'e.g. 9B8X7K62 or Bank Ref',
                    prefixIcon: Icon(Icons.receipt_long),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the transaction ID';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Notes (Optional)
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Sent from 017XXXXXXXX',
                  ),
                ),
                const SizedBox(height: 16),

                // Info notice
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requires admin approval. Shows as PAID after verification.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Deposit Entry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
