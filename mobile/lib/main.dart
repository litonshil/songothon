import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/api/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/dashboard_repository.dart';
import 'repositories/investment_repository.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/member/member_dashboard_screen.dart';
import 'state/auth/auth_cubit.dart';
import 'state/auth/auth_state.dart';
import 'state/dashboard/dashboard_cubit.dart';
import 'state/investment/investment_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Core Service Dependencies
  final storageService = SecureStorageService();
  final apiClient = ApiClient(storageService: storageService);

  // Repositories
  final authRepository = AuthRepository(apiClient: apiClient, storageService: storageService);
  final dashboardRepository = DashboardRepository(apiClient: apiClient);
  final investmentRepository = InvestmentRepository(apiClient: apiClient);

  runApp(SongothonApp(
    authRepository: authRepository,
    dashboardRepository: dashboardRepository,
    investmentRepository: investmentRepository,
  ));
}

class SongothonApp extends StatelessWidget {
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final InvestmentRepository investmentRepository;

  const SongothonApp({
    super.key,
    required this.authRepository,
    required this.dashboardRepository,
    required this.investmentRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => AuthCubit(authRepository: authRepository)..checkAuthStatus(),
        ),
        BlocProvider<DashboardCubit>(
          create: (_) => DashboardCubit(dashboardRepository: dashboardRepository),
        ),
        BlocProvider<InvestmentCubit>(
          create: (_) => InvestmentCubit(investmentRepository: investmentRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Songothon Savings & Investment',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          if (state.user.isAdmin) {
            return const AdminDashboardScreen();
          }
          return const MemberDashboardScreen();
        }

        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
