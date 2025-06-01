import 'package:flutter/material.dart';
import 'package:snorify_app/ui/screens/loading_screen.dart'; // Import untuk AppColors

class BackgroundWaves extends StatefulWidget {
  const BackgroundWaves({super.key});

  @override
  State<BackgroundWaves> createState() => _BackgroundWavesState();
}

class _BackgroundWavesState extends State<BackgroundWaves> with TickerProviderStateMixin {
  late final AnimationController _topController;
  late final AnimationController _bottomController;
  late final Animation<double> _topAnimation;
  late final Animation<double> _bottomAnimation;

  @override
  void initState() {
    super.initState();
    // Kontroler untuk animasi gelombang atas
    _topController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);
    // Kontroler untuk animasi gelombang bawah
    _bottomController = AnimationController(
      duration: const Duration(seconds: 7),
      vsync: this,
    )..repeat(reverse: true);

    _topAnimation = Tween<double>(begin: 0.2, end: 0.35).animate(
      CurvedAnimation(parent: _topController, curve: Curves.easeInOut),
    );
    _bottomAnimation = Tween<double>(begin: 0.2, end: 0.35).animate(
      CurvedAnimation(parent: _bottomController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gelombang Atas
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _topAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bluePrimary,
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ),
        // Gelombang Bawah
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _bottomAnimation,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.blueSecondary,
                    Colors.white,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}