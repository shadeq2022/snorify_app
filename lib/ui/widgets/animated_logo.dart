import 'dart:ui'; // Diperlukan untuk PathMetric dan extractPath
import 'package:flutter/material.dart';
import 'package:snorify_app/ui/screens/loading_screen.dart'; // Import untuk AppColors

// Widget stateful untuk mengelola "state" atau keadaan dari animasi
class AnimatedLogo extends StatefulWidget {
  final double size;
  const AnimatedLogo({super.key, required this.size});

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _line1Animation;
  late Animation<double> _line2Animation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // 1. Membuat AnimationController dengan posisi awal 0.0
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // PENTING: Reset controller ke posisi 0 untuk memastikan animasi dimulai dari awal
    _controller.reset();

    // 2. Membuat animasi spesifik untuk GARIS PERTAMA (hijau)
    _line1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );    // 3. Membuat animasi spesifik untuk GARIS KEDUA (oranye)
    // Animasi dimulai lebih cepat di 15% dan selesai di 100% durasi total
    _line2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.07, 1.0, curve: Curves.easeOut),
      ),
    );

    // 4. Pastikan animasi dimulai dari awal dengan delay kecil
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.reset();
        _controller.forward();
      }
    });  }

  @override
  void didUpdateWidget(AnimatedLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset animasi jika widget di-update
    if (mounted) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedBuilder secara efisien membangun ulang widget setiap kali nilai animasi berubah
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // CustomPaint adalah widget yang memungkinkan kita menggambar secara manual di canvas
        return CustomPaint(
          size: Size(widget.size, widget.size),
          // Kita memberikan nilai progress animasi saat ini ke painter
          painter: LogoPainter(
            line1Progress: _line1Animation.value, // Nilai dari 0.0 hingga 1.0
            line2Progress: _line2Animation.value, // Nilai dari 0.0 hingga 1.0
          ),
        );
      },
    );
  }
}

// Custom Painter untuk menggambar logo
class LogoPainter extends CustomPainter {
  final double line1Progress; // Menyimpan progress garis 1
  final double line2Progress; // Menyimpan progress garis 2

  LogoPainter({required this.line1Progress, required this.line2Progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Inisialisasi kuas gambar
    final paint1 = Paint()
      ..color = AppColors.greenLogo
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final paint2 = Paint()
      ..color = AppColors.orangeLogo
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Mendefinisikan bentuk path (jalur) garis
    final path1 = Path()
      ..moveTo(size.width * 0.15, size.height * 0.70)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.85, size.width * 0.35, size.height * 0.60)
      ..quadraticBezierTo(size.width * 0.45, size.height * 0.35, size.width * 0.55, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.65, size.height * 0.75, size.width * 0.75, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.15, size.width * 0.85, size.height * 0.35);

    final path2 = Path()
      ..moveTo(size.width * 0.18, size.height * 0.75)
      ..quadraticBezierTo(size.width * 0.28, size.height * 0.90, size.width * 0.38, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.40, size.width * 0.58, size.height * 0.60)
      ..quadraticBezierTo(size.width * 0.68, size.height * 0.80, size.width * 0.78, size.height * 0.50)
      ..quadraticBezierTo(size.width * 0.88, size.height * 0.20, size.width * 0.88, size.height * 0.40);
      
    // ===================================================================
    // == INI ADALAH BAGIAN UTAMA UNTUK MENGGAMBAR ANIMASI GARIS ==
    // ===================================================================
    _drawAnimatedPath(canvas, path1, paint1, line1Progress);
    _drawAnimatedPath(canvas, path2, paint2, line2Progress);
  }
  
  /// Fungsi helper untuk menggambar sebagian dari path
  void _drawAnimatedPath(Canvas canvas, Path path, Paint paint, double progress) {
    // 1. Hitung metrik (seperti panjang total) dari path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      // 2. Buat path baru dengan mengambil sebagian dari path asli,
      //    mulai dari titik 0.0 hingga ke panjang yang ditentukan oleh 'progress'.
      //    Contoh: jika progress = 0.5, maka kita ambil 50% dari panjang total garis.
      final extractPath = metric.extractPath(0.0, metric.length * progress);
      
      // 3. Gambar path yang sudah dipotong tersebut ke canvas
      canvas.drawPath(extractPath, paint);
    }
  }

  // Memberi tahu Flutter untuk menggambar ulang hanya jika nilai progress berubah
  @override
  bool shouldRepaint(covariant LogoPainter oldDelegate) {
    return line1Progress != oldDelegate.line1Progress || line2Progress != oldDelegate.line2Progress;
  }
}