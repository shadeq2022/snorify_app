import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:snorify_app/core/constants/app_constants.dart';
import 'package:snorify_app/core/models/sesi.dart';
import 'package:snorify_app/core/models/sensor_reading.dart';
import 'package:snorify_app/core/providers/session_provider.dart';
import 'package:snorify_app/core/providers/ble_provider.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;
  
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool _isStabilizing = false;
  int _stabilizationCountdown = 15;
  
  @override
  void initState() {
    super.initState();
    
    // Load session data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SessionProvider>(context, listen: false).loadSessionById(widget.sessionId);
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
        final sessionStart = DateFormat('yyyy-MM-dd HH:mm:ss').parse(
          '${session.tanggal} ${session.waktuMulai}'
        );

        // Hitung statistik SPO2 dan snoring (exclude stabilization data and invalid SpO2 < 70)
        final filteredReadings = readings.where((r) => r.stabilizing != 1 && r.spo2 >= 70).toList();
        final spo2Values = filteredReadings.map((r) => r.spo2).toList();
        final avgSpO2 = spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a + b) / spo2Values.length : 0.0;
        final minSpO2 = spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a < b ? a : b) : 0.0;
        int dropCount = 0;
        for (int i = 1; i < spo2Values.length; i++) {
          if (spo2Values[i - 1] - spo2Values[i] >= 3) dropCount++;
        }
        final snoreCount = filteredReadings.where((r) => r.status == AppConstants.statusSnore).length;
        
        // Check for current stabilization
        final isCurrentlyStabilizing = readings.isNotEmpty && readings.last.stabilizing == 1;
        
        // Check for stabilization start (when we detect stabilizing = 1 and we weren't already stabilizing)
        if (isCurrentlyStabilizing && !_isStabilizing) {
          _isStabilizing = true;
          _stabilizationCountdown = 15;
          
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
                  colors: isDark
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
                Text(session.nama, style: const TextStyle(color: Colors.white70)),
                Text('Tanggal: ${session.tanggal}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(session.waktuSelesai == null ? Icons.stop_circle_outlined : Icons.delete),
                tooltip: session.waktuSelesai == null ? 'End Session' : 'Delete Session',
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
          body: readings.isEmpty
              ? const Center(child: Text('No data available for this session'))
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
                                  colors: isDark
                                      ? [Colors.grey.shade800, Colors.grey.shade900]
                                      : [Colors.blue.shade50, Colors.blue.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,                                children: [                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 16, color: isDark ? Colors.white70 : Colors.grey[700]),
                                          const SizedBox(width: 4),
                                          Text('${session.waktuMulai} - ${session.waktuSelesai ?? "Now"}')
                                        ],
                                      ),                                      IconButton(
                                        onPressed: () => _shareSessionReport(context, session, readings),
                                        icon: const Icon(Icons.share, size: 20),
                                        tooltip: 'Share',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),                                    ],
                                  ),
                                  
                                  Row(
                                    children: [
                                      Icon(Icons.timelapse, size: 16, color: isDark ? Colors.white70 : Colors.grey[700]),
                                      const SizedBox(width: 4),
                                      Text(session.durasi != null ? '${session.durasi} min' : '-')
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
                                          const Text("Avg SpO₂", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('${avgSpO2.toStringAsFixed(1)}%')
                                        ],
                                      ),
                                      Column(                                    
                                        children: [
                                          const Text("Min SpO₂", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('${minSpO2.toStringAsFixed(1)}%')
                                        ],
                                      ),
                                      Column(                                    
                                        children: [
                                          const Text("Drops ≥3%", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('$dropCount')
                                        ],
                                      ),
                                      Column(                                    
                                        children: [
                                          const Text("Snore", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text('$snoreCount')
                                        ],
                                      ),
                                    ],
                                  )
                                ],                              ),                            ),                            const SizedBox(height: 8),
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

  Widget _buildCharts(List<SensorReading> readings, DateTime sessionStartTime) {
    // Filter readings for SpO2 chart: exclude stabilization data and invalid readings (< 70 or > 100)
    final validSpo2Readings = readings.where((r) => 
      r.stabilizing != 1 && r.spo2 >= 70 && r.spo2 <= 100
    ).toList();
    
    // For snoring chart, include all readings except stabilization
    final validSnoreReadings = readings.where((r) => r.stabilizing != 1).toList();
    
    final List<FlSpot> spo2Spots = validSpo2Readings.map((r) {
      final time = sessionStartTime.add(Duration(seconds: r.timestamp - readings.first.timestamp));
      return FlSpot(time.millisecondsSinceEpoch.toDouble(), r.spo2.toDouble());
    }).toList();

    final List<FlSpot> snoreSpots = validSnoreReadings.map((r) {
      final time = sessionStartTime.add(Duration(seconds: r.timestamp - readings.first.timestamp));
      return FlSpot(time.millisecondsSinceEpoch.toDouble(), r.status == 1 ? 1.0 : 0.0);
    }).toList();

    FlTitlesData buildTitles(bool isSnore) => FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: 60 * 60 * 1000, // every 60 minutes to reduce overlap
          getTitlesWidget: (value, meta) {
            final label = DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(value.toInt()));
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Transform.translate(
                offset: const Offset(-8, 0), // move label left slightly to align
                child: Text(label),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40, // <-- Added padding between Y axis and chart
          getTitlesWidget: (value, _) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(isSnore ? (value == 1.0 ? 'Yes' : 'No') : '${value.toInt()}'),
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
        getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
          final time = DateFormat.Hm().format(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()));
          final value = isSnore ? (spot.y == 1.0 ? 'Snoring' : 'No Snore') : '${spot.y.toStringAsFixed(1)}%';
          return LineTooltipItem('$value\n$time', const TextStyle(color: Colors.white));
        }).toList(),
      ),
    );

    Widget buildChart(List<FlSpot> spots, double minY, double maxY, Color color, bool isSnore) {
      return LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: color,
              barWidth: 2,
              dotData: FlDotData(show: false),
            )
          ],
          lineTouchData: buildTouchData(color, isSnore),
          titlesData: buildTitles(isSnore),
          gridData: FlGridData(show: true),
          extraLinesData: !isSnore
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: 95,
                  color: Colors.red,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                  label: HorizontalLineLabel(
                    show: true,
                    labelResolver: (_) => '95%',
                    alignment: Alignment.topLeft,
                    style: const TextStyle(fontSize: 9, color: Colors.red),
                  ),
                )
              ])
            : ExtraLinesData(),
        ),
      );
    }    return Column(
      children: [        // SpO2 Chart Header with Info Icon
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
        SizedBox(height: 180, child: buildChart(spo2Spots, 70, 100, Colors.green, false)),
        const SizedBox(height: 28),
        const Text('Snoring', style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 100, child: buildChart(snoreSpots, 0, 1, Colors.orange, true)),
      ],
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
                  const Icon(
                    Icons.sensors,
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sensor Stabilizing',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please keep your finger steady',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  CircularProgressIndicator(
                    value: (15 - _stabilizationCountdown) / 15,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
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
      builder: (context) => AlertDialog(
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
              _updateSession(context, session, nameController.text, notesController.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _updateSession(BuildContext context, Sesi session, String name, String? notes) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
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
      builder: (context) => AlertDialog(
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
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    await sessionProvider.deleteSession(sessionId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session deleted successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _endSession(BuildContext context, Sesi session) async {
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
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
    }  }

  void _showSpO2DistributionPopup(BuildContext context, List<SensorReading> readings) {
    final validReadings = readings.where((r) => r.stabilizing != 1 && r.spo2 >= 70 && r.spo2 <= 100).toList();
    
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
      builder: (context) => Dialog(
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),              const SizedBox(height: 16),              Table(
                border: TableBorder.all(color: Colors.green[300]!),
                columnWidths: const {
                  0: FlexColumnWidth(1.7),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.lightGreen[100]),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text('SpO2 Range', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text('Min.', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        child: Text('% time', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...spo2Distribution.entries.map((entry) {
                    final minutes = (entry.value / 60).toStringAsFixed(1);
                    final percentage = totalDuration > 0 
                        ? (entry.value / totalDuration * 100).toStringAsFixed(1)
                        : '0.0';
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Text(entry.key),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Text(minutes),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
      ),    );
  }

  Future<void> _shareSessionReport(BuildContext context, Sesi session, List<SensorReading> readings) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing report to share...')),
      );
      
      final pdf = pw.Document();
      
      // Calculate statistics (same as above)
      final validReadings = readings.where((r) => r.stabilizing != 1 && r.spo2 >= 70).toList();
      final spo2Values = validReadings.map((r) => r.spo2).toList();
      final avgSpO2 = spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a + b) / spo2Values.length : 0.0;
      final minSpO2 = spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a < b ? a : b) : 0.0;
      final maxSpO2 = spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a > b ? a : b) : 0.0;
      
      int dropCount = 0;
      for (int i = 1; i < spo2Values.length; i++) {
        if (spo2Values[i - 1] - spo2Values[i] >= 3) dropCount++;
      }
      final snoreCount = validReadings.where((r) => r.status == AppConstants.statusSnore).length;
      
      // Create PDF content (same structure as above)
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Snorify Session Report',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Session: ${session.nama}'),
                pw.Text('Date: ${session.tanggal}'),
                pw.Text('Time: ${session.waktuMulai} - ${session.waktuSelesai ?? "Ongoing"}'),
                pw.Text('Duration: ${session.durasi ?? 0} minutes'),
                pw.SizedBox(height: 20),
                pw.Text('Summary:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Average SpO₂: ${avgSpO2.toStringAsFixed(1)}%'),
                pw.Text('Minimum SpO₂: ${minSpO2.toStringAsFixed(1)}%'),
                pw.Text('Maximum SpO₂: ${maxSpO2.toStringAsFixed(1)}%'),
                pw.Text('SpO₂ Drops ≥3%: $dropCount'),
                pw.Text('Snore Events: $snoreCount'),
              ],
            );
          },
        ),
      );
      
      // Save PDF to temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Snorify_${session.nama}_${session.tanggal}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Snorify Session Report - ${session.nama}',
        subject: 'Sleep Monitoring Report',
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report shared successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing report: $e')),
      );
    }
  }
}