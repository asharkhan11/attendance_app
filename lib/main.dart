import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'utils/app_logger.dart';
import 'utils/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Log Flutter framework errors (UI / Widget tree)
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

  // Log uncaught async platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e(
      'UncaughtAsyncError',
      error.toString(),
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  AppLogger.i('AppMain', 'Attendance App starting in dev mode');
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadProfile()),
      ],
      child: MaterialApp(
        title: 'Attendance System',
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

