import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/providers/theme_provider.dart';
import 'package:snorify_app/core/providers/session_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              // Theme settings
              _buildThemeSettings(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // Data management
              _buildDataManagement(),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // About section
              _buildAboutSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSettings() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appearance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.brightness_6),
              title: const Text('Theme Mode'),
              subtitle: Text(_getThemeModeText(themeProvider.themeMode)),
              onTap: () => _showThemeModeDialog(context, themeProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDataManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Data Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Clear All Data'),
          subtitle: const Text('Delete all sessions and readings'),
          onTap: () => _showClearDataDialog(context),
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Reset Onboarding'),
          subtitle: const Text('Show onboarding screens again'),
          onTap: () => _showResetOnboardingDialog(context),
        ),
      ],
    );
  }
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('App Version'),
          subtitle: Text(AppConstants.appVersion),
        ),
      ],
    );
  }
  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeModeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeModeOption(
              context,
              'System Default',
              Icons.brightness_auto,
              ThemeMode.system,
              themeProvider,
            ),
            _buildThemeModeOption(
              context,
              'Light',
              Icons.brightness_high,
              ThemeMode.light,
              themeProvider,
            ),
            _buildThemeModeOption(
              context,
              'Dark',
              Icons.brightness_4,
              ThemeMode.dark,
              themeProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeModeOption(
    BuildContext context,
    String title,
    IconData icon,
    ThemeMode mode,
    ThemeProvider themeProvider,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: themeProvider.themeMode == mode,
      onTap: () {
        themeProvider.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure you want to delete all sessions and readings? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData(context);
            },
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showResetOnboardingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Onboarding'),
        content: const Text(
          'This will reset the onboarding status. You will see the onboarding screens the next time you restart the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetOnboarding(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData(BuildContext context) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    await sessionProvider.clearAllData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data has been cleared')),
      );
    }
  }  Future<void> _resetOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding has been reset')),
      );
    }
  }
}