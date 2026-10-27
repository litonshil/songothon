import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/contribution_repository.dart';
import 'contribution_state.dart';

class ContributionCubit extends Cubit<ContributionState> {
  final ContributionRepository repository;

  ContributionCubit({required this.repository}) : super(ContributionInitial());

  Future<void> submitPayment({
    required String slug,
    required String type,
    required double amount,
    required String paymentMethod,
    required String trxId,
    required String senderAccount,
    required String targetCycle,
    String? receiptUrl,
    String? notes,
  }) async {
    emit(ContributionSubmitting());
    try {
      final contribution = await repository.submitDeposit(
        slug: slug,
        type: type,
        amount: amount,
        paymentMethod: paymentMethod,
        trxId: trxId,
        senderAccount: senderAccount,
        targetCycle: targetCycle,
        receiptUrl: receiptUrl,
        notes: notes,
      );
      emit(ContributionSubmittedSuccess(contribution: contribution));
    } catch (e) {
      emit(ContributionError(e.toString()));
    }
  }

  Future<void> fetchMyHistory(String slug) async {
    emit(ContributionLoading());
    try {
      final history = await repository.getMyHistory(slug);
      emit(ContributionHistoryLoaded(history));
    } catch (e) {
      emit(ContributionError(e.toString()));
    }
  }

  Future<void> fetchPendingApprovals(String slug) async {
    emit(ContributionLoading());
    try {
      final pending = await repository.getPendingDeposits(slug);
      emit(PendingDepositsLoaded(pending));
    } catch (e) {
      emit(ContributionError(e.toString()));
    }
  }

  Future<void> approveDeposit({required String slug, required String id}) async {
    try {
      await repository.approveDeposit(slug: slug, id: id);
      emit(const ContributionActionSuccess('Deposit successfully approved!'));
      await fetchPendingApprovals(slug);
    } catch (e) {
      emit(ContributionError(e.toString()));
    }
  }

  Future<void> rejectDeposit({
    required String slug,
    required String id,
    required String reason,
  }) async {
    try {
      await repository.rejectDeposit(slug: slug, id: id, reason: reason);
      emit(const ContributionActionSuccess('Deposit rejected with reason noted.'));
      await fetchPendingApprovals(slug);
    } catch (e) {
      emit(ContributionError(e.toString()));
    }
  }
}
