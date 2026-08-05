import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider, Provider;
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/app_providers.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'utils/app_logger.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.e(
      'FlutterFramework',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
      details: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e(
      'UncaughtAsyncError',
      error.toString(),
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  AppLogger.i('AppMain', 'Attendance App starting');
  runApp(
    // ProviderScope wraps the entire tree so Riverpod providers are available everywhere
    const ProviderScope(child: AttendanceApp()),
  );
}

class AttendanceApp extends ConsumerWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadProfile()),
      ],
      child: MaterialApp(
        title: 'Attendance System',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading && !authProvider.isAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      return const LoginScreen();
    }

    final user = authProvider.currentUser!;
    if (user.isAdmin) {
      return const AdminDashboard();
    } else {
      return const TeacherDashboard();
    }
  }
}
