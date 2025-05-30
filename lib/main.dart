import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/core/providers/theme_provider.dart';
import 'package:snorify_app/ui/screens/home_screen.dart';
import 'package:snorify_app/ui/screens/onboarding_screen.dart';
import 'package:snorify_app/ui/screens/session_detail_screen.dart';
import 'package:snorify_app/ui/screens/dashboard_screen.dart';
import 'package:snorify_app/ui/screens/statistics_screen.dart';
import 'package:snorify_app/ui/screens/settings_screen.dart';
import 'package:snorify_app/ui/screens/add_session_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if onboarding is completed
  final prefs = await SharedPreferences.getInstance();
  final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  
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
    child: MyApp(onboardingCompleted: onboardingCompleted),
  ));
}

class MyApp extends StatelessWidget {
  final bool onboardingCompleted;
  
  const MyApp({super.key, required this.onboardingCompleted});

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
          initialRoute: onboardingCompleted ? AppConstants.routeHome : AppConstants.routeOnboarding,
          routes: {
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
