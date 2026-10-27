import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository repository;

  DashboardCubit({required this.repository}) : super(DashboardInitial());

  Future<void> fetchMemberDashboard(String slug) async {
    emit(DashboardLoading());
    try {
      final data = await repository.getMemberDashboard(slug);
      emit(MemberDashboardLoaded(data));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }

  Future<void> fetchAdminDashboard(String slug) async {
    emit(DashboardLoading());
    try {
      final data = await repository.getAdminDashboard(slug);
      emit(AdminDashboardLoaded(data));
    } catch (e) {
      emit(DashboardError(e.toString()));
    }
  }
}
