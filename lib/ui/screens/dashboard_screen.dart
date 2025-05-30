import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/providers/session_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, _) {
        final sessions = sessionProvider.sessions;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCards(sessionProvider),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Sessions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        sessions.isEmpty
                            ? Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/images/no_data1.png',
                                      width: 150,
                                      height: 150,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No sessions yet',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Create your first session to get started!',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            : Scrollbar(
                              thumbVisibility: true,
                              radius: const Radius.circular(8),
                              thickness: 6,
                              child: ListView.builder(
                                padding: const EdgeInsets.only(top: 8),
                                itemCount: sessions.length,
                                itemBuilder: (context, index) {
                                  // Removed the Container with white background and shadow
                                  return _buildSessionCard(
                                    sessions[index],
                                    context,
                                    sessionProvider,
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(SessionProvider sessionProvider) {
  return Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF80D0FF), Color(0xFF007AFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.blueAccent.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        // Circle background with moon icon
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
          ),
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.nightlight_round,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        // Text content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Total Sessions',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              sessionProvider.totalSessions.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}


  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    Sesi sesi,
    BuildContext context,
    SessionProvider sessionProvider,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color:
          isDarkMode
              ? Colors.grey[900]
              : Colors.white, // Background disesuaikan
      elevation: isDarkMode ? 0 : 2, // Hilangkan shadow putih di dark mode
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          await sessionProvider.loadSessionById(sesi.id!);
          if (context.mounted) {
            Navigator.pushNamed(
              context,
              AppConstants.routeSessionDetail,
              arguments: sesi.id,
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    sesi.nama,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(sesi.tanggal, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${sesi.waktuMulai} - ${sesi.waktuSelesai ?? "In Progress"}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.timelapse, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    sesi.durasi != null
                        ? '${sesi.durasi} minutes'
                        : 'Duration not available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              if (sesi.catatan != null && sesi.catatan!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Note: ${sesi.catatan}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
