import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/investment_repository.dart';
import 'investment_state.dart';

class InvestmentCubit extends Cubit<InvestmentState> {
  final InvestmentRepository investmentRepository;

  InvestmentCubit({required this.investmentRepository}) : super(InvestmentInitial());

  Future<void> loadInvestments() async {
    emit(InvestmentLoading());
    try {
      final list = await investmentRepository.getInvestments();
      emit(InvestmentLoaded(list));
    } catch (e) {
      emit(InvestmentError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<bool> createInvestment({
    required String title,
    required double amount,
    required String duration,
    String? notes,
  }) async {
    try {
      await investmentRepository.createInvestment(
        title: title,
        amount: amount,
        duration: duration,
        notes: notes,
      );
      await loadInvestments();
      return true;
    } catch (_) {
      return false;
    }
  }
}
