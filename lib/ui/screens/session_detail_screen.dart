import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';
import 'package:screenshot/screenshot.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isStabilizing = false;
  int _stabilizationCountdown = 20;
  bool _isSharing = false; // Loading state for share functionality
  //Create an instance of ScreenshotController
  ScreenshotController screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();

    // Load session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionProvider>(
        context,
        listen: false,
      ).loadSessionById(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<SessionProvider>(
      builder: (context, sessionProvider, _) {
        final session = sessionProvider.currentSession;
        final readings = sessionProvider.currentReadings;

        if (session == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Hitung waktu awal sesi
        final sessionStart = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).parse('${session.tanggal} ${session.waktuMulai}');

        // Hitung statistik SPO2 dan snoring (exclude stabilization data and invalid SpO2 < 70)
        final filteredReadings =
            readings.where((r) => r.stabilizing != 1 && r.spo2 >= 70).toList();
        final spo2Values = filteredReadings.map((r) => r.spo2).toList();
        final avgSpO2 =
            spo2Values.isNotEmpty
                ? spo2Values.reduce((a, b) => a + b) / spo2Values.length
                : 0.0;
        final minSpO2 =
            spo2Values.isNotEmpty
                ? spo2Values.reduce((a, b) => a < b ? a : b)
                : 0.0;
        int dropCount = 0;
        for (int i = 1; i < spo2Values.length; i++) {
          if (spo2Values[i - 1] - spo2Values[i] >= 3) dropCount++;
        }
        final snoreCount =
            filteredReadings
                .where((r) => r.status == AppConstants.statusSnore)
                .length;

        // Check for current stabilization
        final isCurrentlyStabilizing =
            readings.isNotEmpty && readings.last.stabilizing == 1;
        // Check for stabilization start (when we detect stabilizing = 1 and we weren't already stabilizing)
        if (isCurrentlyStabilizing && !_isStabilizing) {
          _isStabilizing = true;
          _stabilizationCountdown = 20;

          // Start countdown timer
          _startStabilizationCountdown();
        } else if (!isCurrentlyStabilizing && _isStabilizing) {
          // Stabilization ended
          _isStabilizing = false;
        }

        return Scaffold(
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isDark
                          ? [Colors.grey[900]!, Colors.black87]
                          : [Colors.blue.shade300, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            centerTitle: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  session.nama,
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'Tanggal: ${session.tanggal}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  session.waktuSelesai == null
                      ? Icons.stop_circle_outlined
                      : Icons.delete,
                ),
                tooltip:
                    session.waktuSelesai == null
                        ? 'End Session'
                        : 'Delete Session',
                onPressed: () {
                  if (session.waktuSelesai == null) {
                    _endSession(context, session);
                  } else {
                    _showDeleteConfirmationDialog(context, session.id!);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditSessionDialog(context, session),
              ),
            ],
          ),
          body:
              readings.isEmpty
                  ? const Center(
                    child: Text('No data available for this session'),
                  )
                  : Stack(
                    children: [
                      SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors:
                                        isDark
                                            ? [
                                              Colors.grey.shade800,
                                              Colors.grey.shade900,
                                            ]
                                            : [
                                              Colors.blue.shade50,
                                              Colors.blue.shade100,
                                            ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.access_time,
                                              size: 16,
                                              color:
                                                  isDark
                                                      ? Colors.white70
                                                      : Colors.grey[700],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${session.waktuMulai} - ${session.waktuSelesai ?? "Now"}',
                                            ),
                                          ],
                                        ),                                        IconButton(
                                          onPressed: _isSharing 
                                              ? null
                                              : () => _shareSessionReport(
                                                context,
                                                session,
                                                readings,
                                              ),
                                          icon: _isSharing
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.share,
                                                  size: 20,
                                                ),
                                          tooltip: _isSharing ? 'Generating report...' : 'Share',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.timelapse,
                                          size: 16,
                                          color:
                                              isDark
                                                  ? Colors.white70
                                                  : Colors.grey[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          session.durasi != null
                                              ? '${session.durasi} min'
                                              : '-',
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Wrap(
                                      spacing: 18,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        Column(
                                          children: [
                                            const Text(
                                              "Avg SpO₂",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${avgSpO2.toStringAsFixed(1)}%',
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              "Min SpO₂",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${minSpO2.toStringAsFixed(1)}%',
                                            ),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              "Drops ≥3%",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text('$dropCount'),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text(
                                              "Snore",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text('$snoreCount'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildCharts(readings, sessionStart),
                            ],
                          ),
                        ),
                      ),
                      _buildStabilizationOverlay(),
                    ],
                  ),
        );
      },
    );
  }

  // WIDGET BUILDER UNTUK TAMPILAN DI UI APLIKASI
  Widget _buildCharts(List<SensorReading> readings, DateTime sessionStartTime) {
    final referenceTimestamp =
        readings.isNotEmpty ? readings.first.timestamp : 0;

    final validSnoreReadings =
        readings.where((r) => r.stabilizing != 1).toList();

    final validSpo2Readings =
        readings
            .where((r) => r.stabilizing != 1 && r.spo2 >= 70 && r.spo2 <= 100)
            .toList();

    final List<FlSpot> spo2Spots =
        validSpo2Readings.map((r) {
          final time = sessionStartTime.add(
            Duration(seconds: r.timestamp - referenceTimestamp),
          );
          return FlSpot(
            time.millisecondsSinceEpoch.toDouble(),
            r.spo2.toDouble(),
          );
        }).toList();

    final List<FlSpot> snoreSpots =
        validSnoreReadings.map((r) {
          final time = sessionStartTime.add(
            Duration(seconds: r.timestamp - referenceTimestamp),
          );
          return FlSpot(
            time.millisecondsSinceEpoch.toDouble(),
            r.status == 1 ? 1.0 : 0.0,
          );
        }).toList();

    FlTitlesData buildTitles(bool isSnore) => FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 10 * 60 * 1000,
          getTitlesWidget: (value, meta) {
            final label = DateFormat.Hm().format(
              DateTime.fromMillisecondsSinceEpoch(value.toInt()),
            );
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Transform.translate(
                offset: const Offset(-8, 0),
                child: Text(label),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget:
              (value, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  isSnore ? (value == 1.0 ? 'Yes' : 'No') : '${value.toInt()}',
                ),
              ),
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    LineTouchData buildTouchData(Color color, bool isSnore) => LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: color.withOpacity(0.9),
        getTooltipItems:
            (touchedSpots) =>
                touchedSpots.map((spot) {
                  final time = DateFormat.Hm().format(
                    DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()),
                  );
                  final value =
                      isSnore
                          ? (spot.y == 1.0 ? 'Snoring' : 'No Snore')
                          : '${spot.y.toStringAsFixed(1)}%';
                  return LineTooltipItem(
                    '$value\n$time',
                    const TextStyle(color: Colors.white),
                  );
                }).toList(),
      ),
    );

    Widget buildChart(
      List<FlSpot> spots,
      double minY,
      double maxY,
      Color color,
      bool isSnore,
    ) {
      double? chartMinX, chartMaxX;

      if (!isSnore && snoreSpots.isNotEmpty) {
        chartMinX = snoreSpots.first.x;
        chartMaxX = snoreSpots.last.x;
      } else if (spots.isNotEmpty) {
        chartMinX = spots.first.x;
        chartMaxX = spots.last.x;
      }

      return LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: chartMinX,
          maxX: chartMaxX,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
          ],
          lineTouchData: buildTouchData(color, isSnore),
          titlesData: buildTitles(isSnore),
          gridData: FlGridData(show: true),
          extraLinesData:
              !isSnore
                  ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 95,
                        color: Colors.red,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          labelResolver: (_) => '95%',
                          alignment: Alignment.topLeft,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  )
                  : ExtraLinesData(),
        ),
      );
    }

    // ## PERUBAHAN ##
    // Header dipisahkan dari Screenshot widget agar tidak ikut tercapture
    return Column(
      children: [
        // SpO2 Chart Header with Info Icon (SEKARANG DI LUAR SCREENSHOT)
        Row(
          children: [
            const Expanded(flex: 3, child: SizedBox()), // Left spacer
            const Text('SpO₂', style: TextStyle(fontWeight: FontWeight.bold)),
            const Expanded(flex: 2, child: SizedBox()), // Center spacer
            IconButton(
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showSpO2DistributionPopup(context, readings),
              tooltip: 'SpO2 Distribution',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        // Screenshot widget tidak lagi digunakan di sini karena kita capture secara off-screen
        // Kita langsung tampilkan saja grafiknya
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: buildChart(spo2Spots, 70, 100, Colors.green, false),
              ),
              const SizedBox(height: 28),
              const Text(
                'Snoring',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 100,
                child: buildChart(snoreSpots, 0, 1, Colors.orange, true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ## FUNGSI BARU ##
  // WIDGET BUILDER KHUSUS UNTUK MEMBUAT GAMBAR GRAFIK UNTUK PDF
  Widget _buildChartsForPdf(
    List<SensorReading> readings,
    DateTime sessionStartTime,
  ) {
    // Fungsi ini membuat versi "bersih" dari grafik untuk dirender menjadi gambar.
    final referenceTimestamp =
        readings.isNotEmpty ? readings.first.timestamp : 0;

    final validSnoreReadings =
        readings.where((r) => r.stabilizing != 1).toList();

    final validSpo2Readings =
        readings
            .where((r) => r.stabilizing != 1 && r.spo2 >= 70 && r.spo2 <= 100)
            .toList();

    final List<FlSpot> spo2Spots =
        validSpo2Readings.map((r) {
          final time = sessionStartTime.add(
            Duration(seconds: r.timestamp - referenceTimestamp),
          );
          return FlSpot(
            time.millisecondsSinceEpoch.toDouble(),
            r.spo2.toDouble(),
          );
        }).toList();

    final List<FlSpot> snoreSpots =
        validSnoreReadings.map((r) {
          final time = sessionStartTime.add(
            Duration(seconds: r.timestamp - referenceTimestamp),
          );
          return FlSpot(
            time.millisecondsSinceEpoch.toDouble(),
            r.status == 1 ? 1.0 : 0.0,
          );
        }).toList();

    FlTitlesData buildTitles(bool isSnore) => FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 10 * 60 * 1000,
          getTitlesWidget: (value, meta) {
            final label = DateFormat.Hm().format(
              DateTime.fromMillisecondsSinceEpoch(value.toInt()),
            );
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(
                label,
                style: const TextStyle(color: Colors.black, fontSize: 14),
              ),
            ); // UBAH FONT
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget:
              (value, _) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  isSnore ? (value == 1.0 ? 'Yes' : 'No') : '${value.toInt()}',
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ), // UBAH FONT
              ),
        ),
      ),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    LineTouchData buildTouchData(Color color, bool isSnore) =>
        LineTouchData(enabled: false);

    Widget buildChart(
      List<FlSpot> spots,
      double minY,
      double maxY,
      Color color,
      bool isSnore,
    ) {
      double? chartMinX, chartMaxX;

      if (!isSnore && snoreSpots.isNotEmpty) {
        chartMinX = snoreSpots.first.x;
        chartMaxX = snoreSpots.last.x;
      } else if (spots.isNotEmpty) {
        chartMinX = spots.first.x;
        chartMaxX = spots.last.x;
      }

      return LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: chartMinX,
          maxX: chartMaxX,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: false),
            ),
          ],
          lineTouchData: buildTouchData(color, isSnore),
          titlesData: buildTitles(isSnore),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine:
                (value) =>
                    const FlLine(color: Colors.black26, strokeWidth: 0.5),
            getDrawingVerticalLine:
                (value) =>
                    const FlLine(color: Colors.black26, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black, width: 1),
          ),
          extraLinesData:
              !isSnore
                  ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: 95,
                        color: Colors.red,
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          labelResolver: (_) => '95%',
                          alignment: Alignment.topLeft,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ), // UBAH FONT
                        ),
                      ),
                    ],
                  )
                  : ExtraLinesData(),
        ),
      );
    }

    // Widget yang akan di-render untuk PDF
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // UBAH FONT JUDUL
          const Text(
            'SpO₂',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 22,
            ),
          ),
          SizedBox(
            height: 250,
            child: buildChart(spo2Spots, 70, 100, Colors.green, false),
          ),
          const SizedBox(height: 30),
          // UBAH FONT JUDUL
          const Text(
            'Snoring',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontSize: 22,
            ),
          ),
          SizedBox(
            height: 150,
            child: buildChart(snoreSpots, 0, 1, Colors.orange, true),
          ),
        ],
      ),
    );
  }

  void _startStabilizationCountdown() {
    if (!mounted) return;

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isStabilizing) {
        timer.cancel();
        return;
      }

      setState(() {
        _stabilizationCountdown--;
      });

      if (_stabilizationCountdown <= 0) {
        timer.cancel();
      }
    });
  }

  Widget _buildStabilizationOverlay() {
    if (!_isStabilizing) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sensors, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Sensor Stabilizing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please keep your finger steady',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  CircularProgressIndicator(
                    value: (20 - _stabilizationCountdown) / 20,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_stabilizationCountdown}s',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSessionDialog(BuildContext context, Sesi session) {
    final nameController = TextEditingController(text: session.nama);
    final notesController = TextEditingController(text: session.catatan);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Session'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Session Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _updateSession(
                    context,
                    session,
                    nameController.text,
                    notesController.text,
                  );
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _updateSession(
    BuildContext context,
    Sesi session,
    String name,
    String? notes,
  ) async {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );

    final updatedSession = session.copyWith(
      nama: name,
      catatan: notes?.isNotEmpty == true ? notes : null,
    );

    await sessionProvider.updateSession(updatedSession);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session updated successfully')),
      );
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context, int sessionId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Session'),
            content: const Text(
              'Are you sure you want to delete this session? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteSession(context, sessionId);
                },
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  void _deleteSession(BuildContext context, int sessionId) async {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );

    await sessionProvider.deleteSession(sessionId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session deleted successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _endSession(BuildContext context, Sesi session) async {
    final sessionProvider = Provider.of<SessionProvider>(
      context,
      listen: false,
    );
    final bleProvider = Provider.of<BleProvider>(context, listen: false);

    // Get current time
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm:ss');
    final endTime = timeFormat.format(now);

    // Calculate duration in minutes
    final startTime = DateFormat('HH:mm:ss').parse(session.waktuMulai);
    final endTimeObj = DateFormat('HH:mm:ss').parse(endTime);
    final difference = endTimeObj.difference(startTime);
    final durationMinutes = difference.inMinutes;

    // Update session
    final updatedSession = session.copyWith(
      waktuSelesai: endTime,
      durasi: durationMinutes,
    );

    await sessionProvider.updateSession(updatedSession);

    // Disconnect from device
    bleProvider.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session ended successfully')),
      );
    }
  }
  // ## FUNGSI DIPERBARUI ##
  // FUNGSI SHARE DENGAN METODE CAPTURE OFF-SCREEN
  Future<void> _shareSessionReport(
  BuildContext context,
  Sesi session,
  List<SensorReading> readings,
) async {
  // Set loading state
  setState(() {
    _isSharing = true;
  });

  try {
    final pdf = pw.Document();

    // 1. Ambil data yang valid
    final allValidReadings = readings
        .where((r) => r.stabilizing != 1 && r.spo2 >= 70)
        .toList();

    if (allValidReadings.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid data to generate report.')),
        );
      }
      return;
    }

  // 2. Capture gambar grafik
  final chartWidgetForPdf = _buildChartsForPdf(readings, DateFormat('yyyy-MM-dd HH:mm:ss').parse('${session.tanggal} ${session.waktuMulai}'));
  final imageBytes = await screenshotController.captureFromWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(1200, 600)),
      child: MaterialApp(
        home: Scaffold(backgroundColor: Colors.white, body: chartWidgetForPdf),
        theme: ThemeData.light(),
        debugShowCheckedModeBanner: false,
      ),
    ),
    targetSize: const Size(1200, 600),
    pixelRatio: 1.5,
  );

  if (imageBytes == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture chart image for PDF.')),
      );
    }
    return;
  }
  final image = pw.MemoryImage(imageBytes);

  // 3. Kalkulasi statistik
  final spo2Values = allValidReadings.map((r) => r.spo2).toList();
  final avgSpO2 = spo2Values.reduce((a, b) => a + b) / spo2Values.length;
  final minSpO2 = spo2Values.reduce((a, b) => a < b ? a : b);
  int dropCount = 0;
  for (int i = 1; i < spo2Values.length; i++) {
    if (spo2Values[i - 1] - spo2Values[i] >= 3) dropCount++;
  }
  final snoreCount =
      allValidReadings.where((r) => r.status == AppConstants.statusSnore).length;

  // 4. Kalkulasi Tabel Distribusi SpO₂
  Map<String, double> spo2Distribution = {
    '100% - 94%': 0, '93% - 88%': 0, '87% - 80%': 0, '79% - 70%': 0,
  };
  final totalDuration = allValidReadings.length;
  for (var reading in allValidReadings) {
    if (reading.spo2 >= 94) spo2Distribution['100% - 94%'] = (spo2Distribution['100% - 94%'] ?? 0) + 1;
    else if (reading.spo2 >= 88) spo2Distribution['93% - 88%'] = (spo2Distribution['93% - 88%'] ?? 0) + 1;
    else if (reading.spo2 >= 80) spo2Distribution['87% - 80%'] = (spo2Distribution['87% - 80%'] ?? 0) + 1;
    else spo2Distribution['79% - 70%'] = (spo2Distribution['79% - 70%'] ?? 0) + 1;
  }

  // 5. Bangun halaman PDF dengan layout yang benar
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ================== BAGIAN ATAS (HEADER & SUMMARY) ==================
            // ## PERBAIKAN: Gunakan pw.Row, bukan pw.Partition ##
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- KOLOM KIRI (INFO & SUMMARY) ---
                pw.Container(
                  width: 350, // Lebar kolom kiri
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Session Report: ${session.nama}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 8),
                      pw.Text('Date: ${session.tanggal}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Time: ${session.waktuMulai} - ${session.waktuSelesai ?? "Ongoing"}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Duration: ${session.durasi ?? "-"} min', style: const pw.TextStyle(fontSize: 10)),
                      if (session.catatan != null && session.catatan!.isNotEmpty)
                        pw.Text('Notes: ${session.catatan}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Divider(height: 15),
                      pw.Text('Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text('Avg SpO₂: ${avgSpO2.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Min SpO₂: ${minSpO2.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Drops ≥3%: $dropCount', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Snore Count: $snoreCount', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                // --- KOLOM KANAN (TABEL DISTRIBUSI) ---
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('SpO₂ Distribution', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Table.fromTextArray(
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                        cellAlignment: pw.Alignment.centerRight,
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2.5), 1: const pw.FlexColumnWidth(1.5), 2: const pw.FlexColumnWidth(1.5),
                        },
                        data: <List<String>>[
                          <String>['SpO₂ Range', 'Time (min)', '% Time'],
                          ...spo2Distribution.entries.map((entry) {
                            final minutes = (entry.value / 60).toStringAsFixed(1);
                            final percentage = totalDuration > 0
                                ? (entry.value / totalDuration * 100).toStringAsFixed(1)
                                : '0.0';
                            return [entry.key, '$minutes', '$percentage %'];
                          }).toList(),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),

            pw.Divider(height: 10),

            // ================== BAGIAN BAWAH (GRAFIK) ==================
            pw.Text('Charts:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 1),
            
            pw.Expanded(
              child: pw.Image(image, fit: pw.BoxFit.fitWidth),
            )
          ],
        );
      },
    ),
  );
  // 6. Simpan dan share file
  final output = await getTemporaryDirectory();
  final file = File("${output.path}/session_report_${session.id}.pdf");
  await file.writeAsBytes(await pdf.save());

  await Share.shareXFiles([XFile(file.path)], text: 'Session Report: ${session.nama}');
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report generated successfully!')),
    );
  }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  } finally {
    // Reset loading state
    if (mounted) {
      setState(() {
        _isSharing = false;
      });
    }
  }
}

  void _showSpO2DistributionPopup(
    BuildContext context,
    List<SensorReading> readings,
  ) {
    final validReadings =
        readings
            .where((r) => r.stabilizing != 1 && r.spo2 >= 70 && r.spo2 <= 100)
            .toList();

    if (validReadings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid SpO2 data available')),
      );
      return;
    }

    // Calculate SpO2 distribution
    Map<String, double> spo2Distribution = {
      '100% - 94%': 0,
      '93% - 88%': 0,
      '87% - 80%': 0,
      '79% - 70%': 0,
    };

    final totalDuration = validReadings.length; // in seconds

    for (var reading in validReadings) {
      if (reading.spo2 >= 94) {
        spo2Distribution['100% - 94%'] = spo2Distribution['100% - 94%']! + 1;
      } else if (reading.spo2 >= 88) {
        spo2Distribution['93% - 88%'] = spo2Distribution['93% - 88%']! + 1;
      } else if (reading.spo2 >= 80) {
        spo2Distribution['87% - 80%'] = spo2Distribution['87% - 80%']! + 1;
      } else {
        spo2Distribution['79% - 70%'] = spo2Distribution['79% - 70%']! + 1;
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SpO2 Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(color: Colors.green[300]!),
                    columnWidths: const {
                      0: FlexColumnWidth(1.7),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: Colors.lightGreen[100],
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Text(
                              'SpO2 Range',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Text(
                              'Min.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 8,
                            ),
                            child: Text(
                              '% time',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      ...spo2Distribution.entries.map((entry) {
                        final minutes = (entry.value / 60).toStringAsFixed(1);
                        final percentage =
                            totalDuration > 0
                                ? (entry.value / totalDuration * 100)
                                    .toStringAsFixed(1)
                                : '0.0';
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Text(entry.key),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Text(minutes),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Text(percentage),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
