import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/api/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';

// Feature Clean Architecture Repositories
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/organization/data/repositories/org_repository.dart';
import 'features/contributions/data/repositories/contribution_repository.dart';
import 'features/dashboard/data/repositories/dashboard_repository.dart';
import 'features/investments/data/repositories/investment_repository.dart';
import 'features/expenses/data/repositories/expense_repository.dart';
import 'features/income/data/repositories/income_repository.dart';
import 'features/notifications/data/repositories/notification_repository.dart';

// Cubits / State
import 'features/auth/presentation/bloc/auth_cubit.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'features/contributions/presentation/bloc/contribution_cubit.dart';

// Screens
import 'features/organization/presentation/screens/select_or_create_org_screen.dart';
import 'screens/auth/login_screen.dart';

/// Global navigator key so the auth listener can clear the nav stack
/// from outside the widget tree (e.g. after logout from a pushed route).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Core Service Dependencies
  final storageService = SecureStorageService();
  final apiClient = ApiClient(storageService: storageService);

  // 2. Feature Clean Architecture Repositories
  final authRepository = AuthRepository(apiClient: apiClient, storageService: storageService);
  final orgRepository = OrgRepository(apiClient: apiClient, storageService: storageService);
  final contributionRepository = ContributionRepository(apiClient: apiClient);
  final dashboardRepository = DashboardRepository(apiClient: apiClient);
  final investmentRepository = InvestmentRepository(apiClient: apiClient);
  final expenseRepository = ExpenseRepository(apiClient: apiClient);
  final incomeRepository = IncomeRepository(apiClient: apiClient);
  final notificationRepository = NotificationRepository(apiClient: apiClient);

  runApp(SongothonApp(
    storageService: storageService,
    authRepository: authRepository,
    orgRepository: orgRepository,
    contributionRepository: contributionRepository,
    dashboardRepository: dashboardRepository,
    investmentRepository: investmentRepository,
    expenseRepository: expenseRepository,
    incomeRepository: incomeRepository,
    notificationRepository: notificationRepository,
  ));
}

class SongothonApp extends StatelessWidget {
  final SecureStorageService storageService;
  final AuthRepository authRepository;
  final OrgRepository orgRepository;
  final ContributionRepository contributionRepository;
  final DashboardRepository dashboardRepository;
  final InvestmentRepository investmentRepository;
  final ExpenseRepository expenseRepository;
  final IncomeRepository incomeRepository;
  final NotificationRepository notificationRepository;

  const SongothonApp({
    super.key,
    required this.storageService,
    required this.authRepository,
    required this.orgRepository,
    required this.contributionRepository,
    required this.dashboardRepository,
    required this.investmentRepository,
    required this.expenseRepository,
    required this.incomeRepository,
    required this.notificationRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<SecureStorageService>.value(value: storageService),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<OrgRepository>.value(value: orgRepository),
        RepositoryProvider<ContributionRepository>.value(value: contributionRepository),
        RepositoryProvider<DashboardRepository>.value(value: dashboardRepository),
        RepositoryProvider<InvestmentRepository>.value(value: investmentRepository),
        RepositoryProvider<ExpenseRepository>.value(value: expenseRepository),
        RepositoryProvider<IncomeRepository>.value(value: incomeRepository),
        RepositoryProvider<NotificationRepository>.value(value: notificationRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>(
            create: (_) => AuthCubit(authRepository: authRepository)..checkAuthStatus(),
          ),
          BlocProvider<DashboardCubit>(
            create: (_) => DashboardCubit(repository: dashboardRepository),
          ),
          BlocProvider<ContributionCubit>(
            create: (_) => ContributionCubit(repository: contributionRepository),
          ),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is Unauthenticated) {
              appNavigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            } else if (state is Authenticated) {
              appNavigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => SelectOrCreateOrgScreen(orgRepository: orgRepository),
                ),
                (route) => false,
              );
            }
          },
          child: MaterialApp(
            title: 'Songothon • সংগঠন',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            navigatorKey: appNavigatorKey,
            home: AuthGate(orgRepository: orgRepository),
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final OrgRepository orgRepository;

  const AuthGate({super.key, required this.orgRepository});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return SelectOrCreateOrgScreen(orgRepository: orgRepository);
        }

        if (state is AuthLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }
}
