import 'package:flutter/material.dart';
import 'package:snorify_app/ui/screens/loading_screen.dart'; // Import untuk AppColors

class BackgroundWaves extends StatelessWidget {
  const BackgroundWaves({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gelombang Atas
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.bluePrimary.withOpacity(0.4),
                  AppColors.bluePrimary.withOpacity(0.25),
                  Colors.white.withOpacity(0.2),
                ],
              ),
            ),
          ),
        ),
        // Gelombang Bawah
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.25,
            decoration: BoxDecoration(              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.blueSecondary.withOpacity(0.4),
                  AppColors.blueSecondary.withOpacity(0.25),
                  Colors.white.withOpacity(0.2),
                ],
              ),
            ),
          ),        ),
      ],
    );
  }
}