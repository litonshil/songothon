import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/contribution_cubit.dart';
import '../bloc/contribution_state.dart';
import '../../data/models/contribution_model.dart';

class AdminVerificationScreen extends StatefulWidget {
  final String orgSlug;

  const AdminVerificationScreen({super.key, required this.orgSlug});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  void _loadPending() {
    context.read<ContributionCubit>().fetchPendingApprovals(widget.orgSlug);
  }

  void _confirmApprove(ContributionModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Deposit?'),
        content: Text(
          'Confirm payment of ৳ ${item.amount.toStringAsFixed(2)} from ${item.memberName ?? "Member"} (TrxID: ${item.trxId})?\n\nThis will update the organization vault balance and notify the member via push.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ContributionCubit>().approveDeposit(
                    slug: widget.orgSlug,
                    id: item.id,
                  );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(ContributionModel item) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Provide a clear reason for rejecting ${item.memberName ?? "this member"}\'s payment submission:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Transaction ID not found on bKash statement',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(ctx).pop();
              context.read<ContributionCubit>().rejectDeposit(
                    slug: widget.orgSlug,
                    id: item.id,
                    reason: reason,
                  );
            },
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '৳ ', decimalDigits: 2);
    final dateFormatter = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deposit Verification Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPending,
          ),
        ],
      ),
      body: BlocConsumer<ContributionCubit, ContributionState>(
        listener: (context, state) {
          if (state is ContributionActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF0F766E),
              ),
            );
          } else if (state is ContributionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFB71C1C),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ContributionLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is PendingDepositsLoaded) {
            final pending = state.pendingDeposits;
            if (pending.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 72, color: Colors.teal.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'All Caught Up!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'There are no pending deposits waiting for verification in this organization.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => _loadPending(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pending.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final item = pending[i];
                  return Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.memberName ?? 'Member Deposit',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.targetCycle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                currencyFormatter.format(item.amount),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  item.paymentMethod.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Sender AC', item.senderAccount),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('TrxID: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                              Text(
                                item.trxId,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: item.trxId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('TrxID copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildDetailRow('Submitted', dateFormatter.format(item.paidAt)),
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildDetailRow('Notes', item.notes!),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFB71C1C),
                                    side: const BorderSide(color: Color(0xFFB71C1C)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text('Reject'),
                                  onPressed: () => _showRejectDialog(item),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F766E),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Approve'),
                                  onPressed: () => _confirmApprove(item),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          }

          return Center(
            child: ElevatedButton(
              onPressed: _loadPending,
              child: const Text('Load Verification Queue'),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
