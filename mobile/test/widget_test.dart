import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:songothon_mobile/core/api/api_client.dart';
import 'package:songothon_mobile/core/storage/secure_storage_service.dart';
import 'package:songothon_mobile/repositories/auth_repository.dart';
import 'package:songothon_mobile/state/auth/auth_cubit.dart';
import 'package:songothon_mobile/screens/auth/login_screen.dart';

void main() {
  testWidgets('Renders Login Screen with branding and fields', (WidgetTester tester) async {
    final storage = SecureStorageService();
    final client = ApiClient(storageService: storage);
    final authRepo = AuthRepository(apiClient: client, storageService: storage);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => AuthCubit(authRepository: authRepo),
          child: const LoginScreen(),
        ),
      ),
    );

    expect(find.text('SONGOTHON'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
