import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/ui/screens/dashboard_screen.dart';
import 'package:snorify_app/ui/screens/add_session_screen.dart';
import 'package:snorify_app/ui/screens/statistics_screen.dart';
import 'package:snorify_app/ui/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // List of screens to navigate between
  final List<Widget> _screens = [
    const DashboardScreen(),
    const AddSessionScreen(),
    const StatisticsScreen(),
    const SettingsScreen(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appName),
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Session',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}