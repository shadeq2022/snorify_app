import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/ui/widgets/animated_logo.dart';
import 'package:snorify_app/ui/widgets/background_waves.dart';

// Mendefinisikan warna dari variabel CSS
class AppColors {
  static const Color textDark = Color(0xFF2D3748);
  static const Color textMedium = Color(0xFF718096);
  static const Color bluePrimary = Color(0xFF64B5F6);
  static const Color blueSecondary = Color(0xFF3E92CC);
  static const Color blueLight = Color(0xFFA9D9F9);
  static const Color orangeLogo = Color(0xFFFFA500);
  static const Color greenLogo = Color(0xFF4CAF50);
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Pastikan UI sudah siap sebelum memulai navigasi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _isInitialized = true;
      });
      _navigateToNextScreen();
    });
  }
  _navigateToNextScreen() async {
    try {
      // Tunggu lebih lama untuk memastikan animasi logo selesai
      // 4 detik untuk memberikan waktu animasi 3 detik + buffer 1 detik
      await Future.delayed(const Duration(milliseconds: 4500));
      
      // Check if onboarding is completed
      final prefs = await SharedPreferences.getInstance();
      final bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      if (mounted) {
        if (onboardingCompleted) {
          // Navigate to home screen
          Navigator.pushReplacementNamed(context, AppConstants.routeHome);
        } else {
          // Navigate to onboarding screen
          Navigator.pushReplacementNamed(context, AppConstants.routeOnboarding);
        }
      }
    } catch (e) {
      // Fallback jika ada error
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeOnboarding);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isInitialized ? Stack(
        children: [
          // 1. Latar belakang dengan gelombang animasi
          const BackgroundWaves(),

          // 2. Konten utama di tengah
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,              children: [
                // Logo SVG Animasi dengan key unik untuk memastikan widget dibuat ulang
                AnimatedLogo(
                  key: ValueKey(DateTime.now().millisecondsSinceEpoch),
                  size: 160,
                ),

                const SizedBox(height: 24),

                // Judul Aplikasi
                Text(
                  'Snorify',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),

                const SizedBox(height: 16),
                // Tagline Aplikasi
                Text(
                  'Memantau kualitas tidur Anda...',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ) : Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}