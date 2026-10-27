import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/contribution_cubit.dart';
import '../bloc/contribution_state.dart';

class SubmitPaymentBottomSheet extends StatefulWidget {
  final String orgSlug;
  final String currentCycle;
  final double defaultAmount;
  final VoidCallback? onSuccess;

  const SubmitPaymentBottomSheet({
    super.key,
    required this.orgSlug,
    required this.currentCycle,
    this.defaultAmount = 1000.0,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String orgSlug,
    required String currentCycle,
    double defaultAmount = 1000.0,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider.value(
        value: BlocProvider.of<ContributionCubit>(context),
        child: SubmitPaymentBottomSheet(
          orgSlug: orgSlug,
          currentCycle: currentCycle,
          defaultAmount: defaultAmount,
          onSuccess: onSuccess,
        ),
      ),
    );
  }

  @override
  State<SubmitPaymentBottomSheet> createState() => _SubmitPaymentBottomSheetState();
}

class _SubmitPaymentBottomSheetState extends State<SubmitPaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();

  String _selectedMethod = 'bkash';
  String _selectedType = 'share_installment';
  late final TextEditingController _amountController;
  late final TextEditingController _senderController;
  late final TextEditingController _trxIdController;
  late final TextEditingController _cycleController;
  late DateTime _cycle;
  late final TextEditingController _notesController;
  late final TextEditingController _receiptController;

  final List<Map<String, String>> _paymentMethods = [
    {'id': 'bkash', 'name': 'bKash (বিকাশ)', 'icon': '📱'},
    {'id': 'nagad', 'name': 'Nagad (নগদ)', 'icon': '📲'},
    {'id': 'rocket', 'name': 'Rocket (রকেট)', 'icon': '🚀'},
    {'id': 'bank_transfer', 'name': 'Bank Transfer (ব্যাংক)', 'icon': '🏦'},
    {'id': 'cash', 'name': 'Cash (নগদ জমা)', 'icon': '💵'},
  ];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.defaultAmount.toStringAsFixed(0));
    _senderController = TextEditingController();
    _trxIdController = TextEditingController();
    _cycle = DateTime.now();
    _cycleController = TextEditingController(text: _formatCycle(_cycle));
    _notesController = TextEditingController();
    _receiptController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderController.dispose();
    _trxIdController.dispose();
    _cycleController.dispose();
    _notesController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  String _formatCycle(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}';

  Future<void> _pickCycle() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(initial: _cycle),
    );
    if (picked == null) return;
    setState(() {
      _cycle = picked;
      _cycleController.text = _formatCycle(picked);
    });
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    context.read<ContributionCubit>().submitPayment(
          slug: widget.orgSlug,
          type: _selectedType,
          amount: amount,
          paymentMethod: _selectedMethod,
          trxId: _trxIdController.text.trim(),
          senderAccount: _senderController.text.trim(),
          targetCycle: _cycleController.text.trim(),
          receiptUrl: _receiptController.text.trim().isEmpty ? null : _receiptController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BlocConsumer<ContributionCubit, ContributionState>(
      listener: (context, state) {
        if (state is ContributionSubmittedSuccess) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: const Color(0xFF1B5E20),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          widget.onSuccess?.call();
        } else if (state is ContributionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: const Color(0xFFB71C1C),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ContributionSubmitting;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submit Deposit',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Cycle: ${widget.currentCycle}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Deposit Type
                  const Text(
                    'Deposit Category',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'share_installment', label: Text('Installment')),
                      ButtonSegment(value: 'down_payment', label: Text('Down Payment')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (set) {
                      setState(() {
                        _selectedType = set.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Selector
                  const Text(
                    'Payment Channel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMethod,
                        isExpanded: true,
                        items: _paymentMethods.map((m) {
                          return DropdownMenuItem<String>(
                            value: m['id'],
                            child: Row(
                              children: [
                                Text(m['icon']!, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedMethod = val);
                                }
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    decoration: InputDecoration(
                      labelText: 'Amount (BDT)',
                      prefixText: '৳ ',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter the deposited amount';
                      }
                      final amt = double.tryParse(val.trim());
                      if (amt == null || amt <= 0) {
                        return 'Amount must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Sender Number
                  TextFormField(
                    controller: _senderController,
                    keyboardType: TextInputType.phone,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: 'Sender Account / Phone Number',
                      hintText: 'e.g. 01711223344 or AC#100293',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your sender mobile or bank account';
                      }
                      if (val.trim().length < 4) {
                        return 'Account number is too short';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Transaction ID (TrxID)
                  TextFormField(
                    controller: _trxIdController,
                    enabled: !isSubmitting,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-_]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Transaction ID (TrxID)',
                      hintText: 'e.g. BKASH9828X or TRX102934',
                      prefixIcon: const Icon(Icons.receipt_long_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter the transaction reference ID';
                      }
                      if (val.trim().length < 4) {
                        return 'Transaction ID must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Target Cycle
                  TextFormField(
                    controller: _cycleController,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    onTap: isSubmitting ? null : _pickCycle,
                    decoration: InputDecoration(
                      labelText: 'Target Cycle (Year-Month)',
                      hintText: '2026-10',
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                      prefixIcon: const Icon(Icons.calendar_month_outlined, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Target billing cycle is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Optional Receipt Link
                  TextFormField(
                    controller: _receiptController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Receipt / Screenshot Link (Optional)',
                      hintText: 'Paste a link to your payment screenshot',
                      prefixIcon: const Icon(Icons.link_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Optional Notes
                  TextFormField(
                    controller: _notesController,
                    enabled: !isSubmitting,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'Any extra remarks for the admin...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Submit for Verification',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  final DateTime initial;

  const _MonthPickerDialog({required this.initial});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _year--),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '$_year',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _year++),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2,
                children: List.generate(12, (i) {
                  final month = i + 1;
                  final isSelected = _year == widget.initial.year && month == widget.initial.month;
                  final isCurrent = _year == now.year && month == now.month;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent && !isSelected ? const Color(0xFF0F766E) : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        _monthNames[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
