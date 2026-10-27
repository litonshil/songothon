import 'package:equatable/equatable.dart';
import '../../data/models/contribution_model.dart';

abstract class ContributionState extends Equatable {
  const ContributionState();

  @override
  List<Object?> get props => [];
}

class ContributionInitial extends ContributionState {}

class ContributionLoading extends ContributionState {}

class ContributionSubmitting extends ContributionState {}

class ContributionSubmittedSuccess extends ContributionState {
  final ContributionModel contribution;
  final String message;

  const ContributionSubmittedSuccess({
    required this.contribution,
    this.message = 'Payment submitted successfully! Waiting for admin review.',
  });

  @override
  List<Object?> get props => [contribution, message];
}

class ContributionHistoryLoaded extends ContributionState {
  final List<ContributionModel> history;

  const ContributionHistoryLoaded(this.history);

  @override
  List<Object?> get props => [history];
}

class PendingDepositsLoaded extends ContributionState {
  final List<ContributionModel> pendingDeposits;

  const PendingDepositsLoaded(this.pendingDeposits);

  @override
  List<Object?> get props => [pendingDeposits];
}

class ContributionActionSuccess extends ContributionState {
  final String message;

  const ContributionActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ContributionError extends ContributionState {
  final String message;

  const ContributionError(this.message);

  @override
  List<Object?> get props => [message];
}
