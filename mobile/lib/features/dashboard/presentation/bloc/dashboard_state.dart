import 'package:equatable/equatable.dart';
import '../../data/models/admin_dashboard_model.dart';
import '../../data/models/member_dashboard_model.dart';

abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class MemberDashboardLoaded extends DashboardState {
  final MemberDashboardModel dashboard;

  const MemberDashboardLoaded(this.dashboard);

  @override
  List<Object?> get props => [dashboard];
}

class AdminDashboardLoaded extends DashboardState {
  final AdminDashboardModel data;

  const AdminDashboardLoaded(this.data);

  @override
  List<Object?> get props => [data];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}
