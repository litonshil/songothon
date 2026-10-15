import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../../models/contribution_model.dart';
import '../../models/user_model.dart';
import '../../state/dashboard/dashboard_cubit.dart';

class RecordDepositDialog extends StatefulWidget {
  final List<UserModel> members;
  final List<ContributionPeriodModel> periods;

  const RecordDepositDialog({
    super.key,
    required this.members,
    required this.periods,
  });

  @override
  State<RecordDepositDialog> createState() => _RecordDepositDialogState();
}

class _RecordDepositDialogState extends State<RecordDepositDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUserId;
  String? _selectedPeriodId;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'bank_transfer';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.members.isNotEmpty) {
      _selectedUserId = widget.members.first.id;
    }
    if (widget.periods.isNotEmpty) {
      _selectedPeriodId = widget.periods.first.id;
      _amountController.text = widget.periods.first.amountDue.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onPeriodChanged(String? periodId) {
    setState(() {
      _selectedPeriodId = periodId;
      if (periodId != null) {
        final period = widget.periods.firstWhere((p) => p.id == periodId);
        _amountController.text = period.amountDue.toStringAsFixed(2);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedUserId == null) return;

    setState(() => _isSubmitting = true);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final success = await context.read<DashboardCubit>().recordDeposit(
          userId: _selectedUserId!,
          periodId: _selectedPeriodId,
          amount: amount,
          paymentMethod: _paymentMethod,
          referenceNo: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member deposit recorded successfully in financial ledger'),
            backgroundColor: AppTheme.darkGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to record deposit. Please check inputs.'),
            backgroundColor: AppTheme.errorRed,
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
                        'Record Member Deposit',
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

                // Member Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Select Member'),
                  items: widget.members.map((m) {
                    return DropdownMenuItem(
                      value: m.id,
                      child: Text(
                        '${m.fullName} (${m.email})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedUserId = val),
                  validator: (v) => v == null ? 'Please select a member' : null,
                ),
                const SizedBox(height: 14),

                // Contribution Period Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedPeriodId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Contribution Cycle'),
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
                const SizedBox(height: 14),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount Received (\$)',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (val) {
                    final num = double.tryParse(val ?? '');
                    if (num == null || num <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment Method
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Payment Channel'),
                  items: const [
                    DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Wire / Transfer', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money (bKash/Nagad)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'cash', child: Text('Cash in Hand', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setState(() => _paymentMethod = val ?? 'bank_transfer'),
                ),
                const SizedBox(height: 14),

                // Transaction Reference
                TextFormField(
                  controller: _refController,
                  decoration: const InputDecoration(
                    labelText: 'Transaction Ref # (Optional)',
                    hintText: 'e.g., TXN-984210 or Check #',
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm & Post to Ledger'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
