import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/distributor/distributor_home.dart';
import 'screens/dispatch/dispatch_home.dart';
import 'screens/owner/owner_dashboard.dart';
import 'screens/production/production_home.dart';
import 'screens/rawmaterial/rm_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const PolytechApp());
}

class PolytechApp extends StatelessWidget {
  const PolytechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swami Polytech ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: {'/login': (_) => const LoginScreen()},
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  Widget _homeForRole(User user) {
    switch (user.role) {
      case UserRole.owner:
        return const OwnerDashboard();
      case UserRole.dispatch:
        return const DispatchHome();
      case UserRole.supervisor:
        return const ProductionHome();
      case UserRole.operator:
        return const RMHome();
      case UserRole.distributor:
        return DistributorHome(user: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String?, User?)>(
      future: Future.wait([
        ApiService.getToken(),
        ApiService.getSavedUser(),
      ]).then((values) => (values[0] as String?, values[1] as User?)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final (token, user) = snapshot.data!;
        if (token == null || user == null) return const LoginScreen();
        return _homeForRole(user);
      },
    );
  }
}
