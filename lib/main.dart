import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/core/providers/theme_provider.dart';
import 'package:snorify_app/ui/screens/home_screen.dart';
import 'package:snorify_app/ui/screens/onboarding_screen.dart';
import 'package:snorify_app/ui/screens/loading_screen.dart';
import 'package:snorify_app/ui/screens/session_detail_screen.dart';
import 'package:snorify_app/ui/screens/dashboard_screen.dart';
import 'package:snorify_app/ui/screens/statistics_screen.dart';
import 'package:snorify_app/ui/screens/add_session_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SessionProvider()),
      ChangeNotifierProxyProvider<SessionProvider, BleProvider>(
        create: (_) => BleProvider(),
        update: (_, sessionProvider, bleProvider) {
          bleProvider?.initializeWithSessionProvider(sessionProvider);
          return bleProvider!;
        },
      ),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,
          theme: themeProvider.getLightTheme(),
          darkTheme: themeProvider.getDarkTheme(),
          themeMode: themeProvider.themeMode,
          initialRoute: AppConstants.routeLoading,
          routes: {
            AppConstants.routeLoading: (context) => const LoadingScreen(),
            AppConstants.routeOnboarding: (context) => const OnboardingScreen(),
            AppConstants.routeHome: (context) => const HomeScreen(),
            AppConstants.routeAddSession: (context) => const AddSessionScreen(),
            AppConstants.routeDashboard: (context) => const DashboardScreen(),
            AppConstants.routeStatistics: (context) => const StatisticsScreen(),
            '/session-detail': (context) => SessionDetailScreen(
              sessionId: ModalRoute.of(context)!.settings.arguments as int,
            ),
          },
        );
      },
    );
  }
}
